import "CoreLibs/graphics"
import "CoreLibs/nineslice"
import "roomy"
import "defs"
import "savedata"
import "levels"

class("Levels").extends(Room)

local pd <const> = playdate
local gfx <const> = playdate.graphics


local frameSlice = gfx.nineSlice.new("/images/frame", 8, 8, 32, 32)
local bigFont = gfx.font.new("/fonts/ruby_15")
local smallFont = gfx.font.new("/fonts/topaz_serif_8")

local COLS <const> = 4
local ROWS <const> = 4
local CELL <const> = 36
local GAP <const> = 8
local GRID_W <const> = COLS * CELL + (COLS - 1) * GAP
local GRID_H <const> = ROWS * CELL + (ROWS - 1) * GAP
local GX <const> = 24
local GY <const> = 44
local PANEL_X <const> = 252

local REPEAT_DELAY <const> = 0.3
local REPEAT_RATE <const> = 0.09

local MOVES = {
	up = {x = 0, y = -1},
	down = {x = 0, y = 1},
	left = {x = -1, y = 0},
	right = {x = 1, y = 0}
}

local function draw_check(x, y, color)
	gfx.setColor(color)
	gfx.drawLine(x, y + 3, x + 2, y + 5)
	gfx.drawLine(x + 2, y + 5, x + 7, y)
end

function Levels:init()
	Levels.super.init(self)
	self.page = 1
	self.cursor = 0
	self.holdTime = {}
	self.repeatTime = {}
end

function Levels:enter(previous, page)
	if page ~= nil then
		self.page = math.max(1, math.min(4, page))
	end
	self.cursor = 0
	self.holdTime = {}
	self.repeatTime = {}
end

function Levels:keys()
	return LevelData.forYear(self.page)
end

function Levels:isUnlocked(key)
	local index = LevelData.indexOf(key)
	if index == nil then
		return false
	end
	if index == 1 then
		return true
	end
	return SavedData.isSolved(LevelData.keys[index - 1])
end

function Levels:moveCursor(dx, dy)
	local x = self.cursor % COLS
	local y = math.floor(self.cursor / COLS)
	local nx = x + dx
	local ny = y + dy
	if nx < 0 then
		if self.page > 1 then
			self.page = self.page - 1
			nx = COLS - 1
		else
			nx = 0
		end
	elseif nx > COLS - 1 then
		if self.page < 4 then
			self.page = self.page + 1
			nx = 0
		else
			nx = COLS - 1
		end
	end
	if ny < 0 then
		ny = 0
	elseif ny > ROWS - 1 then
		ny = ROWS - 1
	end
	self.cursor = ny * COLS + nx
end

function Levels:update(dt)
	for dir, move in pairs(MOVES) do
		if pd.buttonJustPressed(dir) then
			self:moveCursor(move.x, move.y)
			self.holdTime[dir] = 0
			self.repeatTime[dir] = 0
		elseif pd.buttonIsPressed(dir) and self.holdTime[dir] ~= nil then
			self.holdTime[dir] = self.holdTime[dir] + dt
			if self.holdTime[dir] >= REPEAT_DELAY then
				self.repeatTime[dir] = self.repeatTime[dir] + dt
				if self.repeatTime[dir] >= REPEAT_RATE then
					self:moveCursor(move.x, move.y)
					self.repeatTime[dir] = 0
				end
			end
		else
			self.holdTime[dir] = nil
		end
	end

	if pd.buttonJustPressed("b") then
		manager:enter(scene_menu)
		return
	end

	if pd.buttonJustPressed("a") then
		local key = self:keys()[self.cursor + 1]
		if key ~= nil and self:isUnlocked(key) then
			manager:enter(scene_game, key)
		end
	end
end

function Levels:draw()
	gfx.clear(gfx.kColorBlack)

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	frameSlice:drawInRect(GX - 12, GY - 12, GRID_W + 24, GRID_H + 24)

	local keys = self:keys()

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(bigFont)
	local header = "YEAR " .. self.page
	gfx.drawText(header, GX, 12)

	for i = 0, #keys - 1 do
		local col = i % COLS
		local row = math.floor(i / COLS)
		local x = GX + col * (CELL + GAP)
		local y = GY + row * (CELL + GAP)
		local key = keys[i + 1]
		local unlocked = self:isUnlocked(key)
		local solved = SavedData.isSolved(key)
		local selected = i == self.cursor

		if selected then
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRect(x - 2, y - 2, CELL + 4, CELL + 4)
			gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		else
			gfx.setColor(gfx.kColorWhite)
			gfx.drawRoundRect(x, y, CELL, CELL, 3)
		end

		local label
		if not unlocked then
			label = "?"
		else
			label = tostring(tonumber(key:match("%d+-(%d+)")))
		end

		gfx.setFont(bigFont)
		local lw, lh = gfx.getTextSize(label)
		gfx.drawText(label, x + math.floor((CELL - lw) / 2), y + math.floor((CELL - lh) / 2) - 2)
		gfx.setFont(smallFont)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		if solved then
			local color = gfx.kColorBlack
			if not selected then
				color = gfx.kColorWhite
			end
			draw_check(x + CELL - 12, y + 4, color)
		end
	end

	self:drawPanel(keys)
end

function Levels:drawPanel(keys)
	local key = keys[self.cursor + 1]

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(smallFont)

	gfx.drawText("solved " .. SavedData.solvedCount() .. "/" .. LevelData.count(), PANEL_X, 12)

	if key == nil then
		return
	end

	local level = LevelData.get(key)
	smallFont:drawText(level.name, PANEL_X, 36, 136, 60, nil, gfx.kWrapWord, gfx.kAlignLeft)

	if not self:isUnlocked(key) then
		gfx.drawText("locked", PANEL_X, 110)
		gfx.drawText("solve the", PANEL_X, 136)
		gfx.drawText("previous level", PANEL_X, 150)
	elseif SavedData.isSolved(key) then
		gfx.drawText("solved in " .. format_time(SavedData.bestTime(key)), PANEL_X, 110)
		if SavedData.wasCheated(key) then
			gfx.drawText("(solution used)", PANEL_X, 124)
		end
	else
		gfx.drawText("unsolved", PANEL_X, 110)
	end

	gfx.drawText("A play", PANEL_X, 180)
	gfx.drawText("B back", PANEL_X, 194)
	gfx.drawText("edges: year", PANEL_X, 208)
end
