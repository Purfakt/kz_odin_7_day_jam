package game

import rl "vendor:raylib"

SpriteId :: enum {
	Player_Fine,
	Player_Meh,
	Player_Scared,
	Player_Cry,
	WallTorch,
	Torch,
	Wall,
	Floor,
	Exit,
	Void,
}

AtlasSprite: [SpriteId]rl.Rectangle = {
	.Player_Fine   = {0 * CELL_SIZE, 0 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Player_Meh    = {1 * CELL_SIZE, 0 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Player_Scared = {2 * CELL_SIZE, 0 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Player_Cry    = {3 * CELL_SIZE, 0 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Wall          = {0 * CELL_SIZE, 1 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Floor         = {2 * CELL_SIZE, 3 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Exit          = {2 * CELL_SIZE, 1 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.WallTorch     = {0 * CELL_SIZE, 2 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Torch         = {1 * CELL_SIZE, 2 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void          = {},
}

init_atlas :: proc() -> rl.Texture2D {
	return rl.LoadTexture("assets/atlas.png")
}
