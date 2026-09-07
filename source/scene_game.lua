import "CoreLibs/graphics"
import "CoreLibs/nineslice"
import "roomy"
import "defs"
import "savedata"
import "levels"
import "dungeon"

class("Game").extends(Room)

local pd <const> = playdate
local gfx <const> = playdate.graphics


local floorImage = gfx.image.new("/images/floor")
local wallImage = gfx.image.new("/images/wall")
local markerImage = gfx.image.new("/images/marker")
local chestImage = gfx.image.new("/images/chest")
local monsterImages = {monster = gfx.image.new("/images/monster")}
local function monsterImageFor(name)
	if name == nil then
		return monsterImages.monster
	end
	local img = monsterImages[name]
	if img == nil then
		img = gfx.image.new("/images/monsters/" .. name)
		if img == nil then
			img = monsterImages.monster
		end
		monsterImages[name] = img
	end
	return img
end
local frameSlice = gfx.nineSlice.new("/images/frame", 8, 8, 32, 32)
local bigFont = gfx.font.new("/fonts/ruby_15")
local smallFont = gfx.font.new("/fonts/topaz_serif_8")

local BOARD_X <const> = 24
local BOARD_Y <const> = 24
local PANEL_X <const> = 252
local REPEAT_DELAY <const> = 0.3
local REPEAT_RATE <const> = 0.08

local DIR_MOVES = {
	up = {x = 0, y = -1},
	down = {x = 0, y = 1},
	left = {x = -1, y = 0},
	right = {x = 1, y = 0}
}

local function draw_check(x, y)
	gfx.drawLine(x, y + 3, x + 2, y + 5)
	gfx.drawLine(x + 2, y + 5, x + 7, y)
end

local function draw_cross(x, y, size)
	gfx.drawLine(x, y, x + size, y + size)
	gfx.drawLine(x, y + size, x + size, y)
end

function Game:init()
	Game.super.init(self)
	self.dungeon = nil
	self.selection = {x = 0, y = 0}
	self.holdTime = {}
	self.repeatTime = {}
	self.time = 0
	self.won = false
	self.cheated = false
end

function Game:enter(previous, key)
	self:loadLevel(key)
	local menu = pd.getSystemMenu()
	menu:addMenuItem("Reset level", function()
		self:resetLevel()
	end)
	menu:addMenuItem("Show solution", function()
		self:showSolution()
	end)
	menu:addMenuItem("Return to levels", function()
		manager:enter(scene_levels)
	end)
end

function Game:leave()
	pd.getSystemMenu():removeAllMenuItems()
end

function Game:loadLevel(key)
	self.dungeon = Dungeon.new(LevelData.get(key), key)
	self.selection = {x = 0, y = 0}
	self.holdTime = {}
	self.repeatTime = {}
	self.time = 0
	self.won = false
	self.cheated = false
end

function Game:resetLevel()
	self:loadLevel(self.dungeon.key)
end

function Game:showSolution()
	if self.won then
		return
	end
	self.dungeon:reveal_solution()
	self.cheated = true
	self:checkWin()
end

function Game:checkWin()
	if self.won then
		return
	end
	if self.dungeon:counts_exact() and self.dungeon:check_full_validity() then
		self.won = true
		SavedData.record(self.dungeon.key, math.floor(self.time), self.cheated)
	end
end

function Game:moveSelection(dx, dy)
	self.selection.x = math.max(0, math.min(DUNGEON_WIDTH - 1, self.selection.x + dx))
	self.selection.y = math.max(0, math.min(DUNGEON_HEIGHT - 1, self.selection.y + dy))
end

function Game:update(dt)
	if self.won then
		if pd.buttonJustPressed("a") then
			local nextKey = LevelData.next(self.dungeon.key)
			if nextKey ~= nil then
				self:loadLevel(nextKey)
			else
				manager:enter(scene_levels)
			end
		elseif pd.buttonJustPressed("b") then
			manager:enter(scene_levels)
		end
		return
	end

	self.time = self.time + dt

	for dir, move in pairs(DIR_MOVES) do
		if pd.buttonJustPressed(dir) then
			self:moveSelection(move.x, move.y)
			self.holdTime[dir] = 0
			self.repeatTime[dir] = 0
		elseif pd.buttonIsPressed(dir) and self.holdTime[dir] ~= nil then
			self.holdTime[dir] = self.holdTime[dir] + dt
			if self.holdTime[dir] >= REPEAT_DELAY then
				self.repeatTime[dir] = self.repeatTime[dir] + dt
				if self.repeatTime[dir] >= REPEAT_RATE then
					self:moveSelection(move.x, move.y)
					self.repeatTime[dir] = 0
				end
			end
		else
			self.holdTime[dir] = nil
		end
	end

	if pd.buttonJustPressed("a") then
		self.dungeon:toggle_wall(self.selection.x, self.selection.y)
		self:checkWin()
	elseif pd.buttonJustPressed("b") then
		self.dungeon:toggle_marker(self.selection.x, self.selection.y)
	end
end

function Game:draw()
	gfx.clear(gfx.kColorBlack)
	local d = self.dungeon
	if d == nil then
		return
	end

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	frameSlice:drawInRect(0, 0, BOARD_X * 2 + BOARD_SIZE, BOARD_Y * 2 + BOARD_SIZE)

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	for y = 0, DUNGEON_HEIGHT - 1 do
		for x = 0, DUNGEON_WIDTH - 1 do
			local px = BOARD_X + x * TILE_SIZE
			local py = BOARD_Y + y * TILE_SIZE
			floorImage:draw(px, py)
			if d:cell(x, y) == C_WALL then
				wallImage:draw(px, py)
			end
		end
	end

	for y = 0, DUNGEON_HEIGHT - 1 do
		for x = 0, DUNGEON_WIDTH - 1 do
			local px = BOARD_X + x * TILE_SIZE
			local py = BOARD_Y + y * TILE_SIZE
			local c = d:cell(x, y)
			if c == C_TREASURE then
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				chestImage:draw(px, py)
			elseif c == C_MONSTER then
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				monsterImageFor(d.monsterType):draw(px, py)
			elseif c == C_FLOOR then
				gfx.setImageDrawMode(gfx.kDrawModeBlackTransparent)
				markerImage:draw(px, py)
			end
		end
	end

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(smallFont)
	gfx.setColor(gfx.kColorWhite)
	for i = 0, DUNGEON_HEIGHT - 1 do
		local text = tostring(d.row_count[i])
		local w, h = gfx.getTextSize(text)
		local ty = BOARD_Y + i * TILE_SIZE + math.floor((TILE_SIZE - h) / 2)
		gfx.drawText(text, BOARD_X - 6 - w, ty)
		local status = d:row_status(i)
		if status == 0 then
			draw_check(BOARD_X - 14, BOARD_Y + i * TILE_SIZE + TILE_SIZE - 8)
		elseif status == 1 then
			draw_cross(BOARD_X - 14, ty, 8)
		end
	end

	for i = 0, DUNGEON_WIDTH - 1 do
		local text = tostring(d.col_count[i])
		local w, h = gfx.getTextSize(text)
		local tx = BOARD_X + i * TILE_SIZE + math.floor((TILE_SIZE - w) / 2)
		local ty = BOARD_Y - 6 - h
		gfx.drawText(text, tx, ty)
		local status = d:col_status(i)
		if status == 0 then
			draw_check(BOARD_X + i * TILE_SIZE + TILE_SIZE - 9, BOARD_Y - 6)
		elseif status == 1 then
			draw_cross(tx + 1, ty + 1, 8)
		end
	end

	if not self.won then
		gfx.setColor(gfx.kColorWhite)
		gfx.drawRoundRect(BOARD_X + self.selection.x * TILE_SIZE, BOARD_Y + self.selection.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, 3)
	end

	self:drawPanel()

	if self.won then
		self:drawWinOverlay()
	end
end

function Game:drawPanel()
	local d = self.dungeon
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(smallFont)

	smallFont:drawText(d.key .. " - " .. d.name, PANEL_X, 14, 140, 44, nil, gfx.kWrapWord, gfx.kAlignLeft)

	gfx.drawText("time " .. format_time(self.time), PANEL_X, 66)

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	monsterImageFor(d.monsterType):draw(PANEL_X, 88)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawText(d.monsterType, PANEL_X + TILE_SIZE + 6, 94)

	if d.bossPos ~= nil then
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		monsterImageFor(d.bossType):draw(PANEL_X, 118)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		gfx.drawText("boss " .. d.bossType, PANEL_X + TILE_SIZE + 6, 124)
	end

	gfx.drawText("solved " .. SavedData.solvedCount() .. "/" .. LevelData.count(), PANEL_X, 152)

	gfx.drawText("A wall", PANEL_X, 196)
	gfx.drawText("B mark", PANEL_X, 210)
end

function Game:drawWinOverlay()
	gfx.setColor(gfx.kColorBlack)
	gfx.setDitherPattern(0.5)
	gfx.fillRect(0, 0, 240, 240)
	gfx.setDitherPattern(1)

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	frameSlice:drawInRect(48, 64, 144, 112)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(bigFont)
	local title = "SOLVED!"
	local w = gfx.getTextSize(title)
	gfx.drawText(title, 120 - math.floor(w / 2), 80)

	gfx.setFont(smallFont)
	local lines
	if self.cheated then
		lines = "time " .. format_time(self.time) .. " (solution used)"
	else
		lines = "time " .. format_time(self.time)
	end
	w = gfx.getTextSize(lines)
	gfx.drawText(lines, 120 - math.floor(w / 2), 106)

	local hint
	if LevelData.next(self.dungeon.key) ~= nil then
		hint = "A next   B levels"
	else
		hint = "A levels"
	end
	w = gfx.getTextSize(hint)
	gfx.drawText(hint, 120 - math.floor(w / 2), 148)
end
