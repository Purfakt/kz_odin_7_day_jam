package game

import rl "vendor:raylib"

@(rodata)
FEAR_TEXT := [?]string{"It's too dark in there", "I can't see anything", "Better take a step back"}

Player :: struct {
	using entity:      Entity,
	screen_pos:        rl.Vector2,
	target_pos:        Vec2i,
	flip_x:            bool,
	target_cell:       ^Cell,
	surrounding_cells: [8]Cell,
	can_move:          bool,
	light:             f32,
	torch_on:          bool,
}

init_player :: proc() -> Player {return {id = new_id()}}

handle_movement_input :: proc() -> Vec2i {
	target: Vec2i
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

update_player :: proc(player: ^Player, level: ^Level, frame_time: f32) {
	speed: f32 = 25
	light_per_step: f32 = 0.2

	for cp, i in CARDINAL_POINTS {
		index := (player.pos.y + cp.y) * gm.level.width + (player.pos.x + cp.x)
		player.surrounding_cells[i] = gm.level.cells[index]
	}

	if rl.IsKeyDown(.LEFT_SHIFT) {
		speed = 50
	}

	target_pos := &player.target_pos
	screen_pos := &player.screen_pos
	can_move := &player.can_move

	gs := gm.state.gs.(GS_Level)


	if (gs.progress == .GOT_TORCH && rl.IsKeyPressed(.SPACE)) {
		if player.torch_on {play_torch_off_sound()} else {play_torch_on_sound()}
		player.torch_on = !player.torch_on
	}

	if player.torch_on && player.light != 0 {
		if gs.progress == .GOT_TORCH {
			gs.progress = .LIT_TORCH
		}
		level.d_light_sources[player.id] = LightSource{player.target_pos, player.light}
	} else if _, has_player_source := level.d_light_sources[player.id]; has_player_source {
		delete_key(&level.d_light_sources, player.id)
	}

	if can_move^ {
		direction := handle_movement_input()
		new_target := target_pos^ + direction

		if new_target == target_pos^ {
			return
		}

		grid_size := (level.width * level.height) - 1
		idx := clamp((new_target.y * level.width) + new_target.x, 0, grid_size)
		cell := &level.cells[idx]
		player.target_cell = cell

		cell_light := max(cell.d_light, cell.s_light)

		if ((player.light > 0 && player.torch_on) || cell_light > 0) && cell.walkable {
			target_pos^ = new_target
			player.flip_x = direction.x == 0 ? player.flip_x : direction.x < 0
			play_step_sound()

			if player.torch_on {
				player.light -= player.light <= 0 ? 0 : light_per_step
			}
			if item, has_item := level.items[new_target]; has_item && item.pickable {
				if gs, is_level := &gm.state.gs.(GS_Level); is_level && gs.progress == .BEGIN {
					gs.progress = .GOT_TORCH
				}
				player.light += item.light
				play_torch_item_sound()
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
	source := AtlasSprite[.Player_Fine]

	switch gm.state.gs.(GS_Level).target_zoom {
	case 0 ..< 2:
		source = AtlasSprite[.Player_Fine]
	case 2 ..< 3:
		source = AtlasSprite[.Player_Meh]
	case 3 ..< 4:
		source = AtlasSprite[.Player_Scared]
	case 4 ..< 1000:
		source = AtlasSprite[.Player_Cry]
	}

	if player.flip_x {
		source.width = -source.width
	}
	rl.DrawTextureRec(gm.atlas, source, {player.screen_pos.x, player.screen_pos.y}, rl.WHITE)

	if player.torch_on {
		torch_source := AtlasSprite[.Torch]
		x_offset := f32(CELL_SIZE / 2.5)
		if player.flip_x {
			torch_source.width = -torch_source.width
			x_offset = -x_offset
		}
		rl.DrawTextureRec(
			gm.atlas,
			torch_source,
			{player.screen_pos.x + f32(x_offset), player.screen_pos.y},
			rl.WHITE,
		)
	}
}
