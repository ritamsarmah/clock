#+feature using-stmt

package main

import "core:c"
import sdl "vendor:sdl3"

/* Globals */

APP_NAME :: "idle"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800

window: ^sdl.Window
renderer: ^sdl.Renderer

/* Functions */

main :: proc() {
	sdl.EnterAppMainCallbacks(0, nil, app_init, app_iterate, app_event, app_quit)
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
	sdl.Log("Initializing %s...\n", APP_NAME)
	if ok := sdl.SetAppMetadata(APP_NAME, "1.0", "me.ritam.clock.idle"); !ok {
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

	sdl.SetRenderVSync(renderer, 1)
	sdl.SetRenderLogicalPresentation(renderer, WINDOW_WIDTH, WINDOW_HEIGHT, .LETTERBOX)

	// Draw black background
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, sdl.ALPHA_OPAQUE)
	sdl.RenderClear(renderer)
	sdl.RenderPresent(renderer)

	return .CONTINUE
}

app_iterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
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
