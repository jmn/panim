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
	name:    string,
	update:  proc(state: ^plugin_state) -> bool, // General update function
	cleanup: proc(state: ^plugin_state), // General cleanup function
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
	current_shader:   ^rl.Shader,
	shaders:          []rl.Shader,
}

Manager :: struct {
	current_scene: ^Scene,
	next_scene:    ^Scene,
	scenes:        [dynamic]Scene,
	state_data:    rawptr,
}

future_state: Future = Future{}
state: plugin_state = plugin_state{}
manager: Manager = Manager{}

// Helper to add scenes dynamically using Odin's append function
create_and_add_scene :: proc(
	name: string,
	update: proc(state: ^plugin_state) -> bool,
	cleanup: proc(state: ^plugin_state),
) {
	scene := create_scene(name, update, cleanup)
	append(&manager.scenes, scene) // Correct use of append
}

// Find scene index by name
index_of_scene :: proc(scene: ^Scene) -> int {
	for sc, i in manager.scenes {
		if sc.name == scene.name {
			return i
		}
	}
	return -1
}

// General Scene Update function
create_scene :: proc(
	name: string,
	update: proc(state: ^plugin_state) -> bool,
	cleanup: proc(state: ^plugin_state),
) -> Scene {
	return Scene{name = name, update = update, cleanup = cleanup}
}

// Scene Logic and Cleanup Functions
scene1_update :: proc(state: ^plugin_state) -> bool {
	if state == nil {
		rl.TraceLog(.ERROR, "State is nil in scene1_update")
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	rl.ClearBackground(rl.Color{30, 30, 30, 255})
	rl.DrawText("Scene 1", 10, 10, 20, rl.Color{255, 255, 255, 255})
	rl.DrawCircle(i32(400 + int(math.sin(state^.t) * 100)), 300, 50, rl.Color{0, 255, 0, 255})

	elapsed_time := rl.GetTime() - state^.scene_start_time

	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene1_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 1 cleanup\n")
}

scene2_update :: proc(state: ^plugin_state) -> bool {
	if state == nil {
		rl.TraceLog(.ERROR, "State is nil in scene2_update")
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

	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	rl.EndMode2D()
	return false
}

scene3_update :: proc(state: ^plugin_state) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.shaders[0]
	}

	// Set background color (gray)
	rl.ClearBackground(rl.Color{128, 128, 128, 255})

	// Update rotation angle for the cube
	state^.t += 0.01

	// Camera setup: Orbiting the object (cube)
	radius := 5.0 // Distance of camera from cube
	angle := state^.t

	// Calculate the camera's position
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0) // Camera height

	// Define camera looking at the center of the scene (where the cube is located)
	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z}, // Camera position
		rl.Vector3{0.0, 0.0, 0.0}, // Target (cube is at the origin)
		rl.Vector3{0.0, 1.0, 0.0}, // Up direction (y-axis)
		45.0, // Field of view
		.PERSPECTIVE, // Projection type
	}

	// Begin 3D mode
	rl.BeginMode3D(camera)

	// Draw "Scene 3" text for debugging
	rl.DrawText("Scene 3", 10, 10, 20, rl.Color{255, 255, 255, 255})

	// Ensure the shader is active
	if state^.current_shader.id != 0 {
		rl.BeginShaderMode(state^.current_shader^)

		// Set the shader matrices
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

		// Set shader uniform values
		modelLoc := rl.GetShaderLocation(state^.current_shader^, "model")
		viewLoc := rl.GetShaderLocation(state^.current_shader^, "view")
		projectionLoc := rl.GetShaderLocation(state^.current_shader^, "projection")
		rl.SetShaderValueMatrix(state^.current_shader^, modelLoc, model)
		rl.SetShaderValueMatrix(state^.current_shader^, viewLoc, view)
		rl.SetShaderValueMatrix(state^.current_shader^, projectionLoc, projection)

		// Set time uniform for animation
		rl.SetShaderValue(
			state^.current_shader^,
			rl.GetShaderLocation(state^.current_shader^, "time"),
			&state^.t,
			.FLOAT,
		)
	}

	// Cube position
	cube_pos := rl.Vector3{0.0, 0.0, 0.0}

	// Draw a red cube at the origin
	rl.DrawCube(cube_pos, 2.0, 2.0, 2.0, rl.Color{255, 0, 0, 255})

	// End 3D mode
	rl.EndMode3D()

	// Check time elapsed to transition to next scene
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 4.0 {
		state^.scene_start_time = -1.0
		return true // Transition to next scene
	}

	return false
}


scene3_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 3 cleanup\n")
}

scene4_update :: proc(state: ^plugin_state) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	// Ensure we have a valid shader
	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.shaders[0] // Assign a shader, ensure it's set
	}

	// Set background color
	rl.ClearBackground(rl.Color{0, 0, 0, 255}) // Black background for contrast

	// Update rotation angle for the cube
	state^.t += 0.01 // Rotate a little each frame

	// Camera setup: orbiting the object (cube)
	radius := 5.0 // Distance of camera from cube
	angle := state^.t // Rotation angle for camera around the object

	// Calculate the camera's position using trigonometric functions
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0) // Keep the camera height fixed

	// Camera looking at the origin (where the cube is centered)
	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z}, // Camera position
		rl.Vector3{0.0, 0.0, 0.0}, // Target is the origin (center of cube)
		rl.Vector3{0.0, 1.0, 0.0}, // Up direction along the y-axis
		45.0, // Field of view (perspective)
		.PERSPECTIVE, // Perspective projection
	}

	// Begin 3D drawing
	rl.BeginMode3D(camera)

	// Draw "Scene 4" text (floating text in 3D space)
	rl.DrawText("Scene 4", 10, 10, 20, rl.Color{255, 255, 255, 255}) // White text

	// Ensure the shader is active
	if state^.current_shader.id != 0 {
		rl.BeginShaderMode(state^.current_shader^)

		// Define the transformation matrices (model, view, projection)
		model := rl.MatrixRotateXYZ(rl.Vector3{f32(state^.t), f32(state^.t), f32(state^.t)}) // Cube rotation
		view := rl.MatrixLookAt(
		rl.Vector3{cam_x, cam_y, cam_z}, // Camera position
		rl.Vector3{0.0, 0.0, 0.0}, // Camera looks at the center of the cube
		rl.Vector3{0.0, 1.0, 0.0}, // "Up" direction
		)
		projection := rl.MatrixPerspective(
			45.0, // Field of view
			f32(rl.GetScreenWidth() / rl.GetScreenHeight()), // Aspect ratio
			0.1, // Near plane
			100.0, // Far plane
		)

		// Set the uniform values for the matrices in the shader
		modelLoc := rl.GetShaderLocation(state^.current_shader^, "model")
		viewLoc := rl.GetShaderLocation(state^.current_shader^, "view")
		projectionLoc := rl.GetShaderLocation(state^.current_shader^, "projection")

		rl.SetShaderValueMatrix(state^.current_shader^, modelLoc, model)
		rl.SetShaderValueMatrix(state^.current_shader^, viewLoc, view)
		rl.SetShaderValueMatrix(state^.current_shader^, projectionLoc, projection)

		// Send the current time to the shader for animations or time-based effects
		rl.SetShaderValue(
			state^.current_shader^,
			rl.GetShaderLocation(state^.current_shader^, "time"),
			&state^.t,
			.FLOAT,
		)
	} else {
		rl.TraceLog(.INFO, "NO SHADER")
	}

	// Cube position (centered at origin)
	cube_pos := rl.Vector3{0.0, 0.0, 0.0}

	// Draw a cube (red colored cube)
	rl.DrawCube(cube_pos, 2.0, 2.0, 2.0, rl.Color{255, 0, 0, 255})

	// End 3D mode (finish drawing in 3D)
	rl.EndMode3D()

	// Time-based condition to transition out of the scene
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 4.0 {
		state^.scene_start_time = -1.0 // Reset the start time
		return true // Transition out of the scene
	}

	return false
}


scene4_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 4 cleanup\n")
}

advance_scene :: proc() {
	fmt.printf("Advancing to next scene\n")
	fmt.printf("Current scene: %s\n", manager.current_scene.name)

	// Find the index of the current scene
	current_index := index_of_scene(manager.current_scene)
	if current_index == -1 {
		rl.TraceLog(.ERROR, "Current scene not found")
		return
	}

	// Set the next scene to be the scene after the current one
	if current_index + 1 < len(manager.scenes) {
		manager.next_scene = &manager.scenes[current_index + 1]
	} else {
		// If it's the last scene, loop back to the first scene
		manager.next_scene = &manager.scenes[0]
	}

	manager.current_scene = manager.next_scene
	manager.next_scene = nil

	// Reset the scene state
	state.frame_count = 0
	state.t = 0.0
	state.scene_start_time = -1.0
}

scene5_update :: proc(state: ^plugin_state) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.shaders[2] // Use the new shader pair
	}

	// Set background color
	rl.ClearBackground(rl.Color{100, 150, 255, 255}) // Light blue background

	// Update the rotation angle for the camera
	state^.t += 0.01 // Control rotation speed

	// Calculate the camera's position around the cube
	radius := 5.0
	angle := state^.t
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0)

	// Define the camera position and target (the cube)
	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z},
		rl.Vector3{0.0, 0.0, 0.0}, // Target the center of the cube
		rl.Vector3{0.0, 1.0, 0.0}, // The 'up' direction is the y-axis
		45.0, // Field of view
		.PERSPECTIVE,
	}

	// Begin drawing in 3D mode
	rl.BeginMode3D(camera)

	// Draw "Scene 5" text at the top-left corner
	rl.DrawText("Scene 5", 10, 10, 20, rl.Color{255, 255, 255, 255})

	// Ensure shader is valid before applying
	if state^.current_shader != nil && state^.current_shader.id != 0 {
		rl.BeginShaderMode(state^.current_shader^)

		// Pass the time value to the shader for color animation
		timeLoc := rl.GetShaderLocation(state^.current_shader^, "time")
		if timeLoc != -1 {
			rl.SetShaderValue(state^.current_shader^, timeLoc, &state^.t, .FLOAT)
		} else {
			rl.TraceLog(.ERROR, "Shader location for 'time' not found")
		}

		// Draw the cube with the shader applied
		rl.DrawCube(rl.Vector3{0.0, 0.0, 0.0}, 2.0, 2.0, 2.0, rl.Color{255, 255, 255, 255})

		rl.EndShaderMode() // End shader mode to revert back to default rendering
	} else {
		rl.TraceLog(.ERROR, "Shader not found or invalid")
	}

	rl.EndMode3D() // End 3D mode

	// Calculate the elapsed time and check if the scene should end
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 4.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}


// Future Scene Timer for scene transitions
start_scene_timer :: proc(duration: f64, on_complete: proc(_: rawptr)) {
	future_state.start_time = rl.GetTime()
	future_state.duration = duration
	future_state.on_complete = on_complete
	future_state.completed = false
}

@(export)
plug_init :: proc "c" () {
	context = runtime.default_context()
	rl.SetTargetFPS(60)

	// Loading shaders with error handling
	shader_rgb := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader.glsl",
	)
	if shader_rgb.id == 0 {
		rl.TraceLog(.ERROR, "Failed to load RGB shader")
	}

	shader_metal := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader_metal.glsl",
	)
	if shader_metal.id == 0 {
		rl.TraceLog(.ERROR, "Failed to load metal shader")
	}

	scene5_shader := rl.LoadShader(
		"./assets/shaders/scene5_vert.glsl",
		"./assets/shaders/scene5_frag.glsl",
	)

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0,
		env              = Env{},
		shaders          = []rl.Shader{shader_metal, shader_rgb, scene5_shader},
		current_shader   = nil,
	}

	// Add scenes dynamically
	create_and_add_scene("Scene 1", scene1_update, scene1_cleanup)
	// create_and_add_scene("Scene 2", scene2_update, scene1_cleanup)
	// create_and_add_scene("Scene 3", scene3_update, scene3_cleanup)
	// create_and_add_scene("Scene 4", scene4_update, scene4_cleanup)
	create_and_add_scene("Scene 5", scene5_update, scene4_cleanup)

	manager = Manager {
		current_scene = &manager.scenes[0],
		next_scene    = &manager.scenes[1],
		scenes        = manager.scenes,
		state_data    = cast(rawptr)&state,
	}

	// Start future state for scene transition
	start_scene_timer(3.0, proc(_: rawptr) {advance_scene()})
}

@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()

	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		fmt.printf("State is nil\n")
		return
	}

	state^.t = rl.GetTime()

	if future_state.completed == false {
		if (state^.t - future_state.start_time) > future_state.duration {
			future_state.completed = true
			if future_state.on_complete != nil {
				future_state.on_complete(manager.state_data)
			}
		}
	}

	fmt.printf("Current scene: %s\n", manager.current_scene.name)
	if manager.current_scene != nil {
		if manager.current_scene.update(state) {
			if manager.current_scene.cleanup != nil {
				manager.current_scene.cleanup(state)
			}

			advance_scene()
		}
	}
}

@(export)
plug_reset :: proc "c" () {
	context = runtime.default_context()
	state.finished = false
	state.frame_count = 0
	state.t = 0.0
	state.scene_start_time = -1.0
	future_state.completed = false
}

@(export)
plug_finished :: proc "c" () -> bool {
	return state.finished
}

@(export)
plug_pre_reload :: proc "c" () -> rawptr {
	return cast(rawptr)(&state)
}

@(export)
plug_post_reload :: proc "c" (prev_state: rawptr) {
	if prev_state != nil {
		prev_state_ptr := cast(^plugin_state)prev_state
		state = prev_state_ptr^
	}
}
