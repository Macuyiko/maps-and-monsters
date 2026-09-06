import "CoreLibs/graphics"
import "CoreLibs/nineslice"
import "roomy"
import "defs"

class("Help").extends(Room)

local pd <const> = playdate
local gfx <const> = playdate.graphics

local floorImage = gfx.image.new("/images/floor")
local wallImage = gfx.image.new("/images/wall")
local chestImage = gfx.image.new("/images/chest")
local monsterImage = gfx.image.new("/images/monster")
local frameSlice = gfx.nineSlice.new("/images/frame", 8, 8, 32, 32)
local bigFont = gfx.font.new("/fonts/ruby_15")
local smallFont = gfx.font.new("/fonts/topaz_serif_8")

local PAGES = {
	{
		text = "Fill the dungeon with wall tiles. The number next to each row and column shows how many wall tiles it must contain.",
		demo = nil
	},
	{
		text = "Monsters lurk in dead ends: floor tiles with walls on three sides. Every dead end needs a monster.",
		demo = {
			{"#", "#", "#"},
			{"#", "M", "#"},
			{"#", ".", "."}
		}
	},
	{
		text = "Treasure chests sit inside 3x3 rooms with exactly one entrance.",
		demo = {
			{"#", "#", "#", "#", "#"},
			{"#", ".", ".", ".", "#"},
			{"#", ".", "T", ".", "#"},
			{"#", ".", ".", ".", "."},
			{"#", "#", "#", "#", "#"}
		}
	},
	{
		text = "Hallways may never form a 2x2 open square, except inside treasure rooms. All floor tiles must be connected.",
		demo = {
			{".", ".", "#"},
			{".", ".", "#"},
			{"#", "#", "#"}
		}
	},
	{
		text = "D-pad moves the cursor. A places or removes a wall. B marks a tile with an X. The system menu has a reset and the solution. Good luck!",
		demo = nil
	}
}

function Help:init()
	Help.super.init(self)
	self.page = 1
end

function Help:enter()
	self.page = 1
end

function Help:update(dt)
	if pd.buttonJustPressed("b") then
		manager:enter(scene_menu)
	elseif pd.buttonJustPressed("a") or pd.buttonJustPressed("right") or pd.buttonJustPressed("down") then
		if self.page < #PAGES then
			self.page = self.page + 1
		else
			manager:enter(scene_menu)
		end
	elseif pd.buttonJustPressed("left") or pd.buttonJustPressed("up") then
		if self.page > 1 then
			self.page = self.page - 1
		end
	end
end

function Help:draw()
	gfx.clear(gfx.kColorBlack)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.setFont(bigFont)
	local header = "HOW TO PLAY"
	local w = gfx.getTextSize(header)
	gfx.drawText(header, 120 - math.floor(w / 2), 10)

	local page = PAGES[self.page]
	if page.demo ~= nil then
		local demo = page.demo
		local dw = #demo[1] * TILE_SIZE
		local dh = #demo * TILE_SIZE
		local dx = 16
		local dy = 120 - dh / 2
		for r, row in ipairs(demo) do
			for c, cell in ipairs(row) do
				local px = dx + (c - 1) * TILE_SIZE
				local py = dy + (r - 1) * TILE_SIZE
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				floorImage:draw(px, py)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				if cell == "#" then
					wallImage:draw(px, py)
				elseif cell == "M" then
					monsterImage:draw(px, py)
				elseif cell == "T" then
					chestImage:draw(px, py)
				end
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
			end
		end
		gfx.setColor(gfx.kColorWhite)
		gfx.drawRect(dx - 2, dy - 2, dw + 4, dh + 4)
		gfx.setFont(smallFont)
		smallFont:drawText(page.text, dx + dw + 16, 60, 400 - (dx + dw + 16) - 16, 130, nil, gfx.kWrapWord, gfx.kAlignLeft)
	else
		gfx.setFont(smallFont)
		smallFont:drawText(page.text, 40, 70, 320, 110, nil, gfx.kWrapWord, gfx.kAlignLeft)
	end

	gfx.setFont(smallFont)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	local footer = self.page .. "/" .. #PAGES .. "    A next    B back"
	w = gfx.getTextSize(footer)
	gfx.drawText(footer, 120 - math.floor(w / 2), 220)
end
