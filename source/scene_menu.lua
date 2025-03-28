import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/nineslice"
import "CoreLibs/animator"
import "roomy"

class("Menu").extends(Room)

local pd <const> = playdate
local gfx <const> = playdate.graphics
local bannerAnim = gfx.animator.new(1000, 0, 100, pd.easingFunctions.inOutCubic)
local menuAnim = gfx.animator.new(1000, 0, 140, pd.easingFunctions.inOutCubic, 1000)
local bannerImage = gfx.image.new("/images/banner.png")
local backImage = gfx.image.new("/images/back.png")
local frameSlice = gfx.nineSlice.new("/images/frame.png", 8, 8, 32, 32)

function Menu:enter(previous, ...)
	gfx.setBackgroundColor(gfx.kColorBlack)
    gfx.clear()
	menuAnim:reset()
	bannerAnim:reset()
end

function Menu:draw()
	backImage:draw(0, 0)
	
	local width, height = bannerImage:getSize()
	local progress = bannerAnim:currentValue()
	local iw = width * progress/100
	local x = 200 - iw/2
	bannerImage:draw(x, 0, 0, width/2 - iw/2, 0, iw, height)
	
	if bannerAnim:ended() then
		local m = menuAnim:currentValue()
		frameSlice:drawInRect(40, 140-m/2, 140, m)
	end
end

function Menu:update(dt)

end

function Menu:leave(next, ...)
	
end
