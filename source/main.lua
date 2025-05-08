import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/nineslice"
import "CoreLibs/animator"
import "defs"
import "scenes"

local pd <const> = playdate
local gfx <const> = playdate.graphics

manager:enter(scene_level)
scene_level:load("1-1")

function pd.update()
    manager:emit('update')
    manager:emit('draw')
end


