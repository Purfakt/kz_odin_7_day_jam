package game

import "core:fmt"
import "core:math"
import u "utils"
import rl "vendor:raylib"

Vec2i :: [2]int
// --------------
//      GRID
// --------------

CELL_SIZE :: 16
MAX_LIGHT :: 16

LightSource :: struct {
	pos:      Vec2i,
	strength: f32,
}

Level :: struct {
	cells:            [dynamic]Cell,
	items:            map[Vec2i]Item,
	player_start_pos: Vec2i,
	exit_pos:         Vec2i,
	width:            int,
	height:           int,
	d_light_sources:  map[Id]LightSource,
}

COL_FLOOR :: rl.Color{10, 10, 10, 255}
COL_WALL :: rl.Color{27, 28, 51, 255}
COL_WALL_TORCH :: rl.Color{230, 218, 41, 255}
COL_ITEM_TORCH :: rl.Color{218, 125, 34, 255}
COL_PLAYER :: rl.Color{253, 253, 248, 255}
COL_EXIT :: rl.Color{40, 198, 65, 255}

ItemType :: enum {
	Torch,
	WallTorch,
}

Item :: struct {
	using entity: Entity,
	type:         ItemType,
	light:        f32,
	color:        rl.Color,
	pickable:     bool,
}

CellVoid :: struct {}
CellFloor :: struct {}
CellWall :: struct {}
CellExit :: struct {}

CellType :: union {
	CellVoid,
	CellFloor,
	CellWall,
	CellExit,
}

Cell :: struct {
	using entity: Entity,
	s_light:      f32,
	d_light:      f32,
	walkable:     bool,
	type:         CellType,
}

load_level_png :: proc(file_path: string) -> (level: Level, err: string) {
	image_data, ok := u.read_entire_file(file_path)

	if !ok {
		err = "Failed to load image"
		return
	}

	defer delete(image_data)

	image := rl.LoadImageFromMemory(".png", rawptr(&image_data[0]), i32(len(image_data)))
	defer rl.UnloadImage(image)

	width := int(image.width)
	height := int(image.height)
	cells := make([dynamic]Cell, width * height)

	player_pos: Vec2i
	exit_pos: Vec2i

	s_light_sources := make(map[Id]LightSource)
	defer delete(s_light_sources)

	d_light_sources := make(map[Id]LightSource)
	items := make(map[Vec2i]Item)

	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			color := rl.GetImageColor(image, i32(x), i32(y))

			cell_type: CellType = CellVoid{}
			pos: Vec2i = {x, y}
			walkable: bool
			s_light: f32
			d_light: f32

			switch color.rgba {
			case COL_WALL:
				cell_type = CellWall{}
				break
			case COL_WALL_TORCH:
				cell_type = CellWall{}
				s_light = MAX_LIGHT
				item := Item{{new_id(), pos}, .WallTorch, s_light, COL_WALL_TORCH, false}
				s_light_sources[item.id] = {item.pos, item.light}
				items[pos] = item
				break
			case COL_FLOOR:
				cell_type = CellFloor{}
				walkable = true
			case COL_ITEM_TORCH:
				cell_type = CellFloor{}
				walkable = true
				d_light = 10
				item := Item{{new_id(), pos}, .Torch, d_light, COL_ITEM_TORCH, true}
				d_light_sources[item.id] = {item.pos, item.light}
				items[pos] = item
				break
			case COL_EXIT:
				cell_type = CellExit{}
				exit_pos = {x, y}
				walkable = true
				break
			case COL_PLAYER:
				cell_type = CellFloor{}
				walkable = true
				player_pos = {x, y}
				break
			}

			cells[(y * width) + x] = Cell{{new_id(), pos}, s_light, d_light, walkable, cell_type}
		}
	}

	compute_s_light(cells, s_light_sources, {width, height})
	level = {cells, items, player_pos, exit_pos, width, height, d_light_sources}
	compute_d_light(level)
	return
}

clear_d_light :: proc(cells: [dynamic]Cell) {
	for &c in cells {
		c.d_light = 0
	}
}

destroy_level :: proc(level: ^Level) {
	delete(level.items)
	delete(level.d_light_sources)
	delete(level.cells)
}

compute_s_light :: proc(cells: [dynamic]Cell, light_sources: map[Id]LightSource, bounds: Vec2i) {
	for _, source in light_sources {
		lit_cells := get_cells_in_radius(cells, bounds.x, bounds.y, source.pos, source.strength)
		defer delete(lit_cells)

		for idx_to_distance in lit_cells {
			idx := idx_to_distance[0]
			distance := idx_to_distance[1]
			cell := cells[idx]

			lightm := max(cell.s_light, source.strength - f32(distance))
			cells[idx].s_light = lightm
		}
	}
}

compute_d_light :: proc(level: Level) {
	for _, source in level.d_light_sources {
		lit_cells := get_cells_in_radius(
			level.cells,
			level.width,
			level.height,
			source.pos,
			source.strength,
		)
		defer delete(lit_cells)

		for idx_to_distance in lit_cells {
			idx := idx_to_distance[0]
			distance := idx_to_distance[1]
			cell := level.cells[idx]

			lightm := max(cell.d_light, source.strength - f32(distance))
			level.cells[idx].d_light = lightm
		}
	}
}

get_cells_in_radius :: proc(
	cells: [dynamic]Cell,
	width, height: int,
	source: Vec2i,
	radius: f32,
) -> [dynamic][2]int {
	result := make([dynamic][2]int)
	visited := make(map[int]bool)
	queue := make([dynamic][4]int)

	defer {
		delete(queue)
		delete(visited)
	}

	source_idx := (source.y * width) + source.x
	append(&queue, [4]int{source_idx, source.x, source.y, 0})

	queue_start := 0

	for queue_start < len(queue) {
		entry := queue[queue_start]
		queue_start += 1

		idx, x, y, dist := entry[0], entry[1], entry[2], entry[3]

		if visited[idx] {
			continue
		}
		visited[idx] = true

		append(&result, [2]int{idx, dist})

		if dist >= int(radius) {
			continue
		}

		for off in CARDINAL_POINTS {
			nx, ny := x + off[0], y + off[1]
			if nx < 0 || nx >= width || ny < 0 || ny >= height {
				continue
			}
			nidx := (ny * width) + nx

			if _, is_wall := cells[nidx].type.(CellWall); is_wall {
				if !visited[nidx] {
					append(&result, [2]int{nidx, dist + 1})
					visited[nidx] = true
				}
				continue
			}

			append(&queue, [4]int{nidx, nx, ny, dist + 1})
		}
	}

	return result
}

get_dimmed_color :: proc(light: f32, color: rl.Color) -> rl.Color {
	if (light <= 0.01) {
		return rl.BLACK
	}
	light_ratio := math.log2_f32(light) / math.log2_f32(MAX_LIGHT)
	return rl.ColorLerp(rl.BLACK, color, light_ratio)
}

draw_level :: proc(level: Level) {
	for c in level.cells[:] {
		x := i32(c.pos.x * CELL_SIZE)
		y := i32(c.pos.y * CELL_SIZE)
		color: rl.Color
		s_light := c.s_light
		d_light := c.d_light

		switch t in c.type {
		case CellVoid:
			break
		case CellFloor:
			color = COL_FLOOR
		case CellExit:
			color = COL_EXIT
		case CellWall:
			color = COL_WALL
		}

		light := max(d_light, s_light)
		light = min(light, MAX_LIGHT)

		rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, get_dimmed_color(light, color))
	}

	for pos, item in level.items {
		x := i32(pos.x * CELL_SIZE)
		y := i32(pos.y * CELL_SIZE)
		item_size := i32(CELL_SIZE / 2)
		margin := (CELL_SIZE - item_size) / 2
		rl.DrawRectangle(x + margin, y + margin, item_size, item_size, item.color)
	}
}

draw_level_text :: proc(level: Level) {
	old_y := 0
	for c in level.cells[:] {
		char: string

		switch t in c.type {
		case CellVoid:
			char = "-"
		case CellFloor:
			char = "."
		case CellExit:
			char = "e"
		case CellWall:
			char = "x"
		}


		if old_y != c.pos.y {
			fmt.println()
			old_y = c.pos.y
		}
		fmt.print(char)
	}
	fmt.println()
}
