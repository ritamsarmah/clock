package main

import "base:runtime"
import "core:c"
import "core:math"
import "core:os"
import "core:strings"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"
import sdl "vendor:sdl3"

/* Globals */

APP_NAME :: "time"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800
WINDOW_CENTER_X :: f32(WINDOW_WIDTH) / 2
WINDOW_CENTER_Y :: f32(WINDOW_HEIGHT) / 2

MARK_COUNT :: 60

PRIMARY_MARK_WIDTH :: 16
PRIMARY_MARK_HEIGHT :: 64
SECONDARY_MARK_WIDTH :: 6
SECONDARY_MARK_HEIGHT :: 32

MARK_RADIUS :: WINDOW_WIDTH * 0.4
HOUR_HAND_LENGTH :: WINDOW_WIDTH * 0.25
MINUTE_HAND_LENGTH :: WINDOW_WIDTH * 0.35
SECOND_HAND_LENGTH :: WINDOW_WIDTH * 0.45

BG_COLOR :: sdl.FColor{255, 255, 255, sdl.ALPHA_OPAQUE}
FG_COLOR :: sdl.FColor{0, 0, 0, sdl.ALPHA_OPAQUE}
ACCENT_COLOR :: sdl.FColor{255, 0, 0, sdl.ALPHA_OPAQUE}

// Clocks initial position has hands at the top
ANGLE_OFFSET :: math.PI

window: ^sdl.Window
renderer: ^sdl.Renderer
tz: ^datetime.TZ_Region
background: ^sdl.Texture

main :: proc() {
	sdl.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
	context = runtime.default_context()

	sdl.Log("Initializing %s...\n", APP_NAME)
	if ok := sdl.SetAppMetadata(APP_NAME, "1.0", "me.ritam.clock.time"); !ok {
		sdl.Log("Failed to set app metadata: %s", sdl.GetError())
		return .FAILURE
	}

	/* SDL */

	if ok := sdl.Init({.VIDEO}); !ok {
		sdl.Log("Failed to initialize SDL: %s\n", sdl.GetError())
		return .FAILURE
	}

	if ok := sdl.CreateWindowAndRenderer(
		APP_NAME,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.HIGH_PIXEL_DENSITY},
		&window,
		&renderer,
	); !ok {
		sdl.Log("Failed to create window or renderer: %s", sdl.GetError())
		return .FAILURE
	}

	sdl.SetRenderVSync(renderer, 1)
	sdl.SetRenderLogicalPresentation(renderer, WINDOW_WIDTH, WINDOW_HEIGHT, .LETTERBOX)

	/* Timezone */

	tz_link, tz_err := os.read_link("/etc/localtime", context.allocator)
	if tz_err != nil {
		sdl.Log("Failed to read timezone")
		return .FAILURE
	}
	defer delete(tz_link)

	tz_region := string(tz_link)
	tz_region = strings.trim_left(tz_region, ".")
	tz_region = strings.trim_prefix(tz_region, "/usr/share/zoneinfo/")

	tz, _ = timezone.region_load(tz_region)

	/* Rendering */

	background = create_background()

	return .CONTINUE
}

app_iterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
	context = runtime.default_context()

	now := time.now()
	utc, _ := time.time_to_datetime(now)
	local, _ := timezone.datetime_to_tz(utc, tz)

	hour, minute, second := local.hour, local.minute, local.second
	hour = hour % 12 // Convert from 24-hour to 12-hour

	second_angle := math.TAU * f32(second) / 60
	minute_angle := math.TAU * (f32(minute) + f32(second) / 60) / 60
	hour_angle := math.TAU * (f32(hour) + f32(minute) / 60) / 12

	sdl.RenderTexture(renderer, background, nil, nil)

	render_rect(renderer, 8, HOUR_HAND_LENGTH, hour_angle + ANGLE_OFFSET, 0, FG_COLOR)
	render_rect(renderer, 8, MINUTE_HAND_LENGTH, minute_angle + ANGLE_OFFSET, 0, FG_COLOR)
	render_rect(renderer, 4, SECOND_HAND_LENGTH, second_angle + ANGLE_OFFSET, 0, ACCENT_COLOR)

	sdl.RenderPresent(renderer)

	return .CONTINUE
}

app_event :: proc "c" (appstate: rawptr, event: ^sdl.Event) -> sdl.AppResult {
	#partial switch event.type {
	case .QUIT, .WINDOW_CLOSE_REQUESTED:
		return .SUCCESS
	}

	return .CONTINUE
}

app_quit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
	context = runtime.default_context()

	sdl.Log("Quitting %s with result %d", APP_NAME, result)

	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
	sdl.Quit()

	free(tz)
	sdl.DestroyTexture(background)
}

/* Utilities */

create_background :: proc() -> ^sdl.Texture {
	background := sdl.CreateTexture(renderer, .RGBA8888, .TARGET, WINDOW_WIDTH, WINDOW_HEIGHT)
	sdl.SetTextureBlendMode(background, sdl.BLENDMODE_BLEND)
	sdl.SetRenderTarget(renderer, background)
	sdl.SetRenderDrawColorFloat(renderer, BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, BG_COLOR.a)

	sdl.RenderClear(renderer)

	// Render tick marks onto background
	for i in 0 ..< MARK_COUNT {
		is_primary := i % 5 == 0

		width: f32 = is_primary ? PRIMARY_MARK_WIDTH : SECONDARY_MARK_WIDTH
		height: f32 = is_primary ? PRIMARY_MARK_HEIGHT : SECONDARY_MARK_HEIGHT
		angle := f32(i) * math.TAU / MARK_COUNT
		offset := is_primary ? MARK_RADIUS : MARK_RADIUS + height

		render_rect(renderer, width, height, angle, offset, FG_COLOR)
	}

	// Return to main render target
	sdl.SetRenderTarget(renderer, nil)

	return background
}

render_rect :: proc(
	renderer: ^sdl.Renderer,
	width, height, angle, offset: f32,
	color: sdl.FColor,
) {
	hw, hh := width / 2, height

	// Rectangle vertices relative to origin (0,0)
	vertices := [4]sdl.Vertex {
		sdl.Vertex{sdl.FPoint{-hw, 0}, color, {}},
		sdl.Vertex{sdl.FPoint{hw, 0}, color, {}},
		sdl.Vertex{sdl.FPoint{hw, hh}, color, {}},
		sdl.Vertex{sdl.FPoint{-hw, hh}, color, {}},
	}

	cos_a := math.cos(angle)
	sin_a := math.sin(angle)

	for i in 0 ..< 4 {
		x := vertices[i].position.x
		y := vertices[i].position.y + offset
		vertices[i].position.x = WINDOW_CENTER_X + x * cos_a - y * sin_a
		vertices[i].position.y = WINDOW_CENTER_Y + x * sin_a + y * cos_a
	}

	// Two triangles forming the rectangle
	indices := [6]i32{0, 1, 2, 2, 3, 0}

	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(vertices[:]),
		len(vertices),
		raw_data(indices[:]),
		len(indices),
	)
}
