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
	Void_1_NW,
	Void_1_N,
	Void_1_NE,
	Void_1_E,
	Void_1_SE,
	Void_1_S,
	Void_1_SW,
	Void_1_W,
	Void_2_SW,
	Void_2_SE,
	Void_2_NE,
	Void_2_NW,
	Void_3_W,
	Void_3_M,
	Void_3_E,
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
	.Void_1_NW     = {4 * CELL_SIZE, 2 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_N      = {5 * CELL_SIZE, 2 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_NE     = {6 * CELL_SIZE, 2 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_E      = {6 * CELL_SIZE, 3 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_SE     = {6 * CELL_SIZE, 3 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_S      = {5 * CELL_SIZE, 4 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_SW     = {4 * CELL_SIZE, 4 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_1_W      = {4 * CELL_SIZE, 4 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_2_SW     = {2 * CELL_SIZE, 5 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_2_SE     = {5 * CELL_SIZE, 5 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_2_NE     = {2 * CELL_SIZE, 7 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_2_NW     = {5 * CELL_SIZE, 7 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_3_W      = {2 * CELL_SIZE, 6 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_3_M      = {3 * CELL_SIZE, 6 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
	.Void_3_E      = {4 * CELL_SIZE, 6 * CELL_SIZE, CELL_SIZE, CELL_SIZE},
}

init_atlas :: proc() -> rl.Texture2D {
	return rl.LoadTexture("assets/atlas.png")
}
