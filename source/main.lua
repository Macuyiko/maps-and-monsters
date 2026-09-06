import "CoreLibs/graphics"
import "defs"
import "scenes"

local pd <const> = playdate

manager:enter(scene_menu)

function pd.update()
	local dt = pd.getElapsedTime()
	pd.resetElapsedTime()
	manager:emit("update", dt)
	manager:emit("draw")
end
