package main

import "base:runtime"
import "core:c"
import "core:math"
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

TIMEZONE_REGION :: "America/Los_Angeles"

HOUR_HAND_LEN := f32(WINDOW_WIDTH) * 0.25
MINUTE_HAND_LEN := f32(WINDOW_WIDTH) * 0.35
SECOND_HAND_LEN := f32(WINDOW_WIDTH) * 0.45

// Clocks initial position has hands at the top
ANGLE_OFFSET :: math.PI / 2.0

window: ^sdl.Window
renderer: ^sdl.Renderer
tz: ^datetime.TZ_Region

main :: proc() {
	sdl.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
	context = runtime.default_context()

	sdl.Log("Initializing %s...\n", APP_NAME)
	if ok := sdl.SetAppMetadata(APP_NAME, "1.0", "me.ritam.time"); !ok {
		sdl.Log("Failed to set app metadata: %s", sdl.GetError())
		return .FAILURE
	}

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

	tz, _ = timezone.region_load(TIMEZONE_REGION)

	sdl.SetRenderVSync(renderer, 1)
	sdl.SetRenderLogicalPresentation(renderer, WINDOW_WIDTH, WINDOW_HEIGHT, .LETTERBOX)

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

	sdl.SetRenderDrawColor(renderer, 0, 0, 0, sdl.ALPHA_OPAQUE)
	sdl.RenderClear(renderer)

	hx := WINDOW_CENTER_X + HOUR_HAND_LEN * math.cos(hour_angle - ANGLE_OFFSET)
	hy := WINDOW_CENTER_Y + HOUR_HAND_LEN * math.sin(hour_angle - ANGLE_OFFSET)

	mx := WINDOW_CENTER_X + MINUTE_HAND_LEN * math.cos(minute_angle - ANGLE_OFFSET)
	my := WINDOW_CENTER_Y + MINUTE_HAND_LEN * math.sin(minute_angle - ANGLE_OFFSET)

	sx := WINDOW_CENTER_X + SECOND_HAND_LEN * math.cos(second_angle - ANGLE_OFFSET)
	sy := WINDOW_CENTER_Y + SECOND_HAND_LEN * math.sin(second_angle - ANGLE_OFFSET)

	sdl.SetRenderDrawColor(renderer, 255, 0, 0, sdl.ALPHA_OPAQUE)
	sdl.RenderLine(renderer, WINDOW_CENTER_X, WINDOW_CENTER_Y, hx, hy)

	sdl.SetRenderDrawColor(renderer, 0, 255, 0, sdl.ALPHA_OPAQUE)
	sdl.RenderLine(renderer, WINDOW_CENTER_X, WINDOW_CENTER_Y, mx, my)

	sdl.SetRenderDrawColor(renderer, 0, 0, 255, sdl.ALPHA_OPAQUE)
	sdl.RenderLine(renderer, WINDOW_CENTER_X, WINDOW_CENTER_Y, sx, sy)

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
	sdl.Log("Quitting %s with result %d", APP_NAME, result)

	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
	sdl.Quit()
}
