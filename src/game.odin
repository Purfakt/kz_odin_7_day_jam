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
GS_Playing :: struct {
	current_zoom: f32,
	target_zoom:  f32,
	zoom_speed:   f32,
}

GS_Won :: struct {}

GameState :: union {
	GS_Menu,
	GS_Playing,
	GS_Won,
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

	if state, ok := &g_mem.state.(GS_Playing); ok {
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

check_exit :: proc() {
	player_pos := g_mem.player.pos
	current_level := g_mem.level

	current_level_id := &g_mem.level_id

	if player_pos == current_level.exit_pos {
		if current_level_id^ <= LEVEL_AMOUNT - 1 {
			current_level_id^ += 1
			load_level(current_level_id^)
		} else {
			g_mem.state = GS_Won{}
		}

	}
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

	if state, ok := &g_mem.state.(GS_Playing); ok {
		light := max(current_cell.d_light, current_cell.s_light, player.light)

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
	check_exit()
	move_player(&g_mem.player, &g_mem.level, dt)
	update_light_zoom()
	handle_input()
	clear_d_light(g_mem.level.cells)
	compute_d_light(g_mem.level)
}

draw :: proc(dt: f32) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	level := g_mem.level
	player := g_mem.player

	switch state in g_mem.state {
	case GS_Won:
		w := rl.GetScreenWidth() / 4
		h := rl.GetScreenHeight() / 4
		font_size := i32(36)
		rl.BeginMode2D(ui_camera())
		rl.DrawText(
			fmt.ctprintf("YOU WON"),
			w - (font_size * 4 / 2),
			h - font_size / 2,
			font_size,
			rl.WHITE,
		)
		rl.EndMode2D()
		break
	case GS_Playing:
		rl.BeginMode2D(game_camera())
		draw_level(level)
		draw_player(player)
		rl.EndMode2D()
	case GS_Menu:
		break
	}

	if g_mem.debug.active {
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
			dbg_light: int
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
					fmt.ctprintf("{}", dbg_light),
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
				"player_pos: %v\n" +
				"player_light: %v\n" +
				"light_mode: %v\n" +
				"cell_id: %v\n" +
				"cell_pos: %v\n" +
				"cell_s_light: %v\n" +
				"cell_d_light: %v\n" +
				"cell_type: %v\n" +
				"cell_walkable: %v\n",
				g_mem.level_id + 1,
				player.pos,
				player.light,
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
		state = GS_Playing{current_zoom = 1, target_zoom = 1, zoom_speed = 2},
		player = Player{id = new_id()},
	}

	load_level(1)

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
