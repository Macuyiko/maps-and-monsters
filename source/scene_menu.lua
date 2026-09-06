import "CoreLibs/graphics"
import "CoreLibs/nineslice"
import "CoreLibs/animator"
import "CoreLibs/crank"
import "roomy"
import "savedata"

class("Menu").extends(Room)

local pd <const> = playdate
local gfx <const> = playdate.graphics


local bannerImage = gfx.image.new("/images/banner")
local backImage = gfx.image.new("/images/back")
local frameSlice = gfx.nineSlice.new("/images/frame", 8, 8, 32, 32)
local bigFont = gfx.font.new("/fonts/ruby_15")
local smallFont = gfx.font.new("/fonts/topaz_serif_8")

local bannerAnim = gfx.animator.new(1200, 0, 100, pd.easingFunctions.inOutCubic)
local menuAnim = gfx.animator.new(1000, 0, 140, pd.easingFunctions.inOutCubic, 900)

local ITEMS <const> = {"Play", "How to play", "Reset progress"}
local MENU_X <const> = 62
local MENU_Y <const> = 104

function Menu:init()
	Menu.super.init(self)
	self.sel = 1
	self.confirmReset = false
	self.flashTime = 0
end

function Menu:enter()
	gfx.setBackgroundColor(gfx.kColorBlack)
	gfx.clear()
	self.sel = 1
	self.confirmReset = false
	self.flashTime = 0
	bannerAnim:reset()
	menuAnim:reset()
end

function Menu:update(dt)
	if self.flashTime > 0 then
		self.flashTime = self.flashTime - dt
	end

	local ticks = pd.getCrankTicks(12)
	local moved = false
	if pd.buttonJustPressed("up") or ticks < 0 then
		self.sel = self.sel - 1
		moved = true
	elseif pd.buttonJustPressed("down") or ticks > 0 then
		self.sel = self.sel + 1
		moved = true
	end
	if moved then
		self.sel = (self.sel - 1) % #ITEMS + 1
		self.confirmReset = false
	end

	if pd.buttonJustPressed("a") then
		if self.sel == 1 then
			manager:enter(scene_levels)
		elseif self.sel == 2 then
			manager:enter(scene_help)
		elseif self.sel == 3 then
			if self.confirmReset then
				SavedData.resetProgress()
				self.confirmReset = false
				self.flashTime = 2
			else
				self.confirmReset = true
			end
		end
	end
end

function Menu:draw()
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	backImage:draw(0, 0)

	local width, height = bannerImage:getSize()
	local progress = bannerAnim:currentValue()
	local iw = math.floor(width * progress / 100)
	local sx = math.floor(width / 2) - math.floor(iw / 2)
	bannerImage:draw(sx, 0, gfx.image.kUnflipped, playdate.geometry.rect.new(sx, 0, iw, height))

	if bannerAnim:ended() then
		local m = menuAnim:currentValue()
		frameSlice:drawInRect(36, 140 - m / 2, 208, m)
	end

	if menuAnim:ended() then
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		gfx.setFont(bigFont)
		for i, item in ipairs(ITEMS) do
			local cursor = "  "
			if i == self.sel then
				cursor = "> "
			end
			gfx.drawText(cursor .. item, MENU_X, MENU_Y + (i - 1) * 24)
		end

		gfx.setFont(smallFont)
		if self.sel == 3 and self.confirmReset then
			gfx.drawText("press A again to confirm", MENU_X, MENU_Y + #ITEMS * 24 + 6)
		elseif self.flashTime > 0 then
			gfx.drawText("progress cleared", MENU_X, MENU_Y + #ITEMS * 24 + 6)
		else
			gfx.drawText("A select   crank browse", MENU_X, MENU_Y + #ITEMS * 24 + 6)
		end
	end
end
