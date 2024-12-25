package plug

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"
NUM_GROUPS :: 20

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

GroupState :: struct {
	t_interp:  f32,
	direction: f32,
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
	groups:      [dynamic]GroupState,
	camera:      rl.Camera2D,
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
	context = runtime.default_context()
	state.initialized = true
	state.finished = false
	state.frame_count = 0
	state.env = Env{}
	state.groups = make([dynamic]GroupState, NUM_GROUPS)
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


// orbit_circle :: proc(env: Env, t: f32, radius: f32, orbit: f32, color: rl.Color) {
// 	angle := 2.0 * math.PI * t
// 	cx := env.screen_width * 0.5
// 	cy := env.screen_height * 0.5
// 	px := cx + math.cos(angle) * orbit
// 	py := cy + math.sin(angle) * orbit
// 	rl.DrawCircleV({px, py}, radius, color)
// }
//
orbit_circle :: proc(
	env: Env,
	t: f32,
	radius: f32,
	orbit: f32,
	offset_x: f32,
	color: rl.Color,
) -> (
	f32,
	f32,
) {
	angle := 2.0 * math.PI * t
	cx := env.screen_width * 0.5
	cy := env.screen_height * 0.5
	px := cx + math.cos(angle) * orbit + offset_x
	py := cy + math.sin(angle) * orbit
	rl.DrawCircleV({px, py}, radius, color)
	return px, py
}

euclidean_distance :: proc(a, b: rl.Vector2) -> f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
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
		if state.camera.zoom == 0.0 {
			state.camera = rl.Camera2D {
				target   = {env.screen_width * 0.5, env.screen_height * 0.5},
				offset   = {env.screen_width * 0.5, env.screen_height * 0.5},
				rotation = 0.0,
				zoom     = 0.2, // Set a zoom-in level
			}
		}

		// Zoom in further but keep a zoomed-out effect
		state.camera.zoom = 0.2 + 0.1 * math.sin(2.0 * math.PI * state.t)

		rl.BeginMode2D(state.camera)

		rl.ClearBackground(rl.BLUE)

		num_groups_per_row := 5
		num_rows := 4
		group_spacing := env.screen_width * 0.25 // Tighter spacing

		// Loop through each row and column to position the sets
		for row in 0 ..< num_rows {
			for col in 0 ..< num_groups_per_row {
				group_index := row * num_groups_per_row + col
				group_offset_x := f32(col) * group_spacing - env.screen_width * 0.15 // X offset for each set
				group_offset_y := f32(row) * group_spacing - env.screen_height * 0.15 // Y offset for each set

				if len(state.groups) <= group_index {
					append(&state.groups, GroupState{t_interp = 0.5, direction = 1.0})
				}

				group_state := &state.groups[group_index]

				radius_green := env.screen_width * 0.04
				orbit_green := env.screen_width * 0.25
				x1, y1 := orbit_circle(
					state.env,
					state.t,
					radius_green,
					orbit_green,
					group_offset_x,
					rl.GREEN,
				)

				radius_red := env.screen_width * 0.01
				orbit_red := env.screen_width * 0.13
				x3, y3 := orbit_circle(
					state.env,
					state.t,
					radius_red,
					orbit_red,
					group_offset_x,
					rl.RED,
				)

				radius_yellow := env.screen_width * 0.01
				group_state.t_interp += group_state.direction * 0.01
				if group_state.t_interp >= 1.0 {
					group_state.t_interp = 1.0
					group_state.direction = -1.0
				} else if group_state.t_interp <= 0.0 {
					group_state.t_interp = 0.0
					group_state.direction = 1.0
				}

				x2 := math.lerp(x1, x3, group_state.t_interp)
				y2 := math.lerp(y1, y3, group_state.t_interp)

				yellow_position := rl.Vector2{x2, y2}
				green_position := rl.Vector2{x1, y1}
				red_position := rl.Vector2{x3, y3}

				distance_to_green := euclidean_distance(yellow_position, green_position)
				distance_to_red := euclidean_distance(yellow_position, red_position)

				if distance_to_green < (radius_green + radius_yellow) {
					group_state.direction = 1.0 // Change direction when touching the green circle
				}
				if distance_to_red < (radius_red + radius_yellow) {
					group_state.direction = -1.0 // Change direction when touching the red circle
				}

				rl.DrawCircleV(yellow_position, radius_yellow, rl.YELLOW)

				rl.DrawLineV(green_position, yellow_position, rl.BLACK)
				rl.DrawLineV(yellow_position, red_position, rl.BLACK)
			}
		}

		rl.EndMode2D()
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
