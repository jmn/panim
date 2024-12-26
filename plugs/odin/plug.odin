package plug

import "base:runtime"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Env :: struct {
	delta_time:    f32,
	screen_width:  f32,
	screen_height: f32,
}

Scene :: struct {
	update:  proc(_: rawptr) -> bool, // Logic and drawing
	cleanup: proc(_: rawptr), // Cleanup logic
}

Future :: struct {
	completed:   bool,
	start_time:  f64,
	duration:    f64,
	on_complete: proc(_: rawptr),
}

plugin_state :: struct {
	initialized:      bool,
	finished:         bool,
	frame_count:      int,
	t:                f64,
	scene_start_time: f64, // Add scene start time here
	env:              Env,
}

Manager :: struct {
	current_scene: ^Scene,
	next_scene:    ^Scene,
	state_data:    rawptr,
}

future_state: Future = Future{}
state: plugin_state = plugin_state{}
manager: Manager = Manager{}

// Scene 1 Update and Cleanup
scene1_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	rl.ClearBackground(rl.Color{30, 30, 30, 255})
	rl.DrawText("Scene 1", 10, 10, 20, rl.Color{255, 255, 255, 255})
	rl.DrawCircle(i32(400 + int(math.sin(state^.t) * 100)), 300, 50, rl.Color{0, 255, 0, 255})

	elapsed_time := rl.GetTime() - state^.scene_start_time
	// rl.TraceLog(.INFO, fmt.caprintf("el %.10f", elapsed_time))

	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene1_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 1 cleanup\n")
}

// Scene 2 Update and Cleanup
scene2_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	rl.ClearBackground(rl.Color{50, 50, 50, 255})
	rl.DrawText("Scene 2", 10, 10, 20, rl.Color{255, 255, 255, 255})

	state^.t += 0.05
	radius := 100
	center_x := f32(rl.GetScreenWidth()) * f32(0.5)
	center_y := f32(rl.GetScreenHeight()) * 0.5
	x_pos := center_x + f32(radius) * f32(math.cos(state^.t))
	y_pos := center_y + f32(radius) * f32(math.sin(state^.t))

	rl.DrawCircle(i32(x_pos), i32(y_pos), 30, rl.Color{0, 255, 255, 255})

	elapsed_time := rl.GetTime() - state^.scene_start_time
	// rl.TraceLog(.INFO, fmt.caprintf("el %.10f", elapsed_time))

	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene2_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 2 cleanup\n")
}

// Scene 3 Update and Cleanup (New)
scene3_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	// Calculate the rotation angle based on time
	angle := rl.GetTime() * 30.0 // Rotate at 30 degrees per second

	// Set up the camera: View the cube from a fixed position
	camera := rl.Camera3D {
		position   = rl.Vector3{10.0, 10.0, 10.0}, // Camera position
		target     = rl.Vector3{0.0, 0.0, 0.0}, // Camera looks at the center of the cube
		up         = rl.Vector3{0.0, 1.0, 0.0}, // Define the "up" direction
		fovy       = 45.0, // Field of view
		projection = .PERSPECTIVE, // Perspective projection
	}

	// Start 3D mode
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{70, 70, 70, 255}) // Set background color

	// Begin 3D mode with camera
	rl.BeginMode3D(camera)

	// Rotate the cube in the Y axis using the calculated angle
	// In Raylib, use the DrawCube function and pass the rotation as part of the model matrix
	cube_position := rl.Vector3{0.0, 0.0, 0.0} // Cube at the center of the world
	cube_size := f32(2.0)

	// Spin the cube by modifying its position or using a rotation matrix
	// We will use the rotation as part of the drawing function (no direct model matrix available in Raylib)
	// The rotation is applied based on the current time (angle)
	rl.DrawCube(cube_position, cube_size, cube_size, cube_size, rl.Color{255, 0, 0, 255}) // Draw the cube

	// End 3D mode
	rl.EndMode3D()

	// Draw overlay text
	rl.DrawText("Scene 3: Spinning Cube", 10, 10, 20, rl.Color{255, 255, 255, 255})
	rl.EndDrawing()

	// Check elapsed time for scene completion
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		state^.finished = true // Mark as finished when scene 3 is done
		return true
	}

	return false
}


scene3_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 3 cleanup\n")
}

scene1: Scene = Scene {
	update  = scene1_update,
	cleanup = scene1_cleanup,
}
scene2: Scene = Scene {
	update  = scene2_update,
	cleanup = scene2_cleanup,
}
scene3: Scene = Scene {
	update  = scene3_update,
	cleanup = scene3_cleanup,
}

@(export)
plug_init :: proc "c" () {
	context = runtime.default_context()
	rl.SetTargetFPS(60)

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0,
		env              = Env{},
	}

	manager = Manager {
		current_scene = &scene1,
		next_scene    = &scene2,
		state_data    = cast(rawptr)&state,
	}

	// Set up the Future for Scene transition
	future_state = Future {
		completed = false,
		start_time = state.t,
		duration = 3.0,
		on_complete = proc(_: rawptr) {
			fmt.printf("Transitioning to Scene 2\n")
			manager.current_scene = manager.next_scene
		},
	}
}

@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()

	state := cast(^plugin_state)(manager.state_data)
	state^.t = rl.GetTime()

	// Handle future-based transitions (if any)
	if future_state.completed == false {
		if (state^.t - future_state.start_time) > future_state.duration {
			future_state.completed = true
			if future_state.on_complete != nil {
				future_state.on_complete(manager.state_data)
			}
		}
	}

	// Update the current scene
	if manager.current_scene != nil {
		if manager.current_scene.update(manager.state_data) {
			if manager.current_scene.cleanup != nil {
				manager.current_scene.cleanup(manager.state_data)
			}

			// Check if we need to transition to the next scene
			if manager.current_scene == &scene1 {
				manager.current_scene = &scene2
			} else if manager.current_scene == &scene2 {
				manager.current_scene = &scene3
			} else {
				state^.finished = true // All scenes are complete, set finished to true
			}
		}
	}
}

@(export)
plug_reset :: proc "c" () {
	state.finished = false
	state.frame_count = 0
	state.t = 0.0

	manager.current_scene = &scene1
	manager.next_scene = &scene2

	future_state = Future {
		completed = false,
		start_time = state.t,
		duration = 3.0,
		on_complete = proc(_: rawptr) {
			manager.current_scene = manager.next_scene
		},
	}
}

@(export)
plug_finished :: proc "c" () -> bool {
	return state.finished
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
