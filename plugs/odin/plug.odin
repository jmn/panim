package plug

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"
NUM_GROUPS :: 100 // Increase the number of groups to fill the screen

// Define the environment structure
Env :: struct {
	delta_time:    f32,
	screen_width:  f32,
	screen_height: f32,
	rendering:     bool,
	play_sound:    proc(_: rl.Sound, _: rl.Wave), // function pointer equivalent
	mouse_wheel:   f32, // Add mouse wheel input
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
	rotation:    f32, // Track rotation angle
	zoom_speed:  f32, // Speed of zoom transition
	zoom_dir:    f32, // Direction of zoom change
	zoom_min:    f32, // Minimum zoom value
	zoom_max:    f32, // Maximum zoom value
}

state: plugin_state = plugin_state {
	initialized = false,
	finished    = false,
	frame_count = 0,
	env         = Env{},
	rotation    = 0.0, // Initialize the rotation to 0
	zoom_speed  = 0.01, // Smooth zoom speed
	zoom_dir    = 1.0, // Start zooming in
	zoom_min    = 0.2, // Minimum zoom limit
	zoom_max    = 1.0, // Maximum zoom limit
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

euclidean_distance :: proc(a, b: rl.Vector2) -> f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
}

@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()
	state.env = env

	state.frame_count += 1
	if state.frame_count > 1200 {
		state.finished = true
	}

	state.t += 0.01

	// Drawing
	{
		// Update zoom value over time for continuous zooming in and out
		state.camera.zoom += state.zoom_dir * state.zoom_speed
		// Reverse zoom direction if the zoom reaches the min or max value
		if state.camera.zoom <= state.zoom_min {
			state.zoom_dir = 1.0 // Zoom in
		}
		if state.camera.zoom >= state.zoom_max {
			state.zoom_dir = -1.0 // Zoom out
		}

		// Adjust camera rotation based on left and right arrow keys
		if rl.IsKeyDown(.RIGHT) {
			state.rotation += 0.01 // Rotate clockwise
		}
		if rl.IsKeyDown(.LEFT) {
			state.rotation -= 0.01 // Rotate counter-clockwise
		}

		// Set camera properties with zoom and rotation
		state.camera = rl.Camera2D {
			rl.Vector2{env.screen_width * 0.5, env.screen_height * 0.5},
			rl.Vector2{env.screen_width * 0.5, env.screen_height * 0.5},
			state.rotation, // Apply rotation here
			state.camera.zoom, // Apply zoom here
		}

		rl.BeginMode2D(state.camera)

		// Gradient background for a more dynamic look
		rl.ClearBackground(rl.Color{30, 30, 30, 255}) // Dark background

		// Number of rows and groups per row (8 groups per row, multiple rows)
		num_groups_per_row := 8 // 8 groups per row
		num_rows := 6 // 6 rows to fill the screen

		// Calculate the spacing between groups horizontally and vertically
		group_spacing_x := env.screen_width / f32(num_groups_per_row) // Horizontal spacing between groups
		group_spacing_y := env.screen_height / f32(num_rows) // Vertical spacing between groups

		// Loop through each row and column to position the groups
		for row in 0 ..< num_rows {
			for col in 0 ..< num_groups_per_row {
				group_index := row * num_groups_per_row + col
				// Calculate the offset for each group
				group_offset_x :=
					f32(col) * group_spacing_x - env.screen_width * 0.5 + group_spacing_x * 0.5
				group_offset_y :=
					f32(row) * group_spacing_y - env.screen_height * 0.5 + group_spacing_y * 0.5

				// Ensure the state.groups array has enough groups to handle the index
				if len(state.groups) <= group_index {
					append(&state.groups, GroupState{t_interp = 0.5, direction = 1.0})
				}

				group_state := &state.groups[group_index]

				// Define sizes for the circles
				radius_green := env.screen_width * 0.04
				orbit_green := env.screen_width * 0.15 // Smaller orbit to fit within the screen
				green_angle := state.t
				green_position := rl.Vector2 {
					env.screen_width * 0.5 + math.cos(green_angle) * orbit_green + group_offset_x,
					env.screen_height * 0.5 + math.sin(green_angle) * orbit_green + group_offset_y,
				}

				radius_red := env.screen_width * 0.01
				orbit_red := env.screen_width * 0.07 // Smaller orbit to fit within the screen
				red_angle := state.t * 1.5 // Faster orbit for red circle
				red_position := rl.Vector2 {
					env.screen_width * 0.5 + math.cos(red_angle) * orbit_red + group_offset_x,
					env.screen_height * 0.5 + math.sin(red_angle) * orbit_red + group_offset_y,
				}

				radius_yellow := env.screen_width * 0.01
				group_state.t_interp += group_state.direction * 0.01
				if group_state.t_interp >= 1.0 {
					group_state.t_interp = 1.0
					group_state.direction = -1.0
				} else if group_state.t_interp <= 0.0 {
					group_state.t_interp = 0.0
					group_state.direction = 1.0
				}

				// Interpolate between the green and red positions for the yellow circle
				x_yellow := math.lerp(green_position.x, red_position.x, group_state.t_interp)
				y_yellow := math.lerp(green_position.y, red_position.y, group_state.t_interp)

				yellow_position := rl.Vector2{x_yellow, y_yellow}

				// Calculate distances to detect collisions and change directions
				distance_to_green := euclidean_distance(yellow_position, green_position)
				distance_to_red := euclidean_distance(yellow_position, red_position)

				if distance_to_green < (radius_green + radius_yellow) {
					group_state.direction = 1.0 // Change direction when touching the green circle
				}
				if distance_to_red < (radius_red + radius_yellow) {
					group_state.direction = -1.0 // Change direction when touching the red circle
				}

				// Draw the circles with gradient and transparency for more polished look
				rl.DrawCircleV(green_position, radius_green, rl.Color{0, 255, 0, 180})
				rl.DrawCircleV(red_position, radius_red, rl.Color{255, 0, 0, 180})
				rl.DrawCircleV(yellow_position, radius_yellow, rl.Color{255, 255, 0, 180})

				// Use thinner lines for connection with a subtle color
				rl.DrawLineV(green_position, yellow_position, rl.Color{255, 255, 255, 150})
				rl.DrawLineV(yellow_position, red_position, rl.Color{255, 255, 255, 150})
			}
		}

		rl.EndMode2D()
	}
}

@(export)
plug_reset :: proc "c" () {
	state.finished = false
	state.frame_count = 0
	state.rotation = 0.0
	state.camera.zoom = 0.4
	state.zoom_dir = 1.0
}

@(export)
plug_finished :: proc "c" () -> bool {
	return state.finished
}
