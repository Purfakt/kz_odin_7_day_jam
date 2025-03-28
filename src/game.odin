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
- game_hot_reloaded: Run after a hot reload so that the `gm` global
      variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 360

LEVEL_AMOUNT :: 3

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
	level:  Level,
	player: Player,
	state:  GameState,
	debug:  DebugInfo,
	atlas:  rl.Texture2D,
	audio:  Audio,
}

gm: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	zoom := f32(1)

	if state, ok := &gm.state.gs.(GS_Level); ok {
		zoom = state.current_zoom * 2
	}

	return {zoom = zoom, target = gm.player.screen_pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

load_level :: proc(level_num: int) {
	destroy_level(&gm.level)
	level_string := fmt.tprintf("assets/level%2d.png", level_num)
	gm.level, _ = load_level_png(level_string)
	player_pos := gm.level.player_start_pos

	player := &gm.player

	player.pos = player_pos
	player.target_pos = player_pos
	player.target_cell = &gm.level.cells[player_pos.y * gm.level.width + player_pos.x]
	player.screen_pos = {f32(player_pos.x * CELL_SIZE), f32(player_pos.y * CELL_SIZE)}

	for cp, i in CARDINAL_POINTS {
		index := (player.pos.y + cp.y) * gm.level.width + (player.pos.x + cp.x)
		player.surrounding_cells[i] = gm.level.cells[index]
	}

	player.can_move = true
	player.light = 0
	player.torch_on = false
}

handle_input :: proc() {
	if (rl.IsKeyPressed(.ONE)) {
		gm.debug.active = !gm.debug.active
	}

	if (rl.IsKeyPressed(.M)) {
		volume := gm.audio.volume
		set_audio_level(volume > 0.5 ? 0 : 1)
	}

	gs := gm.state.gs
	#partial switch state in gs {
	case GS_Level:
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
			load_level(state.level_id)
		}
		if (rl.IsKeyPressed(.FIVE)) {
			next := state.level_id + 1
			if next > LEVEL_AMOUNT {
				next = 1
			}
			gm.state = init_gs_level(next, state.progress)
		}
	}
}


update :: proc(dt: f32) {
	play_music()
	handle_input()
	if gm.state.in_transition {
		update_transition(dt)
		return
	}
	gm.state.update(dt)
}


draw :: proc(dt: f32) {
	rl.BeginDrawing()

	gm.state.draw(dt)
	if gm.state.in_transition {draw_transition(gm.state.transition.fade)}
	if gm.debug.active {draw_debug()}

	rl.EndDrawing()
}

draw_debug :: proc() {
	gs := gm.state.gs

	switch state in gs {
	case GS_Menu:
		rl.BeginMode2D(ui_camera())
		rl.DrawText(fmt.ctprintf("state: %v", gm.state), 5, 5, 8, rl.WHITE)
		rl.EndMode2D()
	case GS_Level:
		level := gm.level
		player := gm.player
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
			switch gm.debug.debug_light {
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
				"state: %v\n" +
				"player_pos: %v\n" +
				"player_light: %v\n" +
				"player_torch_on: %v\n" +
				"light_mode: %v\n" +
				"cell_id: %v\n" +
				"cell_pos: %v\n" +
				"cell_s_light: %v\n" +
				"cell_d_light: %v\n" +
				"cell_type: %v\n" +
				"cell_walkable: %v\n",
				gm.state,
				player.pos,
				player.light,
				player.torch_on,
				gm.debug.debug_light,
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
	case GS_Won:
		rl.BeginMode2D(ui_camera())
		rl.DrawText(fmt.ctprintf("state: %v", gm.state), 5, 5, 8, rl.WHITE)
		rl.EndMode2D()
	}

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
	rl.InitAudioDevice()
	rl.SetAudioStreamBufferSizeDefault(4096)

	gm = new(Game_Memory)

	gm^ = Game_Memory {
		state  = init_gs_menu(),
		player = init_player(),
		atlas  = init_atlas(),
		audio  = init_sounds(),
	}

	game_hot_reloaded(gm)
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
	rl.CloseAudioDevice()
	destroy_level(&gm.level)
	destroy_sounds()
	free(gm)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return gm
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	gm = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `gm`.
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
