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
	scene_start_time: f64,
	env:              Env,
	scene3_shader:    rl.Shader, // Shader for Scene 3
	scene4_shader:    rl.Shader, // Shader for Scene 4
	current_shader:   ^rl.Shader, // Pointer to the currently active shader
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
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.scene3_shader // Set active shader for Scene 3
	}

	// Set background color
	rl.ClearBackground(rl.Color{50, 50, 50, 255})

	// Update the rotation angle
	state^.t += 0.01 // Control rotation speed

	// Calculate the camera's position around the cube
	radius := 5.0 // Distance of camera from the cube
	angle := state^.t // Rotation angle

	// Calculate camera position using trigonometric functions
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0) // Fixed height for camera's y-axis position

	// Define the camera position and the target (the center of the cube)
	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z},
		rl.Vector3{0.0, 0.0, 0.0}, // Cube is at the center
		rl.Vector3{0.0, 1.0, 0.0}, // The 'up' direction is the y-axis
		45.0, // Field of view
		.PERSPECTIVE,
	}

	// Begin drawing in 3D mode
	rl.BeginMode3D(camera)
	//
	// Draw "Scene 3" text
	rl.DrawText("Scene 3", 10, 10, 20, rl.Color{255, 255, 255, 255}) // Text in white color
	//
	// If shader is being used, ensure uniforms are set correctly:
	if state.current_shader.id != 0 {
		rl.BeginShaderMode(state.current_shader^)
		model := rl.MatrixRotateXYZ(rl.Vector3{f32(state^.t), f32(state^.t), f32(state^.t)})
		view := rl.MatrixLookAt(
			rl.Vector3{cam_x, cam_y, cam_z},
			rl.Vector3{0.0, 0.0, 0.0},
			rl.Vector3{0.0, 1.0, 0.0},
		)
		projection := rl.MatrixPerspective(
			45.0,
			f32(rl.GetScreenWidth() / rl.GetScreenHeight()),
			0.1,
			100.0,
		)

		// Use SetShaderValueMatrix to set uniform matrices
		modelLoc := rl.GetShaderLocation(state.current_shader^, "model")
		viewLoc := rl.GetShaderLocation(state.current_shader^, "view")
		projectionLoc := rl.GetShaderLocation(state.current_shader^, "projection")

		// Set the matrices as uniforms in the shader
		rl.SetShaderValueMatrix(state.current_shader^, modelLoc, model)
		rl.SetShaderValueMatrix(state.current_shader^, viewLoc, view)
		rl.SetShaderValueMatrix(state.current_shader^, projectionLoc, projection)
	}

	// Apply rotation to the cube (rotating around the center)
	rotation_matrix := rl.MatrixRotateXYZ(rl.Vector3{f32(state^.t), f32(state^.t), f32(state^.t)})

	// Cube's center (we'll rotate it at the origin)
	cube_pos := rl.Vector3{0.0, 0.0, 0.0}

	// Draw the cube (it's a single object)
	rl.DrawCube(cube_pos, 2.0, 2.0, 2.0, rl.Color{255, 0, 0, 255}) // Cube with red color

	// End drawing in 3D mode
	rl.EndMode3D()

	// Calculate the elapsed time and check if the scene should end
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 4.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}


scene3_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 3 cleanup\n")
	rl.UnloadShader(state.current_shader^)
}

// Scene 4 Update
scene4_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.scene4_shader // Set active shader for Scene 4
	}

	// Set background color
	rl.ClearBackground(rl.Color{30, 30, 30, 255})

	// Update the rotation angle
	state^.t += 0.01 // Control rotation speed

	// Calculate the camera's position around the cube
	radius := 5.0 // Distance of camera from the cube
	angle := state^.t // Rotation angle

	// Calculate camera position using trigonometric functions
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0) // Fixed height for camera's y-axis position

	// Define the camera position and the target (the center of the cube)
	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z},
		rl.Vector3{0.0, 0.0, 0.0}, // Cube is at the center
		rl.Vector3{0.0, 1.0, 0.0}, // The 'up' direction is the y-axis
		45.0, // Field of view
		.PERSPECTIVE,
	}

	// Begin drawing in 3D mode
	rl.BeginMode3D(camera)

	if state^.current_shader != nil && state^.current_shader^.id != 0 {
		rl.BeginShaderMode(state^.current_shader^)

		// Pass time as a uniform to the shader
		timeLoc := rl.GetShaderLocation(state^.current_shader^, "time")
		value: f32 = cast(f32)state^.t
		rl.SetShaderValue(state^.current_shader^, timeLoc, &value, .FLOAT)


		rl.DrawCube(rl.Vector3{0.0, 0.0, 0.0}, 2.0, 2.0, 2.0, rl.Color{255, 255, 255, 255})
		rl.EndShaderMode()
	}


	// End drawing in 3D mode
	rl.EndMode3D()

	// Calculate the elapsed time and check if the scene should end
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene4_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 4 cleanup\n")
	rl.UnloadShader(state.current_shader^)
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
scene4: Scene = Scene {
	update  = scene4_update,
	cleanup = scene4_cleanup,
}

@(export)
plug_init :: proc "c" () {
	context = runtime.default_context()
	rl.SetTargetFPS(60)

	shader_rgb := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader.glsl",
	)

	shader_metal := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader_metal.glsl",
	)

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0,
		env              = Env{},
		scene3_shader    = shader_rgb,
		scene4_shader    = shader_metal,
		current_shader   = nil,
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
		if manager.current_scene.update(state) { 	// Pass state directly
			if manager.current_scene.cleanup != nil {
				manager.current_scene.cleanup(state)
			}

			// Scene transitions
			if manager.current_scene == &scene1 {
				manager.current_scene = &scene2
			} else if manager.current_scene == &scene2 {
				manager.current_scene = &scene3
			} else if manager.current_scene == &scene3 {
				manager.current_scene = &scene4
			} else {
				state^.finished = true
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
