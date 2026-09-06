# Converts the Dungeons & Diagrams puzzle data from Last Call BBS
# (Content/tokyo.dat) into source/levels/levels.json for the Playdate game.
#
# The tokyo.dat binary format was reverse-engineered by Alan De Smet and is
# documented at https://gitlab.com/AlanDeSmet/dundia
#
# Usage:
#   python support/convert_levels.py [path/to/tokyo.dat]
#
# If no path is given the script looks in common Steam library locations.

import json
import struct
import sys
from pathlib import Path

DEFAULT_INPUTS = [
    r"E:\SteamLibrary\steamapps\common\Last Call BBS\Content\tokyo.dat",
    r"C:\Program Files (x86)\Steam\steamapps\common\Last Call BBS\Content\tokyo.dat",
]

MONSTER_NAMES = {
    0: "bugbear", 1: "mimic", 2: "cultist", 3: "goat", 4: "imp",
    5: "goblin", 6: "golem", 7: "demon", 8: "insectoid", 9: "deathknight",
    10: "lich", 11: "minotaur", 12: "lookseer", 13: "ogre", 14: "skeleton",
    15: "slime", 16: "mindflayer", 17: "kobold",
}

# Cell codes as stored in tokyo.dat
CELL_OPEN = 0
CELL_WALL = 1
CELL_DEADEND = 2
CELL_TREASURE = 3

GRID = 8
DIRS = [(0, -1), (-1, 0), (0, 1), (1, 0)]


def read_puzzles(path):
    puzzles = []
    with open(path, "rb") as f:
        (count,) = struct.unpack("<L", f.read(4))
        for _ in range(count):
            (title_len,) = struct.unpack("<L", f.read(4))
            title = f.read(title_len).decode("ascii")
            data = f.read(80)
            cells = list(data[:64])
            primary, boss, boss_col, boss_row = struct.unpack("<LLLL", data[64:80])
            grid = [cells[r * GRID : (r + 1) * GRID] for r in range(GRID)]
            puzzles.append({
                "title": title.replace("\n", " ").strip(),
                "grid": grid,
                "primary": primary,
                "boss": boss,
                "boss_col": boss_col,
                "boss_row": boss_row,
            })
    return puzzles


def rule_check(grid, rows, columns):
    """Validate a solution grid against the game rules (mirrors the Lua
    implementation). Returns a list of problems (empty = valid)."""
    problems = []

    def cell(x, y):
        if 0 <= x < GRID and 0 <= y < GRID:
            return grid[y][x]
        return CELL_WALL

    # Row / column wall counts
    for r in range(GRID):
        if sum(1 for c in grid[r] if c == CELL_WALL) != rows[r]:
            problems.append(f"row {r} count mismatch")
    for c in range(GRID):
        if sum(1 for r in range(GRID) if grid[r][c] == CELL_WALL) != columns[c]:
            problems.append(f"col {c} count mismatch")

    # Dead ends: every monster on a dead end, every dead end has a monster
    for y in range(GRID):
        for x in range(GRID):
            walls_around = sum(1 for dx, dy in DIRS if cell(x + dx, y + dy) == CELL_WALL)
            dead_end = cell(x, y) != CELL_WALL and walls_around == 3
            monster = cell(x, y) == CELL_DEADEND
            if monster and not dead_end:
                problems.append(f"monster not on dead end at {x},{y}")
            if dead_end and not monster:
                problems.append(f"dead end without monster at {x},{y}")

    # Treasure rooms: each chest in exactly one all-floor 3x3 with one entrance
    room_tiles = set()
    for y in range(GRID):
        for x in range(GRID):
            if cell(x, y) != CELL_TREASURE:
                continue
            placements = []
            for oy in range(-2, 1):
                for ox in range(-2, 1):
                    if all(cell(x + ox + dx, y + oy + dy) in (CELL_OPEN, CELL_TREASURE)
                           for dy in range(3) for dx in range(3)):
                        placements.append((x + ox, y + oy))
            if len(placements) != 1:
                problems.append(f"chest at {x},{y} has {len(placements)} room placements")
                continue
            rx, ry = placements[0]
            for dy in range(3):
                for dx in range(3):
                    room_tiles.add((rx + dx, ry + dy))
            entrances = sum(
                1 for i in range(3)
                for ex, ey in ((rx + i, ry - 1), (rx + i, ry + 3),
                               (rx - 1, ry + i), (rx + 3, ry + i))
                if cell(ex, ey) != CELL_WALL
            )
            if entrances != 1:
                problems.append(f"chest room at {rx},{ry} has {entrances} entrances")

    # No 2x2 floor blocks outside treasure rooms
    for y in range(GRID - 1):
        for x in range(GRID - 1):
            block = [(x + dx, y + dy) for dy in range(2) for dx in range(2)]
            if any(t in room_tiles for t in block):
                continue
            if all(cell(bx, by) != CELL_WALL for bx, by in block):
                problems.append(f"2x2 open block at {x},{y}")

    # Single connected floor component
    floor = {(x, y) for y in range(GRID) for x in range(GRID)
             if grid[y][x] != CELL_WALL}
    seen = set()
    stack = [next(iter(floor))]
    while stack:
        p = stack.pop()
        if p in seen:
            continue
        seen.add(p)
        x, y = p
        for dx, dy in DIRS:
            n = (x + dx, y + dy)
            if n in floor and n not in seen:
                stack.append(n)
    if len(seen) != len(floor):
        problems.append(f"floor not connected: {len(seen)}/{len(floor)} cells reachable")

    return problems


def main():
    path = None
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        for candidate in DEFAULT_INPUTS:
            if Path(candidate).exists():
                path = candidate
                break
    if not path or not Path(path).exists():
        print("tokyo.dat not found; pass its path as the first argument")
        return 1

    puzzles = read_puzzles(path)
    print(f"Loaded {len(puzzles)} puzzles from {path}")

    levels = {}
    failures = 0
    for i, puz in enumerate(puzzles):
        year = i // 16 + 1
        index = i % 16 + 1
        key = f"{year}-{index}"
        grid = puz["grid"]
        rows = [sum(1 for c in grid[r] if c == CELL_WALL) for r in range(GRID)]
        columns = [sum(1 for r in range(GRID) if grid[r][c] == CELL_WALL) for c in range(GRID)]
        chests = [[x, y] for y in range(GRID) for x in range(GRID) if grid[y][x] == CELL_TREASURE]
        monsters = [[x, y] for y in range(GRID) for x in range(GRID) if grid[y][x] == CELL_DEADEND]
        boss_present = grid[puz["boss_row"]][puz["boss_col"]] == CELL_DEADEND

        level = {
            "name": puz["title"],
            "columns": columns,
            "rows": rows,
            "chests": chests,
            "monsters": monsters,
            "monster": MONSTER_NAMES.get(puz["primary"], "goblin"),
            "boss": MONSTER_NAMES.get(puz["boss"], "goblin"),
            "boss_pos": [puz["boss_col"], puz["boss_row"]] if boss_present else None,
            "solution": ["".join("#" if c == CELL_WALL else "." for c in row) for row in grid],
        }

        problems = rule_check(grid, rows, columns)
        if problems:
            failures += 1
            print(f"  [{key}] {level['name']}: FAILED validation")
            for p in problems:
                print(f"      {p}")

        levels[key] = level

    if failures:
        print(f"{failures} puzzles failed validation; NOT writing output")
        return 1

    out = Path(__file__).resolve().parent.parent / "source" / "levels" / "levels.json"
    out.write_text(format_levels(levels), encoding="utf-8")
    print(f"Wrote {len(levels)} validated levels to {out}")
    return 0


def _inline(value):
    return json.dumps(value, separators=(",", ":"))


def format_levels(levels):
    """Compact JSON with each level's arrays kept on single lines."""
    parts = []
    for key in sorted(levels, key=lambda k: tuple(int(n) for n in k.split("-"))):
        lv = levels[key]
        fields = [f'"name": {_inline(lv["name"])}']
        for field in ("columns", "rows", "chests", "monsters"):
            fields.append(f'"{field}": {_inline(lv[field])}')
        fields.append(f'"monster": {_inline(lv["monster"])}')
        fields.append(f'"boss": {_inline(lv["boss"])}')
        fields.append(f'"boss_pos": {_inline(lv["boss_pos"])}')
        fields.append('"solution": [' + ", ".join(_inline(r) for r in lv["solution"]) + "]")
        parts.append(f' "{key}": {{\n  ' + ",\n  ".join(fields) + "\n }")
    return "{\n" + ",\n".join(parts) + "\n}\n"


if __name__ == "__main__":
    sys.exit(main())
