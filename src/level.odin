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

Level :: struct {
	cells:      [dynamic]Cell,
	player_pos: Vec2i,
	exit_pos:   Vec2i,
	width:      int,
	height:     int,
}

COL_FLOOR :: rl.Color{10, 10, 10, 255}
COL_WALL :: rl.Color{27, 28, 51, 255}
COL_WALL_TORCH :: rl.Color{230, 218, 41, 255}
COL_ITEM_TORCH :: rl.Color{218, 125, 34, 255}
COL_PLAYER :: rl.Color{253, 253, 248, 255}
COL_EXIT :: rl.Color{40, 198, 65, 255}

ItemType :: enum {
	Torch,
}

Item :: struct {
	type:  ItemType,
	light: int,
	color: rl.Color,
}

MaybeItem :: union {
	bool,
	Item,
}

CellVoid :: struct {}
CellFloor :: struct {
	item: MaybeItem,
}
CellWall :: struct {
	torch: bool,
}
CellExit :: struct {}

CellType :: union {
	CellVoid,
	CellFloor,
	CellWall,
	CellExit,
}

Cell :: struct {
	pos:           Vec2i,
	static_light:  int,
	dynamic_light: int,
	walkable:      bool,
	type:          CellType,
}


load_level_png :: proc(file_path: string) -> (level: Level, err: string) {
	image_data, ok := u.read_entire_file(file_path)

	if !ok {
		err = "Failed to load image"
		return
	}

	defer delete(image_data)

	image := rl.LoadImageFromMemory(".png", rawptr(&image_data[0]), i32(len(image_data)))

	width := int(image.width)
	height := int(image.height)
	tiles := make([dynamic]Cell, width * height)
	player_pos: Vec2i
	exit_pos: Vec2i

	s_light_sources := make(map[Vec2i]int)
	defer delete(s_light_sources)

	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			color := rl.GetImageColor(image, i32(x), i32(y))

			cell_type: CellType = CellVoid{}
			pos: Vec2i = {x, y}
			walkable := false
			s_light := 0
			d_light := 0

			switch color.rgba {
			case COL_WALL:
				cell_type = CellWall{}
				break
			case COL_WALL_TORCH:
				cell_type = CellWall{true}
				s_light = MAX_LIGHT
				s_light_sources[pos] = s_light
				break
			case COL_FLOOR:
				cell_type = CellFloor{false}
				walkable = true
			case COL_ITEM_TORCH:
				cell_type = CellFloor{Item{.Torch, 5, COL_ITEM_TORCH}}
				d_light = 5
				walkable = true
				break
			case COL_EXIT:
				cell_type = CellExit{}
				exit_pos = {x, y}
				walkable = true
				break
			case COL_PLAYER:
				cell_type = CellFloor{}
				player_pos = {x, y}
				break
			}

			tiles[(y * width) + x] = Cell{pos, s_light, d_light, walkable, cell_type}
		}
	}

	for source, strength in s_light_sources {
		lit_cells := get_cells_in_radius(tiles, width, height, source, strength)
		defer delete(lit_cells)

		for idx_to_distance in lit_cells {
			idx := idx_to_distance[0]
			distance := idx_to_distance[1]
			tile := tiles[idx]

			lightm := max(tile.static_light, strength - distance)
			fmt.printfln("{}, {}, {}", idx, tile.pos, lightm)
			tiles[idx].static_light = lightm
			tiles[idx].dynamic_light = lightm
		}
	}

	level = {tiles, player_pos, exit_pos, width, height}
	return
}


get_cells_in_radius :: proc(
	tiles: [dynamic]Cell,
	width, height: int,
	source: Vec2i,
	radius: int,
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

		if dist >= radius {
			continue
		}

		cardinal_points := [8][2]int {
			{-1, 1},
			{0, 1},
			{1, 1},
			{-1, 0},
			{1, 0},
			{-1, -1},
			{0, -1},
			{1, -1},
		}

		for off in cardinal_points {
			nx, ny := x + off[0], y + off[1]
			if nx < 0 || nx >= width || ny < 0 || ny >= height {
				continue
			}
			nidx := (ny * width) + nx

			if _, is_wall := tiles[nidx].type.(CellWall); is_wall {
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

get_dimmed_color :: proc(light: int, color: rl.Color) -> rl.Color {
	if (light == 0) {
		return rl.BLACK
	}
	light_ratio := math.log2_f32(f32(light)) / math.log2_f32(MAX_LIGHT)
	return rl.ColorLerp(rl.BLACK, color, light_ratio)
}

draw_level :: proc(level: Level) {
	for c in level.cells[:] {
		x := i32(c.pos.x * CELL_SIZE)
		y := i32(c.pos.y * CELL_SIZE)
		color: rl.Color
		light := c.dynamic_light
		extra := false
		extra_col: rl.Color

		switch t in c.type {
		case CellVoid:
			break
		case CellFloor:
			color = COL_FLOOR
			if item, has_item := t.item.(Item); has_item {
				extra = true
				extra_col = item.color
			}
		case CellExit:
			color = COL_EXIT
		case CellWall:
			color = COL_WALL
			if t.torch {
				extra = true
				extra_col = rl.GOLD
			}
		}

		rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, get_dimmed_color(light, color))
		if extra {
			half := i32(CELL_SIZE / 2)
			rl.DrawRectangle(
				x + half / 2,
				y + half / 2,
				half,
				half,
				get_dimmed_color(light, rl.GOLD),
			)
		}

		if (g_mem.debug) {
			rl.DrawText(
				fmt.caprintf("{}", c.static_light, allocator = context.temp_allocator),
				(x + CELL_SIZE / 2) - 3,
				(y + CELL_SIZE / 2) - 4,
				4,
				rl.WHITE,
			)
		}
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
