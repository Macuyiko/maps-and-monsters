LevelData = {}

LevelData.data = json.decodeFile("/levels/levels.json")
LevelData.keys = {}

for key in pairs(LevelData.data) do
	table.insert(LevelData.keys, key)
end

local function key_order(a)
	local year, index = a:match("(%d+)-(%d+)")
	return tonumber(year) * 100 + tonumber(index)
end

table.sort(LevelData.keys, function(a, b)
	return key_order(a) < key_order(b)
end)

function LevelData.count()
	return #LevelData.keys
end

function LevelData.get(key)
	return LevelData.data[key]
end

function LevelData.indexOf(key)
	for i, k in ipairs(LevelData.keys) do
		if k == key then
			return i
		end
	end
	return nil
end

function LevelData.next(key)
	local i = LevelData.indexOf(key)
	if i ~= nil and i < #LevelData.keys then
		return LevelData.keys[i + 1]
	end
	return nil
end

function LevelData.yearOf(key)
	return tonumber(key:match("^(%d+)"))
end

function LevelData.forYear(year)
	local out = {}
	for _, key in ipairs(LevelData.keys) do
		if LevelData.yearOf(key) == year then
			table.insert(out, key)
		end
	end
	return out
end
