import "defs"

-- Dungeon class
local Dungeon = {}
Dungeon.__index = Dungeon

function Dungeon.new()
  local self = setmetatable({}, Dungeon)
  self.col_count = {}
  self.row_count = {}
  self.grid = {}
  self.name = "Unknown"
  self.solved = false
  
  -- Initialize arrays
  for i = 0, DUNGEON_WIDTH - 1 do self.col_count[i] = 0 end
  for i = 0, DUNGEON_HEIGHT - 1 do self.row_count[i] = 0 end
  for i = 0, DUNGEON_WIDTH * DUNGEON_HEIGHT - 1 do self.grid[i] = C_UNKNOWN end
  
  return self
end

-- Access methods
function Dungeon:cell(pos, y)
  if y ~= nil then
    -- Called with x, y parameters
    return self.grid[y * DUNGEON_WIDTH + pos]
  elseif pos.x ~= nil then
    -- Called with {x=x, y=y} format
    return self.grid[pos_to_idx(pos)]
  else
    -- Called with {x, y} array-style format
    return self.grid[pos[2] * DUNGEON_WIDTH + pos[1]]
  end
end

function Dungeon:set_cell(pos, val, y)
  if y ~= nil then
    -- Called with x, y, val parameters
    self.grid[pos * DUNGEON_WIDTH + val] = y
  elseif pos.x ~= nil then
    -- Called with {x=x, y=y} format
    self.grid[pos_to_idx(pos)] = val
  else
    -- Called with {x, y} array-style format
    self.grid[pos[2] * DUNGEON_WIDTH + pos[1]] = val
  end
end

-- Validation helper methods
function Dungeon:count_neighbor_walls(pos)
  local count = 0
  for _, dir in ipairs(NEIGHBOR_DIRS) do
    local neighbor_pos = add_vec(pos, dir)
    if not is_on_grid(neighbor_pos) or self:cell(neighbor_pos) == C_WALL then
      count = count + 1
    end
  end
  return count
end

function Dungeon:count_neighbor_cells(pos, cell_type)
  local count = 0
  for _, dir in ipairs(NEIGHBOR_DIRS) do
    local neighbor_pos = add_vec(pos, dir)
    if is_on_grid(neighbor_pos) and self:cell(neighbor_pos) == cell_type then
      count = count + 1
    end
  end
  return count
end

function Dungeon:count_cells_on_row(cell_type, row)
  local count = 0
  for col = 0, DUNGEON_WIDTH - 1 do
    if self:cell({col, row}) == cell_type then
      count = count + 1
    end
  end
  return count
end

function Dungeon:count_cells_on_col(cell_type, col)
  local count = 0
  for row = 0, DUNGEON_HEIGHT - 1 do
    if self:cell({col, row}) == cell_type then
      count = count + 1
    end
  end
  return count
end

function Dungeon:count_islands()
  -- Count connected components in grid
  local land_pos = set_new()
  
  -- Collect all non-wall positions
  for y = 0, DUNGEON_HEIGHT - 1 do
    for x = 0, DUNGEON_WIDTH - 1 do
      local pos = vec(x, y)
      if self:cell(pos) ~= C_WALL then
        set_add(land_pos, pos)
      end
    end
  end
  
  -- Recursive function to remove an island
  local function remove_island(pos)
    if set_size(land_pos) == 0 then
      return 0
    end
    
    if not set_contains(land_pos, pos) then
      return 0
    end
    
    set_remove(land_pos, pos)
    local result = 1
    
    for _, dir in ipairs(NEIGHBOR_DIRS) do
      local neighbor_pos = add_vec(pos, dir)
      result = result + remove_island(neighbor_pos)
    end
    
    return result
  end
  
  -- Remove islands until there are none left
  local count = 0
  while set_size(land_pos) > 0 do
    local pos = set_pop(land_pos)
    set_add(land_pos, pos)  -- Put it back
    local hits = remove_island(pos)
    if hits == 0 then
      break
    end
    count = count + 1
  end
  
  return count
end

function Dungeon:find_treasures()
  local treasures = {}
  for y = 0, DUNGEON_HEIGHT - 1 do
    for x = 0, DUNGEON_WIDTH - 1 do
      local pos = vec(x, y)
      if self:cell(pos) == C_TREASURE then
        table.insert(treasures, pos)
      end
    end
  end
  return treasures
end

function Dungeon:is_empty_3x3(start_pos)
  for row = 0, 2 do
    for col = 0, 2 do
      local pos = add_vec(start_pos, vec(col, row))
      if not is_on_grid(pos) or (self:cell(pos) ~= C_HALLWAY and self:cell(pos) ~= C_TREASURE) then
        return false
      end
    end
  end
  return true
end

function Dungeon:find_treasure_room(treasure_pos)
  local rooms = {}
  for offset_x = -2, 0 do
    for offset_y = -2, 0 do
      local start_pos = add_vec(treasure_pos, vec(offset_x, offset_y))
      if self:is_empty_3x3(start_pos) then
        table.insert(rooms, start_pos)
      end
    end
  end
  return rooms
end

function Dungeon:find_treasure_room_entrances(treasure_room_pos)
  local entrances = {}
  for offset = 0, 2 do
    local entrance_offsets = {
      vec(offset, -1), 
      vec(offset, 3), 
      vec(-1, offset), 
      vec(3, offset)
    }
    
    for _, entrance_offset in ipairs(entrance_offsets) do
      local entrance_pos = add_vec(treasure_room_pos, entrance_offset)
      if is_on_grid(entrance_pos) and self:cell(entrance_pos) ~= C_WALL then
        table.insert(entrances, entrance_pos)
      end
    end
  end
  return entrances
end

-- Full validation
function Dungeon:check_full_validity(verbose)
  -- Count rows
  for row = 0, DUNGEON_HEIGHT - 1 do
    local walls = self:count_cells_on_row(C_WALL, row)
    if walls ~= self.row_count[row] then
      if verbose then
        print(string.format("ERR: Invalid number of walls on row %d: expected %d, actual %d", 
          row, self.row_count[row], walls))
      end
      return false
    end
  end
  
  -- Count columns
  for col = 0, DUNGEON_WIDTH - 1 do
    local walls = self:count_cells_on_col(C_WALL, col)
    if walls ~= self.col_count[col] then
      if verbose then
        print(string.format("ERR: Invalid number of walls on col %d: expected %d, actual %d", 
          col, self.col_count[col], walls))
      end
      return false
    end
  end
  
  -- Check dead ends and monsters
  for y = 0, DUNGEON_HEIGHT - 1 do
    for x = 0, DUNGEON_WIDTH - 1 do
      local pos = vec(x, y)
      local cell_val = self:cell(pos)
      local has_monster = (cell_val == C_MONSTER)
      local is_dead_end = (cell_val ~= C_WALL and self:count_neighbor_walls(pos) == 3)
      
      if has_monster and not is_dead_end then
        if verbose then
          print(string.format("ERR: monster not on dead-end at %d,%d", x, y))
        end
        return false
      end
      
      if not has_monster and is_dead_end then
        if verbose then
          print(string.format("ERR: no monster on dead-end at %d,%d", x, y))
        end
        return false
      end
    end
  end
  
  -- Check treasure rooms
  local treasures = self:find_treasures()
  local treasure_tiles = set_new()
  
  for _, treasure_pos in ipairs(treasures) do
    local start_poses = self:find_treasure_room(treasure_pos)
    if #start_poses ~= 1 then
      if verbose then
        print(string.format("ERR: only a single startPos allowed per treasureroom, but found %d", #start_poses))
      end
      return false
    end
    
    for _, start_pos in ipairs(start_poses) do
      local entrances = self:find_treasure_room_entrances(start_pos)
      if #entrances ~= 1 then
        if verbose then
          print(string.format("ERR: only a single entrance allowed per treasureroom, but found %d", #entrances))
        end
        return false
      end
      
      -- Add all treasure room tiles to the set
      for row = 0, 2 do
        for col = 0, 2 do
          local pos = add_vec(start_pos, vec(col, row))
          set_add(treasure_tiles, pos)
        end
      end
    end
  end
  
  -- Check hallways are one square wide (no 2x2 blocks outside treasure rooms)
  for y = 0, DUNGEON_HEIGHT - 2 do
    for x = 0, DUNGEON_WIDTH - 2 do
      local start_pos = vec(x, y)
      local is_valid = false
      
      -- Check if any of the 2x2 tiles are in treasure room or a wall
      for row = 0, 1 do
        for col = 0, 1 do
          local pos = add_vec(start_pos, vec(col, row))
          if set_contains(treasure_tiles, pos) or self:cell(pos) == C_WALL then
            is_valid = true
            break
          end
        end
        if is_valid then break end
      end
      
      if not is_valid then
        if verbose then
          print(string.format("ERR: hallway 2x2 block found at %d,%d", x, y))
        end
        return false
      end
    end
  end
  
  -- Check connected components
  local islands = self:count_islands()
  if islands ~= 1 then
    if verbose then
      print(string.format("ERR: all unshaded squares should be connected, but found %d islands", islands))
    end
    return false
  end
  
  -- All validations passed
  return true
end

-- Quick validation for a potential cell placement
function Dungeon:check_quick_validity(c, x, y)
  local pos = vec(x, y)
  local row_walls = self:count_cells_on_row(C_WALL, y)
  local row_unknowns = self:count_cells_on_row(C_UNKNOWN, y)
  local place_wall = (c == C_WALL) and 1 or 0
  local min_row_walls = row_walls + place_wall
  local max_row_walls = min_row_walls + row_unknowns - 1
  
  if not (self.row_count[y] >= min_row_walls and self.row_count[y] <= max_row_walls) then
    return false
  end
  
  local col_walls = self:count_cells_on_col(C_WALL, x)
  local col_unknowns = self:count_cells_on_col(C_UNKNOWN, x)
  local min_col_walls = col_walls + place_wall
  local max_col_walls = min_col_walls + col_unknowns - 1
  
  if not (self.col_count[x] >= min_col_walls and self.col_count[x] <= max_col_walls) then
    return false
  end
  
  -- Check impact on monsters and dead ends
  for _, dir in ipairs(NEIGHBOR_DIRS) do
    local neighbor_pos = add_vec(pos, dir)
    if is_on_grid(neighbor_pos) and self:cell(neighbor_pos) ~= C_UNKNOWN then
      local cell_val = self:cell(neighbor_pos)
      local has_monster = (cell_val == C_MONSTER)
      local neighbor_walls = self:count_neighbor_walls(neighbor_pos)
      local neighbor_unknowns = self:count_neighbor_cells(neighbor_pos, C_UNKNOWN)
      local min_neighbor_walls = neighbor_walls + place_wall
      local max_neighbor_walls = min_neighbor_walls + neighbor_unknowns - 1
      local is_dead_end = (cell_val ~= C_WALL and min_neighbor_walls == 3 and neighbor_unknowns < 2)
      
      if has_monster and not (min_neighbor_walls <= 3 and 3 <= max_neighbor_walls) then
        return false
      end
      
      if not has_monster and is_dead_end then
        return false
      end
    end
  end
  
  return true
end

-- Solve the puzzle using backtracking
function Dungeon:place_cell(pos, verbose)
  if self.solved then
    return
  end
  
  if pos == DUNGEON_WIDTH * DUNGEON_HEIGHT then
    if self:check_full_validity(verbose) then
      self.solved = true
    end
    return
  end
  
  if self.grid[pos] ~= C_UNKNOWN then
    self:place_cell(pos + 1, verbose)
    return
  end
  
  -- Try each possible cell type
  for _, cell_type in ipairs({C_HALLWAY, C_WALL}) do
    local pos_coords = idx_to_pos(pos)
    if self:check_quick_validity(cell_type, pos_coords.x, pos_coords.y) then
      self.grid[pos] = cell_type
      self:place_cell(pos + 1, verbose)
      if self.solved then
        return
      end
      self.grid[pos] = C_UNKNOWN
    end
  end
end

function Dungeon:solve(verbose)
  if verbose then
    print("Starting to solve the dungeon...")
  end
  
  self:place_cell(0, verbose)
  
  if verbose then
    if self.solved then
      print("Solution found!")
    else
      print("Unsolvable!")
    end
  end
  
  return self.solved
end

-- Return the Dungeon class
return Dungeon