/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
      pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g_mem` global
      variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 360

GS_Menu :: struct {}

Progress :: enum {
	BEGIN,
	NEW_LEVEL,
	HAS_TORCH,
}
GS_InLevel :: struct {
	current_zoom: f32,
	target_zoom:  f32,
	zoom_speed:   f32,
	progress:     Progress,
}

GS_LevelTransition :: struct {
	time_fade_out: f32,
	time_fade_in:  f32,
	fade:          f32,
	level_loaded:  bool,
	next_level:    int,
}

GS_Won :: struct {}

GameState :: union {
	GS_Menu,
	GS_InLevel,
	GS_LevelTransition,
	GS_Won,
}

init_gs_in_level :: proc() -> GS_InLevel {
	return GS_InLevel{current_zoom = 1, target_zoom = 1, zoom_speed = 2}
}

init_gs_menu :: proc() -> GS_Menu {
	return GS_Menu{}
}

init_gs_level_transition :: proc(next_level: int) -> GS_LevelTransition {
	return GS_LevelTransition {
		time_fade_in = 0,
		time_fade_out = 0,
		level_loaded = false,
		next_level = next_level,
	}
}

LEVEL_AMOUNT :: 2

DebugLight :: enum {
	None,
	Static,
	Dynamic,
	Both,
}
DebugInfo :: struct {
	active:      bool,
	debug_light: DebugLight,
}

Game_Memory :: struct {
	level:    Level,
	level_id: int,
	player:   Player,
	state:    GameState,
	debug:    DebugInfo,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	zoom := f32(1)

	if state, ok := &g_mem.state.(GS_InLevel); ok {
		zoom = state.current_zoom
	}

	return {zoom = zoom, target = g_mem.player.screen_pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

load_level :: proc(level_num: int) {
	destroy_level(&g_mem.level)
	level_string := fmt.aprintf("assets/level%2d.png", level_num)
	g_mem.level, _ = load_level_png(level_string)
	g_mem.level_id = level_num

	player_pos := g_mem.level.player_start_pos

	player := &g_mem.player

	player.pos = player_pos
	player.target_pos = player_pos
	player.screen_pos = {f32(player_pos.x * CELL_SIZE), f32(player_pos.y * CELL_SIZE)}
	player.can_move = true
	player.light = 0
}

check_exit :: proc() -> bool {
	player_pos := g_mem.player.pos
	current_level := g_mem.level

	current_level_id := g_mem.level_id

	if player_pos == current_level.exit_pos {
		if current_level_id <= LEVEL_AMOUNT - 1 {
			g_mem.state = init_gs_level_transition(g_mem.level_id + 1)
		} else {
			g_mem.state = GS_Won{}
		}
		return true
	}

	return false
}

handle_input :: proc() {
	if (rl.IsKeyPressed(.ONE)) {
		g_mem.debug.active = !g_mem.debug.active
	}

	if (rl.IsKeyPressed(.TWO)) {
		debug_light := g_mem.debug.debug_light

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

		g_mem.debug.debug_light = debug_light
	}

	if (rl.IsKeyPressed(.FOUR)) {
		load_level(g_mem.level_id)
	}
	if (rl.IsKeyPressed(.FIVE)) {
		next := g_mem.level_id + 1
		if next > LEVEL_AMOUNT {
			next = 1
		}
		g_mem.level_id = next
		load_level(g_mem.level_id)
	}
}

update_light_zoom :: proc() {
	level := g_mem.level
	player := g_mem.player
	id := player.pos.y * level.width + player.pos.x
	current_cell := level.cells[id]
	dt := rl.GetFrameTime()

	if state, ok := &g_mem.state.(GS_InLevel); ok {
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

update :: proc(dt: f32) {
	switch &state in g_mem.state {
	case GS_InLevel:
		if check_exit() {
			break
		}
		update_player(&g_mem.player, &g_mem.level, dt)
		update_light_zoom()
		handle_input()
		clear_d_light(g_mem.level.cells)
		compute_d_light(g_mem.level)
	case GS_LevelTransition:
		if state.time_fade_in < 1 {
			state.time_fade_in += dt
			state.fade = state.time_fade_in
		} else if !state.level_loaded {
			g_mem.level_id = state.next_level
			load_level(state.next_level)
			state.level_loaded = true
		} else if state.time_fade_out < 1 {
			draw_in_level(g_mem.level, g_mem.player)
			state.time_fade_out += dt
			state.fade = 1 - state.time_fade_out
		} else {
			g_mem.state = init_gs_in_level()
		}
	case GS_Won:
		if rl.IsKeyPressed(.ESCAPE) {
			g_mem.state = init_gs_menu()
		}
	case GS_Menu:
		if rl.IsKeyPressed(.SPACE) {
			g_mem.state = init_gs_level_transition(0)
		}
	}
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

draw_in_level :: proc(level: Level, player: Player) {
	rl.BeginMode2D(game_camera())
	draw_level(level)
	draw_player(player)
	draw_ui(player)
	rl.EndMode2D()
}

draw :: proc(dt: f32) {
	rl.BeginDrawing()

	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()

	switch state in g_mem.state {
	case GS_Menu:
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

	case GS_Won:
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
	case GS_LevelTransition:
		rl.DrawRectangle(0, 0, w, h, rl.Color{0, 0, 0, u8(state.fade * f32(255))})
	case GS_InLevel:
		rl.ClearBackground(rl.BLACK)
		level := g_mem.level
		player := g_mem.player
		draw_in_level(level, player)
	}

	if g_mem.debug.active {
		level := g_mem.level
		player := g_mem.player
		mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), game_camera())
		hovered_cell_pos := Vec2i{int(mouse_world.x / CELL_SIZE), int(mouse_world.y / CELL_SIZE)}

		hovered_cell_id := clamp(
			(hovered_cell_pos.y * level.width + hovered_cell_pos.x),
			0,
			len(level.cells) - 1,
		)
		hovered_cell := level.cells[hovered_cell_id]

		rl.BeginMode2D(game_camera())
		for c in level.cells {
			shown := true
			dbg_light: f32
			switch g_mem.debug.debug_light {
			case .None:
				shown = false
				continue
			case .Dynamic:
				dbg_light = c.d_light
			case .Static:
				dbg_light = c.s_light
			case .Both:
				dbg_light = max(c.d_light, c.s_light)
			}

			x := i32(c.pos.x)
			y := i32(c.pos.y)

			if shown {
				rl.DrawText(
					fmt.ctprintf("%.1f", dbg_light),
					(x * CELL_SIZE + CELL_SIZE / 2) - 3,
					(y * CELL_SIZE + CELL_SIZE / 2) - 4,
					4,
					rl.WHITE,
				)
			}
		}
		rl.EndMode2D()

		rl.BeginMode2D(ui_camera())
		rl.DrawText(
			fmt.ctprintf(
				"current_level: %v\n" +
				"state: %v\n" +
				"player_pos: %v\n" +
				"player_light: %v\n" +
				"player_fear: %v\n" +
				"player_torch_on: %v\n" +
				"light_mode: %v\n" +
				"cell_id: %v\n" +
				"cell_pos: %v\n" +
				"cell_s_light: %v\n" +
				"cell_d_light: %v\n" +
				"cell_type: %v\n" +
				"cell_walkable: %v\n",
				g_mem.level_id + 1,
				g_mem.state,
				player.pos,
				player.light,
				player.fear,
				player.torch_on,
				g_mem.debug.debug_light,
				hovered_cell.id,
				hovered_cell.pos,
				hovered_cell.s_light,
				hovered_cell.d_light,
				hovered_cell.type,
				hovered_cell.walkable,
			),
			5,
			5,
			8,
			rl.WHITE,
		)
		rl.EndMode2D()
	}

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	dt := rl.GetFrameTime()
	update(dt)
	draw(dt)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(1280, 720, "Dark Pathways")
	rl.SetWindowPosition(600, 200)
	rl.SetTargetFPS(60)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		state = init_gs_menu(),
		player = Player{id = new_id()},
	}

	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return true
}

@(export)
game_shutdown :: proc() {
	destroy_level(&g_mem.level)
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	// rl.SetWindowSize(i32(w), i32(h))
}
