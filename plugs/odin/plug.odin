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

	return false
}

scene2_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 2 cleanup\n")
}

scene3_update :: proc(state: ^plugin_state) -> bool {
	if state == nil {
		rl.TraceLog(.ERROR, "State is nil in scene3_update")
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
		state^.current_shader = &state^.shaders[0]
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

	rl.DrawText("Scene 3", 10, 10, 20, rl.Color{255, 255, 255, 255})

	rl.BeginMode3D(camera)

	if state^.current_shader != nil {
		rl.BeginShaderMode(state^.current_shader^)
		rotation_matrix := rl.MatrixRotateXYZ(
			rl.Vector3{f32(state^.t), f32(state^.t), f32(state^.t)},
		)
		rl.DrawCube(rl.Vector3{0.0, 0.0, 0.0}, 2.0, 2.0, 2.0, rl.Color{255, 0, 0, 255})
		rl.EndShaderMode()
	}

	rl.EndMode3D()

	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 4.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene3_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 3 cleanup\n")
}

scene4_update :: proc(state: ^plugin_state) -> bool {
	if state == nil {
		rl.TraceLog(.ERROR, "State is nil in scene4_update")
		return false
	}

	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	rl.ClearBackground(rl.Color{30, 30, 30, 255})

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

	rl.BeginMode3D(camera)

	if state^.current_shader != nil {
		rl.BeginShaderMode(state^.current_shader^)

		timeLoc := rl.GetShaderLocation(state^.current_shader^, "time")
		value: f32 = cast(f32)state^.t
		rl.SetShaderValue(state^.current_shader^, timeLoc, &value, .FLOAT)

		rl.DrawCube(rl.Vector3{0.0, 0.0, 0.0}, 2.0, 2.0, 2.0, rl.Color{255, 255, 255, 255})
		rl.EndShaderMode()
	}

	rl.EndMode3D()

	elapsed_time := rl.GetTime() - state^.scene_start_time
	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0
		return true
	}

	return false
}

scene4_cleanup :: proc(state: ^plugin_state) {
	fmt.printf("Scene 4 cleanup\n")
}

advance_scene :: proc() {
	// Transition to the next scene
	manager.current_scene = manager.next_scene
	manager.next_scene = nil

	if len(manager.scenes) > 0 {
		// Loop back to the first scene after reaching the last one
		manager.next_scene = &manager.scenes[0]
	}

	// Reset the scene state
	state.frame_count = 0
	state.t = 0.0
	state.scene_start_time = -1.0
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

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0,
		env              = Env{},
		shaders          = []rl.Shader{shader_rgb, shader_metal},
		current_shader   = nil,
	}

	// Add scenes dynamically
	create_and_add_scene("Scene 1", scene1_update, scene1_cleanup)
	create_and_add_scene("Scene 2", scene2_update, scene2_cleanup)
	create_and_add_scene("Scene 3", scene3_update, scene3_cleanup)
	create_and_add_scene("Scene 4", scene4_update, scene4_cleanup)

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

	manager.current_scene = &manager.scenes[0]

	// Reset future state for scene transition
	start_scene_timer(3.0, proc(_: rawptr) {advance_scene()})
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
