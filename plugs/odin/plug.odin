package plug

import "base:runtime"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

// Define the environment structure
Env :: struct {
	frame_count:  int,
	time_elapsed: f32,
}

// Plugin state structure
plugin_state :: struct {
	initialized: bool,
	finished:    bool,
	frame_count: int,
	env:         Env,
}

state: plugin_state = plugin_state {
	initialized = false,
	finished = false,
	frame_count = 0,
	env = Env{frame_count = 0, time_elapsed = 0.0},
}

// Plugin functions implementation
@(export)
plug_init :: proc() {
	state.initialized = true
	state.finished = false
	state.frame_count = 0
	state.env = Env {
		frame_count  = 0,
		time_elapsed = 0.0,
	}
}

@(export)
plug_pre_reload :: proc() -> rawptr {
	return cast(rawptr)&state
}

@(export)
plug_post_reload :: proc(prev_state: rawptr) {
	if prev_state != nil {
		prev_state_ptr := cast(^plugin_state)prev_state
		state = prev_state_ptr^
	}
}


@(export)
plug_update :: proc(env: Env) {
	state.env = env
	state.frame_count += 1
	if state.frame_count > 100 {
		state.finished = true
	}

	rl.ClearBackground(rl.BLUE)
	fmt.println("update", state.frame_count)
	rl.DrawCircle(100, 100 * i32(state.frame_count / 100), 100, rl.RED)
}

@(export)
plug_reset :: proc() {
	state.finished = false
	state.frame_count = 0
	state.env = Env {
		frame_count  = 0,
		time_elapsed = 0.0,
	}
}

@(export)
plug_finished :: proc() -> bool {
	return state.finished
}
