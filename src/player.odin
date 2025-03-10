package game

import rl "vendor:raylib"

Player :: struct {
	using entity: Entity,
	screen_pos:   rl.Vector2,
	target_pos:   Vec2i,
	can_move:     bool,
	light:        int,
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
	has_moved := false

	if player.light != 0 {
		level.d_light_sources[player.id] = LightSource{player.target_pos, player.light}
	}

	if can_move^ {
		new_target := handle_movement_input(target_pos^)

		if new_target == target_pos^ {
			return
		}

		grid_size := (level.width * level.height) - 1
		idx := clamp((new_target.y * level.width) + new_target.x, 0, grid_size)
		cell := &level.cells[idx]

		if cell.walkable {
			target_pos^ = new_target
			has_moved = true
			if item, has_item := level.items[new_target]; has_item {
				player.light += item.light
				delete_key(&level.items, new_target)
				if _, has_source := level.d_light_sources[item.id]; has_source {
					delete_key(&level.d_light_sources, item.id)
				}
			}
		}
	}

	tar_pos: rl.Vector2 = {f32(target_pos^.x * CELL_SIZE), f32(target_pos^.y * CELL_SIZE)}

	if (rl.Vector2Distance(screen_pos^, tar_pos) < 0.1) {
		screen_pos^ = tar_pos
		player.pos = target_pos^
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
