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

scene1_update :: proc(_: rawptr) -> bool {
	// Access global state
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	// Initialize start time for scene 1 on first update
	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	// Draw scene content
	rl.ClearBackground(rl.Color{30, 30, 30, 255}) // Dark background
	rl.DrawText("Scene 1", 10, 10, 20, rl.Color{255, 255, 255, 255})
	rl.DrawCircle(i32(400 + int(math.sin(state^.t) * 100)), 300, 50, rl.Color{0, 255, 0, 255})

	// Check elapsed time since scene started
	elapsed_time := rl.GetTime() - state^.scene_start_time
	rl.TraceLog(.INFO, fmt.caprintf("el %.10f", elapsed_time))

	// If more than 5 seconds have passed, complete the scene
	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0 // Reset for next scene
		return true // Scene 1 is complete
	}

	return false // Scene is still running
}

scene2_update :: proc(_: rawptr) -> bool {
	// Access global state
	state := cast(^plugin_state)(manager.state_data)
	if state == nil {
		return false
	}

	// Initialize start time for scene 2 on first update
	if state^.scene_start_time < 0.0 {
		state^.scene_start_time = rl.GetTime()
	}

	// Draw scene content
	rl.ClearBackground(rl.Color{50, 50, 50, 255}) // Darker background for scene 2
	rl.DrawText("Scene 2", 10, 10, 20, rl.Color{255, 255, 255, 255})

	// For example, let's animate a rotating circle for Scene 2
	state^.t += 0.05 // Change in time or custom animation parameter
	radius := 100
	center_x := f32(rl.GetScreenWidth()) * f32(0.5)
	center_y := f32(rl.GetScreenHeight()) * 0.5
	x_pos := center_x + f32(radius) * f32(math.cos(state^.t))
	y_pos := center_y + f32(radius) * f32(math.sin(state^.t))

	// Draw rotating circle
	rl.DrawCircle(i32(x_pos), i32(y_pos), 30, rl.Color{0, 255, 255, 255}) // Blue circle

	// Check elapsed time since scene started
	elapsed_time := rl.GetTime() - state^.scene_start_time
	rl.TraceLog(.INFO, fmt.caprintf("el %.10f", elapsed_time))

	// If more than 5 seconds have passed, complete the scene
	if elapsed_time > 5.0 {
		state^.scene_start_time = -1.0 // Reset for next scene
		return true // Scene 2 is complete
	}

	return false // Scene is still running
}

scene1_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 1 cleanup\n")
}


scene2_cleanup :: proc(_: rawptr) {
	fmt.printf("Scene 2 cleanup\n")
}

scene1: Scene = Scene {
	update  = scene1_update,
	cleanup = scene1_cleanup,
}
scene2: Scene = Scene {
	update  = scene2_update,
	cleanup = scene2_cleanup,
}

@(export)
plug_init :: proc "c" () {
	context = runtime.default_context()

	state = plugin_state {
		initialized      = true,
		finished         = false,
		frame_count      = 0,
		t                = 0.0,
		scene_start_time = -1.0, // Initialize scene start time
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
		duration = 3.0, // Wait for 3 seconds before Scene2 starts
		on_complete = proc(_: rawptr) {
			fmt.printf("Transitioning to Scene 2\n")
			manager.current_scene = manager.next_scene
		},
	}
}

@(export)
plug_update :: proc "c" (env: Env) {
	context = runtime.default_context()

	// We don't use env.delta_time anymore, rely on GetTime() for time-based logic
	state := cast(^plugin_state)(manager.state_data)
	state^.t = rl.GetTime() // Use Raylib's GetTime for global time

	// Handle future-based transitions (if any)
	if future_state.completed == false {
		if (state^.t - future_state.start_time) > future_state.duration {
			future_state.completed = true
			if future_state.on_complete != nil {
				future_state.on_complete(manager.state_data) // Trigger next scene logic
			}
		}
	}

	// Update the current scene
	if manager.current_scene != nil {
		if manager.current_scene.update(manager.state_data) {
			// Scene completed, cleanup and transition
			if manager.current_scene.cleanup != nil {
				manager.current_scene.cleanup(manager.state_data)
			}
			manager.current_scene = manager.next_scene // Transition to next scene
		}
	}
}

@(export)
plug_reset :: proc "c" () {
	state.finished = false
	state.frame_count = 0
	state.t = 0.0

	// Reset scene management
	manager.current_scene = &scene1
	manager.next_scene = &scene2

	// Reset Future
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
