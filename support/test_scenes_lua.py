# Headless integration test: runs the real game (defs, levels, save, dungeon,
# roomy, all scenes, main.lua) inside Lua 5.4 with a Playdate SDK shim, and
# scripts a full playthrough: menu -> levels -> gameplay (manual solve, repeat
# input, system menu, show solution, win flow) -> help -> reset progress.

import json
import sys
from pathlib import Path

from lupa import lua54

SDK = Path(r"C:\Users\Seppe\Documents\PlaydateSDK")

lua = lua54.LuaRuntime()
g = lua.globals()


def to_lua(v):
    if isinstance(v, dict):
        t = lua.table()
        for k, val in v.items():
            t[k] = to_lua(val)
        return t
    if isinstance(v, list):
        t = lua.table()
        for i, val in enumerate(v, 1):
            t[i] = to_lua(val)
        return t
    return v


def json_decode_file(path):
    with open("source" + path, encoding="utf-8") as f:
        return to_lua(json.load(f))


def load_file(path):
    code = Path(path).read_text(encoding="utf-8")
    return lua.compile(code.encode(), f"@{path}")


def load_module(name):
    return load_file(f"source/{name}.lua")()


MODULES = {}

SHIM = r"""
local shim = {}

shim.menuItems = {}
shim.datastore = {}
shim.pressed = {}
shim.held = {}
shim.crankPos = 0

local pd = {}

pd.buttonJustPressed = function(b) return shim.pressed[b] == true end
pd.buttonIsPressed = function(b) return shim.held[b] == true end

pd.getCrankPosition = function() return shim.crankPos end

pd.getElapsedTime = function() return 1 / 30 end
pd.resetElapsedTime = function() end

pd.getSystemMenu = function()
    return {
        addMenuItem = function(_, title, cb) shim.menuItems[title] = cb end,
        removeMenuItem = function(_, item) shim.menuItems[item] = nil end,
        removeAllMenuItems = function(_)
            for k in pairs(shim.menuItems) do shim.menuItems[k] = nil end
        end,
    }
end

pd.datastore = {
    read = function(name) return shim.datastore[name] end,
    write = function(t, name) shim.datastore[name] = t end,
    delete = function(name) shim.datastore[name] = nil end,
}

pd.easingFunctions = {
    inOutCubic = function(t, b, c, d) return b + c * t / d end,
    linear = function(t, b, c, d) return b + c * t / d end,
}

pd.json = { decodeFile = _json_decode_file }
pd.getSecondsSinceEpoch = function() return 0, 0 end

pd.geometry = {
    rect = {
        new = function(x, y, w, h)
            return { x = x, y = y, width = w, height = h }
        end,
    },
    point = {
        new = function(x, y)
            return { x = x, y = y }
        end,
    },
    size = {
        new = function(w, h)
            return { width = w, height = h }
        end,
    },
}

local gfx = {}
pd.graphics = gfx

gfx.kColorBlack = 0
gfx.kColorWhite = 1
gfx.kColorClear = 2
gfx.kDrawModeCopy = 0
gfx.kDrawModeWhiteTransparent = 1
gfx.kDrawModeBlackTransparent = 2
gfx.kDrawModeFillWhite = 3
gfx.kDrawModeFillBlack = 4
gfx.kWrapWord = 0
gfx.kWrapTrimmingWord = 1
gfx.kAlignLeft = 0
gfx.kAlignCenter = 1
gfx.kAlignRight = 2

gfx.clear = function() end
gfx.setBackgroundColor = function() end
gfx.setImageDrawMode = function() end
gfx.setColor = function() end
gfx.setDitherPattern = function(pattern)
    if type(pattern) ~= "number" then
        error("setDitherPattern expects a number", 2)
    end
end
gfx.setFont = function() end
gfx.drawLine = function() end
gfx.drawRect = function() end
gfx.drawRoundRect = function() end
gfx.fillRect = function() end
gfx.drawText = function() end
gfx.getTextSize = function(text) return #tostring(text) * 5, 9 end

gfx.image = {
    new = function(_)
        return {
            draw = function() end,
            drawInRect = function() end,
            getSize = function() return 24, 24 end,
        }
    end,
}
gfx.nineSlice = {
    new = function()
        return { drawInRect = function() end }
    end,
}
gfx.animator = {
    new = function()
        return {
            currentValue = function() return 100 end,
            ended = function() return true end,
            reset = function() end,
        }
    end,
}
gfx.font = {
    new = function()
        return {
            drawText = function() end,
            getHeight = function() return 9 end,
        }
    end,
    newFamily = function() return {} end,
}

shim.pd = pd
return shim
"""

CLASS_SHIM = r"""
local function declare_class(name)
    local cls = {}
    cls.__index = cls
    cls.className = name
    cls.extends = function(parent)
        if parent ~= nil then
            cls.super = parent
        end
        local mt = getmetatable(cls) or {}
        mt.__call = function(_, ...)
            local obj = setmetatable({}, cls)
            if obj.init ~= nil then
                obj:init(...)
            end
            return obj
        end
        setmetatable(cls, mt)
        _G[name] = cls
        return cls
    end
    _G[name] = cls
    return cls
end

return {
    class = declare_class,
}
"""

CRANK_SHIM = r"""
local tick_lastCrankReading = nil

local function getCrankTicks(ticksPerRotation)
    local degreesPerSegment = 360 / ticksPerRotation
    local thisCrankReading = playdate.getCrankPosition()
    if tick_lastCrankReading == nil then
        tick_lastCrankReading = thisCrankReading
    end
    local difference = thisCrankReading - tick_lastCrankReading
    if difference > 180 or difference < -180 then
        if tick_lastCrankReading >= 180 then
            tick_lastCrankReading = tick_lastCrankReading - 360
        else
            tick_lastCrankReading = tick_lastCrankReading + 360
        end
    end
    local thisSegment = math.ceil(thisCrankReading / degreesPerSegment)
    local lastSegment = math.ceil(tick_lastCrankReading / degreesPerSegment)
    tick_lastCrankReading = thisCrankReading
    return thisSegment - lastSegment
end

return { getCrankTicks = getCrankTicks }
"""

g._json_decode_file = json_decode_file
shim = lua.eval("function()\n" + SHIM + "\nend", [])()

g.playdate = shim.pd
g.json = shim.pd.json
setattr(g, "import", lambda name: MODULES[name])
g_class = lua.eval("function()\n" + CLASS_SHIM + "\nend", [])()
setattr(g, "class", g_class["class"])

MODULES["CoreLibs/graphics"] = shim.pd.graphics
MODULES["CoreLibs/object"] = lua.table()
MODULES["CoreLibs/nineslice"] = lua.table()
MODULES["CoreLibs/animator"] = lua.table()
MODULES["CoreLibs/crank"] = lua.table()
crank_module = lua.eval("function()\n" + CRANK_SHIM + "\nend", [])()
shim.pd.getCrankTicks = crank_module["getCrankTicks"]

MODULES["defs"] = load_module("defs")
MODULES["savedata"] = load_module("savedata")
MODULES["levels"] = load_module("levels")
MODULES["dungeon"] = load_module("dungeon")
MODULES["roomy"] = load_module("roomy")
MODULES["scene_menu"] = load_module("scene_menu")
MODULES["scene_levels"] = load_module("scene_levels")
MODULES["scene_help"] = load_module("scene_help")
MODULES["scene_game"] = load_module("scene_game")
MODULES["scenes"] = load_module("scenes")
load_module("main")

RUNNER = r"""
function(shim, pd)
    local checks = 0
    local errors = {}

    local function ok(cond, msg)
        checks = checks + 1
        if not cond then
            table.insert(errors, msg)
        end
    end

    local function press(button)
        shim.pressed[button] = true
        pd.update()
        shim.pressed[button] = nil
    end

    local function hold(button, frames)
        shim.held[button] = true
        for i = 1, frames do
            pd.update()
        end
        shim.held[button] = nil
    end

    local function idle(frames)
        for i = 1, frames do
            pd.update()
        end
    end

    -- menu booted via main.lua
    ok(manager ~= nil and scene_game ~= nil, "scenes wired up")
    idle(3)

    -- menu: Play
    press("a")
    idle(3)
    ok(manager._scenes[#manager._scenes] == scene_levels, "Play opens level select")

    -- level select navigation
    press("right")
    ok(scene_levels.cursor == 1, "cursor moves right")
    press("down")
    ok(scene_levels.cursor == 5, "cursor moves down")
    press("left")
    press("up")
    ok(scene_levels.cursor == 0, "cursor moves back")

    press("right")
    press("right")
    press("right")
    ok(scene_levels.cursor == 3 and scene_levels.page == 1, "cursor reaches right edge")
    press("right")
    ok(scene_levels.page == 2 and scene_levels.cursor == 0, "right edge moves to next year")
    press("left")
    ok(scene_levels.page == 1 and scene_levels.cursor == 3, "left edge moves to previous year")
    press("left")
    press("left")
    press("left")
    ok(scene_levels.cursor == 0, "cursor back at first level")

    -- locked level refuses to open (1-2 is locked while 1-1 unsolved)
    press("right")
    press("a")
    idle(2)
    ok(manager._scenes[#manager._scenes] == scene_levels, "locked level does not open")
    press("left")

    -- open 1-1
    press("a")
    idle(2)
    ok(manager._scenes[#manager._scenes] == scene_game, "unlocked level opens game")
    local game = scene_game
    ok(game.dungeon.key == "1-1", "level 1-1 loaded")
    ok(game.dungeon:cell(1, 5) == "T", "chest placed")
    ok(game.dungeon:cell(2, 2) == "M", "monster placed")

    -- cursor repeat: initial press starts hold timer, then held frames repeat
    press("right")
    hold("right", 40)
    ok(game.selection.x == 7, "hold right clamps at 7, got " .. tostring(game.selection.x))
    press("down")
    press("down")
    ok(game.selection.y == 2, "cursor moved down twice")

    -- markers: toggle on, toggle off
    press("b")
    ok(game.dungeon:cell(game.selection.x, game.selection.y) == "-", "marker placed")
    press("b")
    ok(game.dungeon:cell(game.selection.x, game.selection.y) == ".", "marker removed")

    -- system menu: reset level
    ok(shim.menuItems["Reset level"] ~= nil, "system menu has Reset level")
    shim.menuItems["Reset level"]()
    ok(game.selection.x == 0 and game.selection.y == 0, "reset restores selection")
    ok(not game.won, "reset clears win state")

    -- manual solve of 1-1
    local sol = game.dungeon.solution
    for y = 0, 7 do
        local row = sol[y + 1]
        for x = 0, 7 do
            if row:sub(x + 1, x + 1) == "#" then
                game.selection.x = x
                game.selection.y = y
                press("a")
            end
        end
    end
    ok(game.won, "manual solve wins the level")
    local save = pd.datastore.read("mm_save")
    ok(save ~= nil and save.solved["1-1"] ~= nil, "progress saved")
    ok(save.solved["1-1"].cheated == false, "honest solve recorded")
    ok(save.solved["1-1"].time >= 0, "time recorded")

    -- system menu: show solution after reset (cheat path)
    shim.menuItems["Reset level"]()
    ok(not game.won, "reset clears win state again")
    shim.menuItems["Show solution"]()
    ok(game.won, "show solution wins")
    ok(game.cheated, "cheat flagged")
    save = pd.datastore.read("mm_save")
    ok(save.solved["1-1"].cheated == false, "cheat does not overwrite honest record")

    -- win overlay: A advances to next level
    press("a")
    ok(game.dungeon.key == "1-2", "A advances to 1-2")

    -- system menu: return to levels
    shim.menuItems["Return to levels"]()
    ok(manager._scenes[#manager._scenes] == scene_levels, "system menu returns to levels")
    press("b")
    ok(manager._scenes[#manager._scenes] == scene_menu, "B returns to menu")
    press("down")
    press("a")
    idle(2)
    ok(manager._scenes[#manager._scenes] == scene_help, "How to play opens help")
    press("right")
    ok(scene_help.page == 2, "help page advances")
    press("left")
    ok(scene_help.page == 1, "help page goes back")
    press("right")
    press("right")
    press("right")
    press("right")
    ok(scene_help.page == 5, "help page 5")
    press("a")
    ok(manager._scenes[#manager._scenes] == scene_menu, "A on last help page returns to menu")

    -- reset progress via menu (two-step confirm)
    press("down")
    press("down")
    press("a")
    save = pd.datastore.read("mm_save")
    ok(save ~= nil and save.solved["1-1"] ~= nil, "first A only confirms")
    press("a")
    save = pd.datastore.read("mm_save")
    ok(save ~= nil and next(save.solved) == nil, "second A wipes progress")

    return {checks = checks, errors = errors}
end
"""

runner = lua.eval(RUNNER, [])
report = runner(shim, shim.pd)

errors = [str(e) for e in report["errors"].values()]
print(f"checks run: {int(report['checks'])}, failures: {len(errors)}")
for e in errors:
    print("FAIL:", e)
sys.exit(1 if errors else 0)



