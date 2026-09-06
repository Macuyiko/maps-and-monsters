DUNGEON_WIDTH = 8
DUNGEON_HEIGHT = 8
TILE_SIZE = 24
BOARD_SIZE = 8 * TILE_SIZE

C_WALL = "#"
C_FLOOR = "-"
C_UNKNOWN = "."
C_MONSTER = "M"
C_TREASURE = "T"

NEIGHBOR_DIRS = {
	{x = 0, y = -1},
	{x = -1, y = 0},
	{x = 0, y = 1},
	{x = 1, y = 0}
}

function is_on_grid(x, y)
	return x >= 0 and x < DUNGEON_WIDTH and y >= 0 and y < DUNGEON_HEIGHT
end

function format_time(t)
	local m = math.floor(t / 60)
	local s = math.floor(t % 60)
	return string.format("%d:%02d", m, s)
end
