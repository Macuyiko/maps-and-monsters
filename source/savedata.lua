local pd <const> = playdate

SavedData = {}

local data = nil

function SavedData.load()
	if data == nil then
		data = pd.datastore.read("mm_save")
		if data == nil then
			data = {}
		end
		if data.solved == nil then
			data.solved = {}
		end
	end
	return data
end

function SavedData.write()
	pd.datastore.write(data, "mm_save")
end

function SavedData.isSolved(key)
	return SavedData.load().solved[key] ~= nil
end

function SavedData.bestTime(key)
	local rec = SavedData.load().solved[key]
	if rec ~= nil then
		return rec.time
	end
	return nil
end

function SavedData.wasCheated(key)
	local rec = SavedData.load().solved[key]
	return rec ~= nil and rec.cheated == true
end

function SavedData.record(key, time, cheated)
	local d = SavedData.load()
	local prev = d.solved[key]
	if prev == nil then
		d.solved[key] = {time = time, cheated = cheated}
	elseif not cheated and (prev.cheated or time < prev.time) then
		d.solved[key] = {time = time, cheated = false}
	end
	SavedData.write()
end

function SavedData.solvedCount()
	local n = 0
	for _ in pairs(SavedData.load().solved) do
		n = n + 1
	end
	return n
end

function SavedData.resetProgress()
	data = {solved = {}}
	SavedData.write()
end
