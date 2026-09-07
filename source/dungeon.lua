import "defs"

Dungeon = {}
Dungeon.__index = Dungeon

function Dungeon.new(level, key, progress)
	local self = setmetatable({}, Dungeon)
	self.key = key
	self.name = level.name
	self.monsterType = level.monster
	self.bossType = level.boss
	self.bossPos = level.boss_pos
	self.row_count = {}
	self.col_count = {}
	for i = 0, DUNGEON_HEIGHT - 1 do
		self.row_count[i] = level.rows[i + 1]
	end
	for i = 0, DUNGEON_WIDTH - 1 do
		self.col_count[i] = level.columns[i + 1]
	end
	self.grid = {}
	for i = 0, DUNGEON_WIDTH * DUNGEON_HEIGHT - 1 do
		self.grid[i] = C_UNKNOWN
	end
	for _, c in ipairs(level.chests) do
		self:set_cell(c[1], c[2], C_TREASURE)
	end
	for _, m in ipairs(level.monsters) do
		self:set_cell(m[1], m[2], C_MONSTER)
	end
	self.solution = level.solution
	if progress ~= nil and progress.grid ~= nil and #progress.grid == DUNGEON_WIDTH * DUNGEON_HEIGHT then
		for i = 0, DUNGEON_WIDTH * DUNGEON_HEIGHT - 1 do
			self.grid[i] = progress.grid:sub(i + 1, i + 1)
		end
	end
	return self
end

function Dungeon:serialize_grid()
	local chars = {}
	for i = 0, DUNGEON_WIDTH * DUNGEON_HEIGHT - 1 do
		chars[i + 1] = self.grid[i]
	end
	return table.concat(chars)
end

function Dungeon:cell(x, y)
	if not is_on_grid(x, y) then
		return C_WALL
	end
	return self.grid[y * DUNGEON_WIDTH + x]
end

function Dungeon:set_cell(x, y, value)
	if is_on_grid(x, y) then
		self.grid[y * DUNGEON_WIDTH + x] = value
	end
end

function Dungeon:toggle_wall(x, y)
	local c = self:cell(x, y)
	if c == C_WALL then
		self:set_cell(x, y, C_UNKNOWN)
	elseif c == C_UNKNOWN or c == C_FLOOR then
		self:set_cell(x, y, C_WALL)
	end
end

function Dungeon:toggle_marker(x, y)
	local c = self:cell(x, y)
	if c == C_UNKNOWN then
		self:set_cell(x, y, C_FLOOR)
	elseif c == C_FLOOR then
		self:set_cell(x, y, C_UNKNOWN)
	end
end

function Dungeon:count_neighbor_walls(x, y)
	local count = 0
	for _, d in ipairs(NEIGHBOR_DIRS) do
		if self:cell(x + d.x, y + d.y) == C_WALL then
			count = count + 1
		end
	end
	return count
end

function Dungeon:count_cells_on_row(cell_type, row)
	local count = 0
	for x = 0, DUNGEON_WIDTH - 1 do
		if self:cell(x, row) == cell_type then
			count = count + 1
		end
	end
	return count
end

function Dungeon:count_cells_on_col(cell_type, col)
	local count = 0
	for y = 0, DUNGEON_HEIGHT - 1 do
		if self:cell(col, y) == cell_type then
			count = count + 1
		end
	end
	return count
end

function Dungeon:row_status(row)
	local walls = self:count_cells_on_row(C_WALL, row)
	if walls < self.row_count[row] then
		return -1
	elseif walls == self.row_count[row] then
		return 0
	end
	return 1
end

function Dungeon:col_status(col)
	local walls = self:count_cells_on_col(C_WALL, col)
	if walls < self.col_count[col] then
		return -1
	elseif walls == self.col_count[col] then
		return 0
	end
	return 1
end

function Dungeon:counts_exact()
	for i = 0, DUNGEON_HEIGHT - 1 do
		if self:row_status(i) ~= 0 then
			return false
		end
	end
	for i = 0, DUNGEON_WIDTH - 1 do
		if self:col_status(i) ~= 0 then
			return false
		end
	end
	return true
end

function Dungeon:count_islands()
	local visited = {}
	local count = 0
	for y = 0, DUNGEON_HEIGHT - 1 do
		for x = 0, DUNGEON_WIDTH - 1 do
			if self:cell(x, y) ~= C_WALL and not visited[y * DUNGEON_WIDTH + x + 1] then
				count = count + 1
				local stack = {{x, y}}
				visited[y * DUNGEON_WIDTH + x + 1] = true
				while #stack > 0 do
					local p = table.remove(stack)
					for _, d in ipairs(NEIGHBOR_DIRS) do
						local nx = p[1] + d.x
						local ny = p[2] + d.y
						if is_on_grid(nx, ny) then
							local ni = ny * DUNGEON_WIDTH + nx + 1
							if not visited[ni] and self.grid[ni - 1] ~= C_WALL then
								visited[ni] = true
								table.insert(stack, {nx, ny})
							end
						end
					end
				end
			end
		end
	end
	return count
end

function Dungeon:is_room_tile(x, y)
	local c = self:cell(x, y)
	return c == C_UNKNOWN or c == C_FLOOR or c == C_TREASURE
end

function Dungeon:find_treasure_rooms(tx, ty)
	local placements = {}
	for oy = -2, 0 do
		for ox = -2, 0 do
			local ok = true
			for dy = 0, 2 do
				for dx = 0, 2 do
					if not self:is_room_tile(tx + ox + dx, ty + oy + dy) then
						ok = false
					end
				end
			end
			if ok then
				table.insert(placements, {x = tx + ox, y = ty + oy})
			end
		end
	end
	return placements
end

function Dungeon:count_room_entrances(rx, ry)
	local count = 0
	for i = 0, 2 do
		local ring = {
			{rx + i, ry - 1},
			{rx + i, ry + 3},
			{rx - 1, ry + i},
			{rx + 3, ry + i}
		}
		for _, r in ipairs(ring) do
			if self:cell(r[1], r[2]) ~= C_WALL then
				count = count + 1
			end
		end
	end
	return count
end

function Dungeon:check_full_validity()
	if not self:counts_exact() then
		return false
	end

	for y = 0, DUNGEON_HEIGHT - 1 do
		for x = 0, DUNGEON_WIDTH - 1 do
			local c = self:cell(x, y)
			if c ~= C_WALL then
				local dead_end = self:count_neighbor_walls(x, y) == 3
				if c == C_MONSTER and not dead_end then
					return false
				end
				if c ~= C_MONSTER and dead_end then
					return false
				end
			end
		end
	end

	local room_tiles = {}
	for y = 0, DUNGEON_HEIGHT - 1 do
		for x = 0, DUNGEON_WIDTH - 1 do
			if self:cell(x, y) == C_TREASURE then
				local placements = self:find_treasure_rooms(x, y)
				if #placements ~= 1 then
					return false
				end
				local room = placements[1]
				if self:count_room_entrances(room.x, room.y) ~= 1 then
					return false
				end
				for dy = 0, 2 do
					for dx = 0, 2 do
						room_tiles[(room.y + dy) * DUNGEON_WIDTH + room.x + dx + 1] = true
					end
				end
			end
		end
	end

	for y = 0, DUNGEON_HEIGHT - 2 do
		for x = 0, DUNGEON_WIDTH - 2 do
			local in_room = false
			for dy = 0, 1 do
				for dx = 0, 1 do
					if room_tiles[(y + dy) * DUNGEON_WIDTH + x + dx + 1] then
						in_room = true
					end
				end
			end
			if not in_room then
				local open = true
				for dy = 0, 1 do
					for dx = 0, 1 do
						if self:cell(x + dx, y + dy) == C_WALL then
							open = false
						end
					end
				end
				if open then
					return false
				end
			end
		end
	end

	return self:count_islands() == 1
end

function Dungeon:reveal_solution()
	for y = 0, DUNGEON_HEIGHT - 1 do
		local row = self.solution[y + 1]
		for x = 0, DUNGEON_WIDTH - 1 do
			local c = self:cell(x, y)
			if c ~= C_MONSTER and c ~= C_TREASURE then
				if row:sub(x + 1, x + 1) == "#" then
					self:set_cell(x, y, C_WALL)
				else
					self:set_cell(x, y, C_UNKNOWN)
				end
			end
		end
	end
end

