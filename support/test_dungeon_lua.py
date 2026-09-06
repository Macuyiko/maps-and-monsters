# Smoke test: runs the real Lua game code (defs.lua, levels.lua, dungeon.lua)
# inside a Lua 5.4 VM with a minimal Playdate shim. For every level it:
#   1. loads the level,
#   2. reveals the official solution,
#   3. asserts the rule validation passes,
#   4. asserts removing any single wall breaks it (validation really checks).

import json
import sys
from lupa import lua54

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


g.playdate = lua.table()
g.playdate.json = lua.table()
g.playdate.json.decodeFile = json_decode_file
g.json = g.playdate.json


def load_module(name):
    with open(f"source/{name}.lua", encoding="utf-8") as f:
        code = f.read()
    fn = lua.compile(code.encode(), f"@{name}.lua")
    return fn()


MODULES = {}

setattr(g, "import", lambda name: MODULES[name])

MODULES["defs"] = load_module("defs")
MODULES["levels"] = load_module("levels")
MODULES["dungeon"] = load_module("dungeon")

runner = lua.eval(
    """
function(LevelData, Dungeon)
    local out = {}
    local fails = 0
    for i, key in ipairs(LevelData.keys) do
        local d = Dungeon.new(LevelData.get(key), key)
        d:reveal_solution()
        if not d:check_full_validity() then
            fails = fails + 1
            table.insert(out, key .. " FAILED on official solution")
        else
            local broke = false
            for y = 0, 7 do
                for x = 0, 7 do
                    if d:cell(x, y) == "#" then
                        d:set_cell(x, y, ".")
                        if d:check_full_validity() then
                            broke = true
                        end
                        d:set_cell(x, y, "#")
                        if broke then break end
                    end
                end
                if broke then break end
            end
            if broke then
                fails = fails + 1
                table.insert(out, key .. " validation accepted a mutated board")
            end
        end
    end
    table.insert(out, "checked " .. #LevelData.keys .. " levels, " .. fails .. " failures")
    return out
end
""",
    [],
)

results = runner(g.LevelData, g.Dungeon)

failed = False
for r in results.values():
    text = str(r)
    print(text)
    if "FAILED" in text or "accepted" in text:
        failed = True
    if "failures" in text and " 0 failures" not in text:
        failed = True

sys.exit(1 if failed else 0)

