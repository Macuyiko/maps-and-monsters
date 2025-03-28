import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/nineslice"
import "CoreLibs/animator"
import "defs"
import "roomy"
import "scene_menu"

local manager = Manager()
local main_menu = Menu()

manager:enter(main_menu)

function playdate.update()
    manager:emit('update')
    manager:emit('draw')
end

local Dungeon = import "dungeon"
local pd <const> = playdate
local gfx <const> = playdate.graphics
local menu <const> = playdate.getSystemMenu()

local function loadLevel(name)
    local level = json.decodeFile("/levels/levels.json")[name]
    local dungeon = Dungeon.new()
    dungeon.name = name
    for i = 0, DUNGEON_WIDTH - 1 do dungeon.col_count[i] = level["columns"][i+1] end
    for i = 0, DUNGEON_HEIGHT - 1 do dungeon.row_count[i] = level["rows"][i+1] end
    for _, o in ipairs(level["chests"]) do
        dungeon:set_cell(vec(o[1], o[2]), C_TREASURE)
    end
    for _, o in ipairs(level["monsters"]) do
        dungeon:set_cell(vec(o[1], o[2]), C_MONSTER)
    end
    return dungeon
end

local dungeon = loadLevel("1-1")
local selection = {x = 0, y = 0}
local timesec, _ = pd.getSecondsSinceEpoch()

-- Assets
local backImage = gfx.image.new("/images/back.png")
local floorImage = gfx.image.new("/images/floor.png")
local wallImage = gfx.image.new("/images/wall.png")
local markerImage = gfx.image.new("/images/marker.png")
local chestImage = gfx.image.new("/images/chest.png")
local monsterImage = gfx.image.new("/images/monster.png")
local frameSlice = gfx.nineSlice.new("/images/frame.png", 8, 8, 32, 32)

local mapFont = gfx.font.newFamily({
    [gfx.font.kVariantNormal] = "/fonts/ruby_15",
    [gfx.font.kVariantBold] = "/fonts/ruby_15",
    [gfx.font.kVariantItalic] = "/fonts/ruby_15",
})

local animator = gfx.animator.new(1000, 0, 80, pd.easingFunctions.inOutCubic)

local function solve()
    for x = 0, DUNGEON_WIDTH-1 do
        for y = 0, DUNGEON_HEIGHT-1 do
            local c = dungeon:cell({x=x, y=y})
            if (c == C_MARKER or c == C_WALL or c == C_HALLWAY) then
                dungeon:set_cell(vec(selection.x, selection.y), C_UNKNOWN)
            end
        end
    end
    dungeon:solve(false)
end

local function drawCross(x, y)
    local crossPadding = 4
    gfx.drawLine(x+crossPadding, y+crossPadding, x+TILE_SIZE-crossPadding, y+TILE_SIZE-crossPadding)
    gfx.drawLine(x+crossPadding, y+TILE_SIZE-crossPadding, x+TILE_SIZE-crossPadding, y+crossPadding)
end

local function drawMap()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    
    for x = 0, DUNGEON_WIDTH-1 do
        for y = 0, DUNGEON_HEIGHT-1 do
            local c = dungeon:cell({x=x, y=y})
            if c == C_WALL then
                wallImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            else
                floorImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            end
        end
    end

    for x = 0, DUNGEON_WIDTH-1 do
        for y = 0, DUNGEON_HEIGHT-1 do
            local c = dungeon:cell({x=x, y=y})
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            if c == C_TREASURE then
                chestImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_MONSTER then
                monsterImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_MARKER then
                gfx.setImageDrawMode(gfx.kDrawModeBlackTransparent)
                markerImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            end
        end
    end
end

local function drawNumbers()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    for i, v in pairs(dungeon.row_count) do  
        gfx.drawText(tostring(v), 8, TILE_SIZE*(i+1)+8, TILE_SIZE, TILE_SIZE, mapFont, nil, gfx.kWrapWord, gfx.kAlignRight)
        if v == dungeon:count_cells_on_row(C_WALL, i) then
            drawCross(0, TILE_SIZE*(i+1))
        end
    end

    for i, v in pairs(dungeon.col_count) do  
        gfx.drawText(tostring(v), TILE_SIZE*(i+1)+8, 8, TILE_SIZE, TILE_SIZE, mapFont, nil, gfx.kWrapWord, gfx.kAlignCenter)
        if v == dungeon:count_cells_on_col(C_WALL, i) then
            drawCross(TILE_SIZE*(i+1), 0)
        end
    end
end

local function drawSelection()
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(TILE_SIZE*(selection.x+1), TILE_SIZE*(selection.y+1), TILE_SIZE, TILE_SIZE, 2)
end

local function drawStats()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local timesecnow, _ = pd.getSecondsSinceEpoch()
    gfx.drawText(
    "Level: 1-1", 
    (DUNGEON_WIDTH+3) * TILE_SIZE, 10,
    120, 20, mapFont, nil, gfx.kWrapWord, gfx.kAlignLeft)
    gfx.drawText(
    "Time: " .. tostring(timesecnow - timesec), 
    (DUNGEON_WIDTH+3) * TILE_SIZE, 40,
    120, 20, mapFont, nil, gfx.kWrapWord, gfx.kAlignLeft)
end

local function checkSolution()
    local solved = dungeon:check_full_validity(false)
end

local function updateGame()
    gfx.setDrawOffset(8, 8)
    drawMap()
    drawNumbers()
    drawSelection()
    
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeBlackTransparent)
    frameSlice:drawInRect(0, 0, (DUNGEON_WIDTH+2)*TILE_SIZE, (DUNGEON_HEIGHT+2)*TILE_SIZE)

    drawStats()
    
    if pd.buttonJustPressed("up") then selection.y = selection.y - 1 end
    if pd.buttonJustPressed("down") then selection.y = selection.y + 1 end
    if pd.buttonJustPressed("left") then selection.x = selection.x - 1 end
    if pd.buttonJustPressed("right") then selection.x = selection.x + 1 end
    if selection.x < 0 then selection.x = 0 end
    if selection.y < 0 then selection.y = 0 end
    if selection.x > DUNGEON_WIDTH-1 then selection.x = DUNGEON_WIDTH-1 end
    if selection.y > DUNGEON_HEIGHT-1 then selection.y = DUNGEON_HEIGHT-1 end
    
    local c = dungeon:cell({x=selection.x, y=selection.y})
    if pd.buttonJustPressed("a") and (c == C_HALLWAY or c == C_UNKNOWN or c == C_MARKER) then
        dungeon:set_cell(vec(selection.x, selection.y), C_WALL)
    elseif pd.buttonJustPressed("a") and c == C_WALL then
        dungeon:set_cell(vec(selection.x, selection.y), C_HALLWAY)
    elseif pd.buttonJustPressed("b") and (c == C_HALLWAY or c == C_UNKNOWN or c == C_WALL) then
        dungeon:set_cell(vec(selection.x, selection.y), C_MARKER)
    elseif pd.buttonJustPressed("b") and c == C_MARKER then
        dungeon:set_cell(vec(selection.x, selection.y), C_HALLWAY)
    end
end



local menuReturn = menu:addMenuItem("Return to Menu", solve)
local menuReset = menu:addMenuItem("Reset Level", solve)
local menuSolve = menu:addMenuItem("Solve", solve)

