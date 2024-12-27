package plug

import "base:runtime"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCENE2_PLAYTIME_SECS :: 2.0

Env :: struct {
	delta_time:    f32,
	screen_width:  f32,
	screen_height: f32,
}

Scene :: struct {
	update:  proc(_: rawptr) -> bool,
	cleanup: proc(_: rawptr),
}

plugin_state :: struct {
	initialized:      bool,
	finished:         bool,
	frame_count:      int,
	t:                f64,
	scene_start_time: f64,
	scene_shader:     rl.Shader,
	metal_shader:     rl.Shader,
	current_shader:   rl.Shader,
}

Manager :: struct {
	current_scene: ^Scene,
	next_scene:    ^Scene,
	state_data:    rawptr,
}

state: plugin_state = plugin_state{}
manager: Manager = Manager{}

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
	if elapsed_time > 1.0 {
		state^.scene_start_time = -1.0
		return true
	}
	return false
}

scene1_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 1 cleanup\n")
}

scene2_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	rl.ClearBackground(rl.Color{50, 50, 50, 255})
	state^.t += 0.01
	radius := 5.0
	angle := state^.t
	cam_x := f32(radius) * f32(math.cos(angle))
	cam_z := f32(radius) * f32(math.sin(angle))
	cam_y := f32(2.0)

	camera := rl.Camera3D {
		rl.Vector3{cam_x, cam_y, cam_z},
		rl.Vector3{0.0, 0.0, 0.0},
		rl.Vector3{0.0, 1.0, 0.0},
		45.0,
		.PERSPECTIVE,
	}

	rl.DrawText("Scene 2 - Spinning Cube", 10, 10, 20, rl.Color{255, 255, 255, 255})
	rl.BeginMode3D(camera)


	if state.scene_shader.id != 0 {
		state.current_shader = state.metal_shader
		rl.BeginShaderMode(state.current_shader)

		model := rl.MatrixRotateXYZ(rl.Vector3{f32(state^.t), f32(state^.t), f32(state^.t)})
		view := rl.MatrixLookAt(
			rl.Vector3{cam_x, cam_y, cam_z},
			rl.Vector3{0.0, 0.0, 0.0},
			rl.Vector3{0.0, 1.0, 0.0},
		)
		projection := rl.MatrixPerspective(
			45.0,
			f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight()),
			0.1,
			100.0,
		)

		modelLoc := rl.GetShaderLocation(state.current_shader, "model")
		viewLoc := rl.GetShaderLocation(state.current_shader, "view")
		projectionLoc := rl.GetShaderLocation(state.current_shader, "projection")

		rl.SetShaderValueMatrix(state.current_shader, modelLoc, model)
		rl.SetShaderValueMatrix(state.current_shader, viewLoc, view)
		rl.SetShaderValueMatrix(state.current_shader, projectionLoc, projection)

		cube_pos := rl.Vector3{0.0, 0.0, 0.0}
		rl.DrawCube(cube_pos, 2.0, 2.0, 2.0, rl.Color{255, 0, 0, 255})

		rl.EndShaderMode()
	}

	rl.EndMode3D()

	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > SCENE2_PLAYTIME_SECS {
		state^.scene_start_time = -1.0
		return true
	}
	return false
}


scene2_cleanup :: proc(_: rawptr) {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return
	}

	fmt.printf("Scene 2 cleanup\n")

	// rl.UnloadShader(state.current_shader)
}

scene3_update :: proc(_: rawptr) -> bool {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	// Initialize scene start time if it's not set
	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	// Clear the background with a dark color
	rl.ClearBackground(rl.Color{50, 50, 50, 255})

	// Increment time for animation
	state^.t += 0.01
	radius := 5.0
	angle := state^.t
	cam_x := radius * math.cos(angle)
	cam_z := radius * math.sin(angle)
	cam_y := 2.0

	// Set up the camera position (camera moves in a circle around the center)
	camera := rl.Camera3D {
		rl.Vector3{f32(cam_x), f32(cam_y), f32(cam_z)},
		rl.Vector3{0.0, 0.0, 0.0},
		rl.Vector3{0.0, 1.0, 0.0},
		45.0,
		.PERSPECTIVE,
	}

	// Draw text to indicate the current scene
	rl.DrawText("Scene 3 - Galaxy Effect", 10, 10, 20, rl.Color{255, 255, 255, 255})

	// Begin 3D rendering mode
	rl.BeginMode3D(camera)

	// Apply the galaxy shader if it's available
	if state.scene_shader.id != 0 {
		state.current_shader = state.scene_shader
		rl.BeginShaderMode(state.current_shader)

		// Set the time uniform for animation (iTime)
		rl.SetShaderValue(
			state.current_shader,
			rl.GetShaderLocation(state.current_shader, "iTime"),
			&state^.t,
			.FLOAT,
		)

		// Set the screen resolution uniform (iResolution)
		screen_resolution := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		rl.SetShaderValue(
			state.current_shader,
			rl.GetShaderLocation(state.current_shader, "iResolution"),
			&screen_resolution,
			.VEC2,
		)

		// Set model, view, and projection matrices for transformation (optional)
		model := rl.MatrixIdentity() // Identity matrix for the model, you can apply rotation/scale if needed
		view := rl.MatrixLookAt(
			rl.Vector3{f32(cam_x), f32(cam_y), f32(cam_z)},
			rl.Vector3{0.0, 0.0, 0.0},
			rl.Vector3{0.0, 1.0, 0.0},
		)
		projection := rl.MatrixPerspective(
			45.0,
			f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight()),
			0.1,
			100.0,
		)

		// Pass matrices to the shader
		rl.SetShaderValueMatrix(
			state.current_shader,
			rl.GetShaderLocation(state.current_shader, "model"),
			model,
		)
		rl.SetShaderValueMatrix(
			state.current_shader,
			rl.GetShaderLocation(state.current_shader, "view"),
			view,
		)
		rl.SetShaderValueMatrix(
			state.current_shader,
			rl.GetShaderLocation(state.current_shader, "projection"),
			projection,
		)

		// Render a sphere to visualize the galaxy effect
		// Adjust the sphere's size, color, and position as needed for your effect
		cube_pos := rl.Vector3{0.0, 0.0, 0.0}
		rl.DrawSphere(cube_pos, 2.0, rl.Color{255, 255, 255, 255}) // You can change this to other objects for more variety

		// End shader mode
		rl.EndShaderMode()
	}

	// End 3D rendering mode
	rl.EndMode3D()

	// Check for elapsed time and transition scenes if necessary
	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > SCENE2_PLAYTIME_SECS {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene3_cleanup :: proc(_: rawptr) {
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return
	}

	fmt.printf("Scene 3 cleanup\n")

	// Unload the galaxy shader
	// rl.UnloadShader(state^.current_shader)
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

	shader_rgb := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader.glsl",
	)

	shader_metal := rl.LoadShader(
		"./assets/shaders/vertex_shader.glsl",
		"./assets/shaders/fragment_shader_metal.glsl",
	)

	shader_galaxy := rl.LoadShader(
		"./assets/shaders/vertex_shader_galaxy.glsl",
		"./assets/shaders/fragment_shader_galaxy.glsl",
	)

	rl.TraceLog(.INFO, fmt.caprintf("Shader loaded okay %p", rl.IsShaderReady(shader_rgb)))

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0,
		scene_shader     = shader_galaxy,
		metal_shader     = shader_metal,
		current_shader   = shader_galaxy,
	}

	manager = Manager {
		current_scene = &scene1,
		next_scene    = &scene2,
		state_data    = cast(rawptr)&state,
	}
}

@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()

	state := cast(^plugin_state)(manager.state_data)
	state^.t = rl.GetTime()

	// Handle scene switching via time
	if manager.current_scene != nil {
		if manager.current_scene.update(manager.state_data) {
			if manager.current_scene.cleanup != nil {
				manager.current_scene.cleanup(manager.state_data)
			}

			// Transition between scenes based on a fixed time interval
			if manager.current_scene == &scene1 {
				manager.current_scene = &scene2

			} else if manager.current_scene == &scene2 {
				manager.current_scene = &scene3
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
