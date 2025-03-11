package game

import "core:fmt"
import rl "vendor:raylib"

GameState :: struct {
	gs:     GS,
	update: proc(dt: f32),
	draw:   proc(dt: f32),
	// should_transition: bool,
	// transition:        Transition,
}

GS :: union {
	GS_Menu,
	GS_Level,
	GS_Won,
}

// ------------
//  TRANSITION
// ------------

Transition :: struct {
	time_fade_out: f32,
	time_fade_in:  f32,
	fade:          f32,
	fade_in_done:  bool,
	next_state:    ^GameState,
}

// update_transition :: proc(dt: f32) {
// 	transition := &gm.state.transition
// 	if transition.time_fade_in < 1 {
// 		transition.time_fade_in += dt
// 		transition.fade = transition.time_fade_in
// 	} else if !transition.fade_in_done {
// 		switch gs in transition.next_state.gs {
// 		case GS_Level:
// 			progress := Progress.BEGIN
// 			if previous_level, is_level := gm.state.gs.(GS_Level); is_level {
// 				progress = previous_level.progress
// 			}
// 			gm.state = init_gs_level(gs.level_id, progress)
// 			load_level(gs.level_id)
// 		case GS_Menu:
// 			gm.state = init_gs_menu()
// 		case GS_Won:
// 			gm.state = init_gs_won()
// 		}
// 		transition.fade_in_done = true
// 	} else if transition.time_fade_out < 1 {
// 		transition.time_fade_out += dt
// 		transition.fade = 1 - transition.time_fade_out
// 	} else {
// 		gm.state.should_transition = false
// 	}
// }

// draw_transition :: proc(fade: f32) {
// 	w := rl.GetScreenWidth()
// 	h := rl.GetScreenHeight()

// 	rl.DrawRectangle(0, 0, w, h, rl.Color{0, 0, 0, u8(fade * f32(255))})
// }


init_gs_level_transition :: proc(next_state: ^GameState) -> Transition {
	return Transition {
		time_fade_in = 0,
		time_fade_out = 0,
		fade_in_done = false,
		next_state = next_state,
	}
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
		// gm.state.should_transition = true
		gm.state = init_gs_level(1, .BEGIN)
		// gm.state.transition = init_gs_level_transition(&next_state)
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
	NEW_LEVEL,
	HAS_TORCH,
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

	fmt.printfln("{} {}", gm.player.pos, current_level)
	level_state := gm.state.gs.(GS_Level)
	current_level_id := level_state.level_id

	if player_pos == current_level.exit_pos {
		if current_level_id <= LEVEL_AMOUNT - 1 {
			// next_level := init_gs_level(current_level_id, progress)
			gm.state = init_gs_level(current_level_id + 1, level_state.progress)
			// gm.state.should_transition = true
		} else {
			// next_state := init_gs_won()
			gm.state = init_gs_won()
			// gm.state.should_transition = true
		}
		return true
	}

	return false
}

handle_input :: proc() {
	if (rl.IsKeyPressed(.ONE)) {
		gm.debug.active = !gm.debug.active
	}

	if (rl.IsKeyPressed(.TWO)) {
		debug_light := gm.debug.debug_light

		switch debug_light {
		case .None:
			debug_light = .Static
		case .Static:
			debug_light = .Dynamic
		case .Dynamic:
			debug_light = .Both
		case .Both:
			debug_light = .None
		}

		gm.debug.debug_light = debug_light
	}

	if (rl.IsKeyPressed(.FOUR)) {
		load_level(gm.state.gs.(GS_Level).level_id)
	}
	if (rl.IsKeyPressed(.FIVE)) {
		level := gm.state.gs.(GS_Level)
		next := level.level_id + 1
		if next > LEVEL_AMOUNT {
			next = 1
		}
		gm.state = init_gs_level(next, .BEGIN)
	}
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
		case 0:
			target_zoom = 5
		case 1 ..< 2:
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

	if check_exit() {
		// fmt.println(gm.state)
		return
	}
	update_player(&gm.player, &gm.level, dt)
	update_light_zoom()
	handle_input()
	clear_d_light(gm.level.cells)
	compute_d_light(gm.level)
	// fmt.println("hello")
}

draw_ui :: proc(player: Player) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	rl.BeginMode2D(ui_camera())

	if player.light > 0 {
		font_size := i32(16)
		light := player.light
		fmt_str := "Holding Light: %.1f"
		if light - 10 > 0 {
			fmt_str = "Holding Light: %2f"
		}
		ctext := fmt.ctprintf(fmt_str, player.light)
		text_len := rl.MeasureText(ctext, font_size)

		rl.DrawText(ctext, (w / 2) - (text_len) - font_size, 10, font_size, rl.WHITE)
	}

	if player.fear > MAX_LIGHT - 1.5 {

		font_size := i32(24)

		ctext := fmt.ctprint(FEAR_TEXT[0])
		text_len := rl.MeasureText(ctext, font_size)

		rl.DrawText(
			ctext,
			(w / 4) - (text_len / 2),
			(h / 2) - (font_size * 2),
			font_size,
			rl.WHITE,
		)
	}
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
