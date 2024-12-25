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
	direction:   f32,
	t_interp:    f32,
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

		// Static variables for state
		if state.direction == 0.0 {
			state.direction = 1.0 // Initialize direction to move toward the red circle
		}

		// First circle (green)
		radius_green := env.screen_width * 0.04
		orbit := env.screen_width * 0.25
		x1 := env.screen_width * 0.5 + math.cos(2.0 * math.PI * state.t) * orbit
		y1 := env.screen_height * 0.5 + math.sin(2.0 * math.PI * state.t) * orbit
		orbit_circle(state.env, state.t, radius_green, orbit, rl.GREEN)
		append(&positions, rl.Vector2{x1, y1})

		// Third circle (red)
		radius_red := env.screen_width * 0.01
		orbit = env.screen_width * 0.13
		x3 := env.screen_width * 0.5 + math.cos(2.0 * math.PI * state.t) * orbit
		y3 := env.screen_height * 0.5 + math.sin(2.0 * math.PI * state.t) * orbit
		orbit_circle(state.env, state.t, radius_red, orbit, rl.RED)
		append(&positions, rl.Vector2{x3, y3})

		// Second circle (yellow, interpolates along the line between the first and third)
		radius_yellow := env.screen_width * 0.012
		if state.t_interp == 0.0 {
			state.t_interp = 0.5 // Start yellow circle in the middle
		}

		t_interp := state.t_interp
		t_interp += state.direction * 0.01 // Adjust interpolation based on direction
		if t_interp >= 1.0 {
			t_interp = 1.0
			state.direction = -1.0 // Reverse direction when reaching the red circle
		} else if t_interp <= 0.0 {
			t_interp = 0.0
			state.direction = 1.0 // Reverse direction when reaching the green circle
		}
		state.t_interp = t_interp

		// Calculate the position of the yellow circle
		x2 := math.lerp(x1, x3, t_interp)
		y2 := math.lerp(y1, y3, t_interp)

		// Check for collision with green and red circles
		dist_to_green := math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
		dist_to_red := math.sqrt((x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3))
		if dist_to_green <= (radius_yellow + radius_green) {
			state.direction = 1.0 // Move toward the red circle
		} else if dist_to_red <= (radius_yellow + radius_red) {
			state.direction = -1.0 // Move toward the green circle
		}

		// Draw the yellow circle
		append(&positions, rl.Vector2{x2, y2})
		rl.DrawCircleV({x2, y2}, radius_yellow, rl.YELLOW)

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
