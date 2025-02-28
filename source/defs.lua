
-- Constants
DUNGEON_WIDTH = 8
DUNGEON_HEIGHT = 8

-- Direction vectors
N_NORTH = {x = 0, y = -1}
N_EAST = {x = -1, y = 0}
N_SOUTH = {x = 0, y = 1}
N_WEST = {x = 1, y = 0}
NEIGHBOR_DIRS = {N_NORTH, N_EAST, N_SOUTH, N_WEST}

-- Cell types
C_HALLWAY = ' '
C_WALL = '#'
C_UNKNOWN = '.'
C_MONSTER = 'M'
C_TREASURE = 'T'
C_MARKER = '+'

-- Utility functions
function is_on_grid(pos)
  return pos.x >= 0 and pos.x < DUNGEON_WIDTH and pos.y >= 0 and pos.y < DUNGEON_HEIGHT
end

function add_vec(v1, v2)
  return {x = v1.x + v2.x, y = v1.y + v2.y}
end

function vec(x, y)
  return {x = x, y = y}
end

function pos_to_idx(pos)
  return pos.y * DUNGEON_WIDTH + pos.x
end

function idx_to_pos(idx)
  return {
    x = idx % DUNGEON_WIDTH,
    y = math.floor(idx / DUNGEON_WIDTH)
  }
end

-- Set operations
function set_new()
  return {}
end

function set_add(set, value)
  set[tostring(value.x) .. "," .. tostring(value.y)] = value
end

function set_remove(set, value)
  set[tostring(value.x) .. "," .. tostring(value.y)] = nil
end

function set_contains(set, value)
  return set[tostring(value.x) .. "," .. tostring(value.y)] ~= nil
end

function set_pop(set)
  for k, v in pairs(set) do
    set_remove(set, v)
    return v
  end
  return nil
end

function set_size(set)
  count = 0
  for _ in pairs(set) do count = count + 1 end
  return count
end
