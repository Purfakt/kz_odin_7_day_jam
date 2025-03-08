package game

// import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Vec2i :: [2]int
// --------------
//      GRID
// --------------

GRID_WIDTH :: 20
GRID_SIZE :: GRID_WIDTH * GRID_WIDTH
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE

Level :: struct {
	tiles:      [dynamic]Cell,
	player_pos: Vec2i,
	width:      int,
	height:     int,
}

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

load_level :: proc(file_path: string) -> (level: Level, err: string) {
	data, ok := os.read_entire_file(file_path)
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
			case 'p':
				player_pos = {x, y}
			}
			cell := Cell{pos, cell_type}
			tiles[(y * width) + x] = cell
		}
	}

	level = {tiles, player_pos, width, height}
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
			color = rl.BLACK
		case .Exit:
			color = rl.DARKBROWN
		case .Wall:
			color = rl.GRAY
		}

		rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, color)
	}
}
