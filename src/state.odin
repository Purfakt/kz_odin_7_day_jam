package game

import "core:fmt"
import rl "vendor:raylib"

GameState :: struct {
	gs:            GS,
	update:        proc(dt: f32),
	draw:          proc(dt: f32),
	in_transition: bool,
	transition:    Transition,
}

GS :: union {
	GS_Menu,
	GS_Level,
	GS_Won,
}

// ------------
//  TRANSITION
// ------------

TRANSITION_TIME :: 1

Transition :: struct {
	time_fade_out:   f32,
	time_fade_in:    f32,
	fade:            f32,
	fade_in_done:    bool,
	next_state_proc: proc() -> GameState,
}

update_transition :: proc(dt: f32) {
	transition := &gm.state.transition
	if transition.time_fade_in < TRANSITION_TIME {
		transition.time_fade_in += dt
		transition.fade = transition.time_fade_in / TRANSITION_TIME
	} else if !transition.fade_in_done {
		transition.fade_in_done = true
		new_game_state := transition.next_state_proc()
		new_game_state.in_transition = true
		new_game_state.transition = transition^
		gm.state = new_game_state
	} else if transition.time_fade_out < TRANSITION_TIME {
		transition.time_fade_out += dt
		transition.fade = 1 - (transition.time_fade_out / TRANSITION_TIME)
	} else {
		gm.state.in_transition = false
		transition.time_fade_out = 0
		transition.time_fade_in = 0
	}
}

draw_transition :: proc(fade: f32) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	alpha := u8(fade * f32(255))
	rl.DrawRectangle(0, 0, w, h, rl.Color{0, 0, 0, alpha})
}


transition_to :: proc(next_state_proc: proc() -> GameState) {
	transition := Transition {
		time_fade_in    = 0,
		time_fade_out   = 0,
		fade_in_done    = false,
		next_state_proc = next_state_proc,
	}
	gm.state.transition = transition
	gm.state.in_transition = true
}

// ------------
//     MENU
// ------------

GS_Menu :: struct {}

init_gs_menu :: proc() -> GameState {
	return GameState{gs = GS_Menu{}, draw = draw_gs_menu, update = update_gs_menu}
}

update_gs_menu :: proc(dt: f32) {
	if rl.IsKeyPressed(.SPACE) {
		transition_to(proc() -> GameState {return init_gs_level(1, .BEGIN)})
	}
}

draw_gs_menu :: proc(dt: f32) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	rl.ClearBackground(rl.BLACK)
	you_won_font_size := i32(36)
	you_won := fmt.ctprintf("DARK PATHWAYS")
	you_won_len := rl.MeasureText(you_won, you_won_font_size)
	subtext_font_size := i32(24)
	restart_text := fmt.ctprintf("PRESS [SPACE] TO START")
	subtext_len := rl.MeasureText(restart_text, subtext_font_size)
	rl.BeginMode2D(ui_camera())
	rl.DrawText(
		you_won,
		w / 4 - you_won_len / 2,
		h / 4 - you_won_font_size / 2,
		you_won_font_size,
		rl.WHITE,
	)
	rl.DrawText(
		restart_text,
		w / 4 - subtext_len / 2,
		h / 4 + subtext_font_size / 2,
		subtext_font_size,
		rl.WHITE,
	)
	rl.EndMode2D()
}

// ------------
//     LEVEL
// ------------

Progress :: enum {
	BEGIN,
	GOT_TORCH,
	LIT_TORCH,
}

GS_Level :: struct {
	level_id:     int,
	current_zoom: f32,
	target_zoom:  f32,
	zoom_speed:   f32,
	progress:     Progress,
}

check_exit :: proc() -> bool {
	player_pos := gm.player.pos
	current_level := gm.level

	level_state := gm.state.gs.(GS_Level)
	current_level_id := level_state.level_id

	if player_pos == current_level.exit_pos {
		if current_level_id <= LEVEL_AMOUNT - 1 {
			transition_to(proc() -> GameState {return next_gs_level()})
		} else {
			transition_to(proc() -> GameState {return init_gs_won()})
		}
		return true
	}

	return false
}

update_light_zoom :: proc() {
	level := gm.level
	player := gm.player
	id := player.pos.y * level.width + player.pos.x
	current_cell := level.cells[id]
	dt := rl.GetFrameTime()

	if state, ok := &gm.state.gs.(GS_Level); ok {
		light := max(
			current_cell.d_light,
			current_cell.s_light,
			(player.torch_on ? player.light : 0),
		)

		target_zoom := f32(1)

		switch light {
		case -100 ..< 0:
			target_zoom = 5
		case 0 ..< 2:
			target_zoom = 4
		case 2 ..< 6:
			target_zoom = 3
		case 6 ..< 10:
			target_zoom = 2
		case 10 ..< 16:
			target_zoom = 1
		}

		state.target_zoom = target_zoom
		if abs(state.target_zoom - state.current_zoom) > 0.1 {
			state.current_zoom = rl.Lerp(
				state.current_zoom,
				state.target_zoom,
				dt * state.zoom_speed,
			)
		} else {
			state.current_zoom = state.target_zoom
		}
	}
}

update_gs_level :: proc(dt: f32) {
	if (rl.IsKeyPressed(.R)) {
		load_level(gm.state.gs.(GS_Level).level_id)
	}
	clear_d_light(gm.level.cells)
	compute_d_light(gm.level)
	update_light_zoom()
	if check_exit() {
		return
	}
	update_player(&gm.player, &gm.level, dt)
}

draw_ui :: proc(player: Player) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	rl.BeginMode2D(ui_camera())

	if player.light > 0 {
		font_size := i32(16)
		light := player.light
		fmt_str := "Light: %.1f"
		if light - 10 > 0 {
			fmt_str = "Light: %2f"
		}
		ctext := fmt.ctprintf(fmt_str, player.light)
		text_len := rl.MeasureText(ctext, font_size)

		rl.DrawText(ctext, (w / 2) - (text_len) - font_size, 10, font_size, rl.WHITE)
	}

	info_text: cstring

	can_move: bool

	for c in player.surrounding_cells {
		if max(c.d_light, c.s_light) > 0 {
			can_move = true
			break
		}
	}


	target_cell: ^Cell = player.target_cell

	if !can_move && !player.torch_on && player.light > 0 {
		info_text = fmt.ctprint("Press SPACE to light your torch")
	} else if !can_move && player.light <= 0 {
		info_text = fmt.ctprint("Press R to restart the level")
	} else if target_cell != nil &&
	   max(target_cell.d_light, target_cell.s_light) <= 0.01 &&
	   !player.torch_on &&
	   can_move {
		info_text = fmt.ctprint(FEAR_TEXT[0])
	}

	font_size := i32(24)
	text_len := rl.MeasureText(info_text, font_size)
	rl.DrawText(
		info_text,
		(w / 4) - (text_len / 2),
		(h / 2) - (font_size * 2),
		font_size,
		rl.WHITE,
	)

	rl.EndMode2D()
}

draw_gs_level :: proc(dt: f32) {
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(game_camera())
	draw_level(gm.level)
	draw_player(gm.player)
	draw_ui(gm.player)
	rl.EndMode2D()
}


next_gs_level :: proc() -> GameState {
	level_id: int = 1
	progress: Progress = .BEGIN
	if level, is_level := gm.state.gs.(GS_Level); is_level {
		level_id = level.level_id + 1
		progress = level.progress
	}

	return init_gs_level(level_id, progress)
}

init_gs_level :: proc(level_id: int, progress: Progress) -> GameState {
	load_level(level_id)
	return GameState {
		gs = GS_Level {
			level_id = level_id,
			current_zoom = 1,
			target_zoom = 1,
			zoom_speed = 2,
			progress = progress,
		},
		update = update_gs_level,
		draw = draw_gs_level,
	}
}


// ------------
//     WON
// ------------

GS_Won :: struct {}

draw_gs_won :: proc(dt: f32) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	rl.ClearBackground(rl.BLACK)
	you_won_font_size := i32(36)
	you_won := fmt.ctprintf("YOU WON")
	you_won_len := rl.MeasureText(you_won, you_won_font_size)
	subtext_font_size := i32(24)
	subtext := fmt.ctprintf("PRESS [ESC] FOR MENU")
	subtext_len := rl.MeasureText(subtext, subtext_font_size)
	rl.BeginMode2D(ui_camera())
	rl.DrawText(
		you_won,
		w / 4 - you_won_len / 2,
		h / 4 - you_won_font_size / 2,
		you_won_font_size,
		rl.WHITE,
	)
	rl.DrawText(
		subtext,
		w / 4 - subtext_len / 2,
		h / 4 + subtext_font_size / 2,
		subtext_font_size,
		rl.WHITE,
	)
	rl.EndMode2D()
}

init_gs_won :: proc() -> GameState {
	return GameState{gs = GS_Won{}, draw = draw_gs_won, update = proc(dt: f32) {
			if rl.IsKeyPressed(.ESCAPE) {
				gm.state = init_gs_menu()
			}
		}}
}
