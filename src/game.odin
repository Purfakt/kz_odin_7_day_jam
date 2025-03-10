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
GS_Playing :: struct {}
GS_Won :: struct {}

GameState :: union {
	GS_Menu,
	GS_Playing,
	GS_Won,
}

Game_Memory :: struct {
	levels:            [dynamic]Level,
	current_level_idx: int,
	player:            Player,
	state:             GameState,
	debug:             bool,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h / PIXEL_WINDOW_HEIGHT,
		target = g_mem.player.screen_pos,
		offset = {w / 2, h / 2},
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

load_level :: proc(level_num: int) {
	player_pos := g_mem.levels[g_mem.current_level_idx].player_pos
	g_mem.player.current_pos = player_pos
	g_mem.player.target_pos = player_pos
	g_mem.player.screen_pos = {f32(player_pos.x * CELL_SIZE), f32(player_pos.y * CELL_SIZE)}
	g_mem.player.can_move = true
}

check_exit :: proc() {
	player_pos := g_mem.player.current_pos
	current_level_idx := &g_mem.current_level_idx
	current_level := g_mem.levels[current_level_idx^]

	if player_pos == current_level.exit_pos {
		if current_level_idx^ < len(g_mem.levels) - 1 {
			current_level_idx^ += 1
			load_level(current_level_idx^)
		} else {
			g_mem.state = GS_Won{}
		}

	}
}

handle_input :: proc() {
	if (rl.IsKeyPressed(.ONE)) {
		g_mem.debug = !g_mem.debug
	}

	if (rl.IsKeyPressed(.FOUR)) {
		load_level(g_mem.current_level_idx)
	}
	if (rl.IsKeyPressed(.FIVE)) {
		next := g_mem.current_level_idx + 1
		if next >= len(g_mem.levels) {
			next = 0
		}
		g_mem.current_level_idx = next
		load_level(g_mem.current_level_idx)
	}
}

update :: proc(dt: f32) {
	check_exit()
	move_player(&g_mem.player, &g_mem.levels[g_mem.current_level_idx], dt)
	handle_input()
}

draw :: proc(dt: f32) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch state in g_mem.state {
	case GS_Won:
		rl.BeginMode2D(ui_camera())
		rl.DrawText(fmt.ctprintf("YOU WON"), 140, 90 - 4, 8, rl.WHITE)

		rl.EndMode2D()
		break
	case GS_Playing:
		rl.BeginMode2D(game_camera())
		draw_level(g_mem.levels[g_mem.current_level_idx])
		draw_player(g_mem.player)
		rl.EndMode2D()
	case GS_Menu:
		break
	}

	if g_mem.debug {
		rl.BeginMode2D(ui_camera())
		rl.DrawText(
			fmt.ctprintf(
				"current_level: %v\nplayer_pos: %v",
				g_mem.current_level_idx + 1,
				g_mem.player.current_pos,
			),
			5,
			5,
			8,
			rl.WHITE,
		)
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

	lvl1, _ := load_level_png("assets/level01.png")
	lvl2, _ := load_level_png("assets/level02.png")

	levels := make([dynamic]Level, 2)
	levels[0] = lvl1
	levels[1] = lvl2

	g_mem^ = Game_Memory {
		state  = GS_Playing{},
		levels = levels,
	}

	load_level(0)

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
	for level in g_mem.levels {
		delete(level.cells)
	}
	delete(g_mem.levels)
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
	rl.SetWindowSize(i32(w), i32(h))
}
