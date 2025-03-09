package game

import rl "vendor:raylib"

Player :: struct {
	screen_pos:  rl.Vector2,
	current_pos: Vec2i,
	target_pos:  Vec2i,
	can_move:    bool,
}

handle_movement_input :: proc(current_pos: Vec2i) -> Vec2i {
	target: Vec2i = current_pos
	if (rl.IsKeyDown(.A)) {
		target.x -= 1
	}
	if (rl.IsKeyDown(.D)) {
		target.x += 1
	}
	if (rl.IsKeyDown(.W)) {
		target.y -= 1
	}
	if (rl.IsKeyDown(.S)) {
		target.y += 1
	}

	return target
}

move_player :: proc(player: ^Player, level: ^Level, frame_time: f32) {
	speed: f32 = 25

	if rl.IsKeyDown(.LEFT_SHIFT) {
		speed = 50
	}

	target_pos := &player.target_pos
	screen_pos := &player.screen_pos
	can_move := &player.can_move

	if can_move^ {
		new_target := handle_movement_input(target_pos^)

		if new_target == target_pos^ {
			return
		}

		grid_size := (level.width * level.height) - 1
		idx := clamp((new_target.y * level.width) + new_target.x, 0, grid_size)
		cell := level.cells[idx]

		#partial switch t in cell.type {
		case CellFloor, CellExit:
			target_pos^ = new_target
		}
	}

	tar_pos: rl.Vector2 = {f32(target_pos^.x * CELL_SIZE), f32(target_pos^.y * CELL_SIZE)}

	if (rl.Vector2Distance(screen_pos^, tar_pos) < 0.1) {
		screen_pos^ = tar_pos
		player.current_pos = target_pos^
		can_move^ = true
	} else {
		screen_pos^.xy += (tar_pos.xy - screen_pos^.xy) * frame_time * speed
		can_move^ = false
	}
}

draw_player :: proc(player: Player) {
	player_rect := rl.Rectangle{player.screen_pos.x, player.screen_pos.y, CELL_SIZE, CELL_SIZE}

	rl.DrawRectangleRec(player_rect, rl.WHITE)
}
