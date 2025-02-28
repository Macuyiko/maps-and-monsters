import "CoreLibs/graphics"
import "CoreLibs/ui"
import "defs"
local Dungeon = import "dungeon"
local pd <const> = playdate
local gfx <const> = playdate.graphics
local menu <const> = playdate.getSystemMenu()


local dungeon = Dungeon.new()
dungeon.row_count = {[0]=5, [1]=2, [2]=2, [3]=2, [4]=7, [5]=1, [6]=4, [7]=5}
dungeon.col_count = {[0]=5, [1]=4, [2]=4, [3]=2, [4]=4, [5]=3, [6]=2, [7]=4}

dungeon:set_cell(vec(5, 3), C_TREASURE)
dungeon:set_cell(vec(0, 2), C_MONSTER)
dungeon:set_cell(vec(7, 5), C_MONSTER)
dungeon:set_cell(vec(0, 6), C_MONSTER)
dungeon:set_cell(vec(2, 6), C_MONSTER)

local selection = {x = 0, y = 0}


-- Assets
local floorImage = gfx.image.new("images/floor.png")
local wallImage = gfx.image.new("images/wall.png")
local markerImage = gfx.image.new("images/marker.png")
local chestImage = gfx.image.new("images/chest.png")
local monsterImage = gfx.image.new("images/monster.png")

local mapFontPaths = {
    [gfx.font.kVariantNormal] = "fonts/ruby_15",
    [gfx.font.kVariantBold] = "fonts/ruby_15",
    [gfx.font.kVariantItalic] = "fonts/ruby_15",
}
local mapFont = gfx.font.newFamily(mapFontPaths)

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
    playdate.graphics.drawLine(x+crossPadding, y+crossPadding, x+TILE_SIZE-crossPadding, y+TILE_SIZE-crossPadding)
    playdate.graphics.drawLine(x+crossPadding, y+TILE_SIZE-crossPadding, x+TILE_SIZE-crossPadding, y+crossPadding)
end


local function drawMap()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    for x = 0, DUNGEON_WIDTH-1 do
        for y = 0, DUNGEON_HEIGHT-1 do
            local c = dungeon:cell({x=x, y=y})
            if c == C_HALLWAY or c == C_UNKNOWN then
                floorImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_TREASURE then
                chestImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_WALL then
                wallImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_MONSTER then
                monsterImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            elseif c == C_MARKER then
                markerImage:draw(TILE_SIZE*(x+1), TILE_SIZE*(y+1))
            end
        end
    end
    
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


function playdate.update()
    gfx.setBackgroundColor(gfx.kColorBlack)
    gfx.clear()
    drawMap()
    drawSelection()
    
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


local menuSolve = menu:addMenuItem("Solve", solve)

