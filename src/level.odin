package game

import "core:fmt"
import "core:strings"
import u "utils"
import rl "vendor:raylib"

Vec2i :: [2]int
// --------------
//      GRID
// --------------

CELL_SIZE :: 16

Level :: struct {
	tiles:      [dynamic]Cell,
	player_pos: Vec2i,
	exit_pos:   Vec2i,
	width:      int,
	height:     int,
}

COL_FLOOR :: rl.Color{10, 10, 10, 255}
COL_WALL :: rl.Color{27, 28, 51, 255}
COL_PLAYER :: rl.Color{253, 253, 248, 255}
COL_EXIT :: rl.Color{40, 198, 65, 255}

CellType :: enum {
	Void,
	Floor,
	Wall,
	Exit,
}

Cell :: struct {
	pos:  Vec2i,
	type: CellType,
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

	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			color := rl.GetImageColor(image, i32(x), i32(y))

			cell_type: CellType = .Void
			pos: Vec2i = {x, y}

			switch color.rgba {
			case COL_WALL:
				cell_type = .Wall
				break
			case COL_FLOOR:
				cell_type = .Floor
			case COL_EXIT:
				cell_type = .Exit
				exit_pos = {x, y}
				break
			case COL_PLAYER:
				cell_type = .Floor
				player_pos = {x, y}
				break
			}

			tiles[(y * width) + x] = Cell{pos, cell_type}
		}
	}

	level = {tiles, player_pos, exit_pos, width, height}
	return
}

load_level_text :: proc(file_path: string) -> (level: Level, err: string) {
	data, ok := u.read_entire_file(file_path)
	if !ok {
		err = "can't read file"
		return
	}
	lines := strings.split(string(data), "\n")

	defer delete(lines)
	defer delete(data)

	height := len(lines)

	if height == 0 {
		err = "no lines in level file"
		return
	}

	width := len(lines[0])

	if width == 0 {
		err = "no char in first line"
		return
	}

	tiles := make([dynamic]Cell, width * height)
	player_pos: Vec2i
	exit_pos: Vec2i

	for y := 0; y < height; y += 1 {
		line := lines[y]
		for x := 0; x < width; x += 1 {
			char := line[x]
			pos: Vec2i = {x, y}
			cell_type: CellType = .Void
			switch char {
			case 'x':
				cell_type = .Wall
			case '.':
				cell_type = .Floor
			case 'e':
				cell_type = .Exit
				exit_pos = {x, y}
			case 'p':
				player_pos = {x, y}
			}
			cell := Cell{pos, cell_type}
			tiles[(y * width) + x] = cell
		}
	}

	level = {tiles, player_pos, exit_pos, width, height}
	return
}

draw_level :: proc(level: Level) {
	for t in level.tiles[:] {
		x := i32(t.pos.x * CELL_SIZE)
		y := i32(t.pos.y * CELL_SIZE)
		color: rl.Color

		switch t.type {
		case .Void:
		case .Floor:
			color = COL_FLOOR
		case .Exit:
			color = COL_EXIT
		case .Wall:
			color = COL_WALL
		}

		rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, color)
	}
}

draw_level_text :: proc(level: Level) {
	old_y := 0
	for t in level.tiles[:] {
		char: string

		switch t.type {
		case .Void:
			char = "-"
		case .Floor:
			char = "."
		case .Exit:
			char = "e"
		case .Wall:
			char = "x"
		}


		if old_y != t.pos.y {
			fmt.println()
			old_y = t.pos.y
		}
		fmt.print(char)
	}
	fmt.println()
}
