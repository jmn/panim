package plug

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

// Define the environment structure
Env :: struct {
	delta_time:    f32,
	screen_width:  f32,
	screen_height: f32,
	rendering:     bool,
	play_sound:    proc(_: rl.Sound, _: rl.Wave), // function pointer equivalent
}

to_string :: proc(env: Env) -> cstring {
	return fmt.ctprintf(
		"delta_time: %f, screen_width: %f, screen_height: %f, rendering: %t",
		env.delta_time,
		env.screen_width,
		env.screen_height,
		env.rendering,
	)
}


// Plugin state structure
plugin_state :: struct {
	initialized: bool,
	finished:    bool,
	frame_count: int,
	t:           f32,
	env:         Env,
}

state: plugin_state = plugin_state {
	initialized = false,
	finished    = false,
	frame_count = 0,
	env         = Env{},
}

// Plugin functions implementation
@(export)
plug_init :: proc "c" () {
	state.initialized = true
	state.finished = false
	state.frame_count = 0
	state.env = Env{}
}

@(export)
plug_pre_reload :: proc "c" () -> rawptr {
	return cast(rawptr)&state
}

@(export)
plug_post_reload :: proc "c" (prev_state: rawptr) {
	if prev_state != nil {
		prev_state_ptr := cast(^plugin_state)prev_state
		state = prev_state_ptr^
	}
}


orbit_circle :: proc(env: Env, t: f32, radius: f32, orbit: f32, color: rl.Color) {
	angle := 2.0 * math.PI * t
	cx := env.screen_width * 0.5
	cy := env.screen_height * 0.5
	px := cx + math.cos(angle) * orbit
	py := cy + math.sin(angle) * orbit
	rl.DrawCircleV({px, py}, radius, color)
}


@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()
	state.env = env
	// rl.TraceLog(.INFO, to_string(env))

	state.frame_count += 1
	if state.frame_count > 100 {
		state.finished = true
	}

	state.t += 0.01

	// Drawing
	{
		rl.ClearBackground(rl.BLUE)

		// Initialize an array to store the positions of the circles
		positions := make([dynamic]rl.Vector2)

		// First circle (green)
		radius := env.screen_width * 0.04
		orbit := env.screen_width * 0.25
		// Calculate the position using orbit_circle
		orbit_circle(state.env, state.t, radius, orbit, rl.GREEN)
		x1 := env.screen_width * 0.5 + math.cos(2.0 * math.PI * state.t) * orbit
		y1 := env.screen_height * 0.5 + math.sin(2.0 * math.PI * state.t) * orbit
		append(&positions, rl.Vector2{x1, y1})

		// Second circle (red, oscillating up and down)
		radius = env.screen_width * 0.02
		orbit = env.screen_width * 0.10
		// Calculate the x position using orbit_circle
		orbit_circle(state.env, state.t, radius, orbit, rl.RED)
		// Oscillating y position based on sine wave
		y2 := env.screen_height * 0.5 + math.sin(2.0 * math.PI * state.t) * orbit
		// We keep x2 fixed at the same position as the first circle
		x2 := env.screen_width * 0.5 + math.cos(2.0 * math.PI * state.t) * orbit
		append(&positions, rl.Vector2{x2, y2})

		// Third circle (red)
		radius = env.screen_width * 0.01
		orbit = env.screen_width * 0.13
		orbit_circle(state.env, state.t, radius, orbit, rl.RED)
		x3 := env.screen_width * 0.5 + math.cos(2.0 * math.PI * state.t) * orbit
		y3 := env.screen_height * 0.5 + math.sin(2.0 * math.PI * state.t) * orbit
		append(&positions, rl.Vector2{x3, y3})

		// Draw lines between each circle
		for i in 0 ..< len(positions) - 1 {
			rl.DrawLineV(positions[i], positions[i + 1], rl.BLACK)
		}
	}
}


@(export)
plug_reset :: proc "c" () {
	state.finished = false
	state.frame_count = 0
	state.env = Env{}
}

@(export)
plug_finished :: proc "c" () -> bool {
	return state.finished
}
