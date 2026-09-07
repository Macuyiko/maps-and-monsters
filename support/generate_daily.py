# Generates a "daily" dungeon puzzle for maps-and-monsters.
#
# Usage:
#   uv run python support/generate_daily.py [YYYY-MM-DD] [--difficulty easy|medium|hard]
#
# Writes daily/YYYY-MM-DD.json using the same level schema as
# source/levels/levels.json (plus a "difficulty" field), suitable for
# hosting online and downloading from the game later.
#
# Generation is seeded from the date (+ difficulty), so the same date always
# produces the same puzzle.
#
# Difficulty tiers:
#   easy   - solvable with row/column count deduction alone
#   medium - additionally requires dead-end / neighbour deduction
#   hard   - requires branching / guessing beyond that
#
# Every generated puzzle is validated with rule_check() (the authoritative
# port of the game rules) and a solution counter guarantees a unique answer.

import argparse
import json
import random
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from convert_levels import (  # noqa: E402
    CELL_OPEN,
    CELL_WALL,
    CELL_DEADEND,
    CELL_TREASURE,
    GRID,
    DIRS,
    rule_check,
)

MONSTERS = [
    "bugbear", "mimic", "cultist", "goat", "imp", "goblin", "golem", "demon",
    "insectoid", "deathknight", "lich", "minotaur", "lookseer", "ogre",
    "skeleton", "slime", "mindflayer",
]
BOSSES = ["bugbear", "ogre", "deathknight", "golem", "lich", "goat", "mimic", "lookseer"]

UNKNOWN = -1
WALL = CELL_WALL
OPEN = CELL_OPEN
MONSTER = CELL_DEADEND
TREASURE = CELL_TREASURE


# ---------------------------------------------------------------------------
# Grid generation
# ---------------------------------------------------------------------------

CHEST_COUNTS = [0] * 25 + [1] * 55 + [2] * 15 + [3] * 3 + [4] * 2


def generate_grid(rng):
    """Build a random valid-shape dungeon. Returns grid or None."""
    grid = [[WALL] * GRID for _ in range(GRID)]

    n_chests = rng.choice(CHEST_COUNTS)

    # Treasure rooms: one 3x3 per chest (matching the original levels), one
    # entrance each; ring cells stay wall so the entrance count is exactly 1
    # by construction.
    rooms = []
    entrances = []
    chest_cells = []
    if n_chests > 0:
        # Like the original levels: every chest gets its own room.
        for _ in range(n_chests):
            placed = _place_room(rng, rooms)
            if placed is None:
                return None
            rx, ry, room = placed
            rooms.append(room)
            border = []
            for i in range(3):
                border += [
                    (rx + i, ry - 1), (rx + i, ry + 3),
                    (rx - 1, ry + i), (rx + 3, ry + i),
                ]
            border = [p for p in border if 0 <= p[0] < GRID and 0 <= p[1] < GRID]
            if not border:
                return None
            entrance = rng.choice(border)
            entrances.append(entrance)
            chest_cells.append(rng.choice(sorted(room)))
        for room in rooms:
            for x, y in room:
                grid[y][x] = OPEN
        for x, y in chest_cells:
            grid[y][x] = TREASURE
        for x, y in entrances:
            grid[y][x] = OPEN

    # Collect ring cells (kept wall) for every room.
    ring = set()
    for room in rooms:
        for y in range(GRID):
            for x in range(GRID):
                if grid[y][x] == WALL and any(
                    abs(x - tx) <= 1 and abs(y - ty) <= 1 and (x != tx or y != ty)
                    for tx, ty in room
                ):
                    ring.add((x, y))

    def block_ok(x, y):
        # Would opening (x,y) complete a 2x2 all-open block outside all rooms?
        for oy in (-1, 0):
            for ox in (-1, 0):
                b = [(x + ox + dx, y + oy + dy) for dy in range(2) for dx in range(2)]
                if any(any(t in room for t in b) for room in rooms):
                    continue
                if all(
                    0 <= bx < GRID and 0 <= by < GRID and grid[by][bx] != WALL
                    for bx, by in b
                ):
                    return False
        return True

    # Randomized DFS carving from the entrance(s), or anywhere for roomless maps.
    if entrances:
        stack = list(entrances)
    else:
        start = (rng.randrange(GRID), rng.randrange(GRID))
        grid[start[1]][start[0]] = OPEN
        stack = [start]
    while stack:
        x, y = stack[-1]
        nbrs = []
        for dx, dy in DIRS:
            nx, ny = x + dx, y + dy
            if (
                0 <= nx < GRID and 0 <= ny < GRID
                and grid[ny][nx] == WALL
                and (nx, ny) not in ring
            ):
                nbrs.append((nx, ny))
        rng.shuffle(nbrs)
        placed = False
        for nx, ny in nbrs:
            grid[ny][nx] = OPEN
            if block_ok(nx, ny):
                stack.append((nx, ny))
                placed = True
                break
            grid[ny][nx] = WALL
        if not placed:
            stack.pop()

    def walls_around(x, y):
        return sum(
            1 for dx, dy in DIRS
            if not (0 <= x + dx < GRID and 0 <= y + dy < GRID)
            or grid[y + dy][x + dx] == WALL
        )

    deadends = [
        (x, y) for y in range(GRID) for x in range(GRID)
        if grid[y][x] != WALL and walls_around(x, y) == 3
    ]
    if not 2 <= len(deadends) <= 9:
        return None
    for x, y in deadends:
        grid[y][x] = MONSTER

    wall_count = sum(row.count(WALL) for row in grid)
    if not 14 <= wall_count <= 46:
        return None

    problems = rule_check(grid, *derive_counts(grid))
    if problems:
        return None
    return grid


def _place_room(rng, existing):
    """Find a random 3x3 with at least one wall row/column between it and
    every existing room (rings may touch; room tiles may not be adjacent)."""
    for _ in range(60):
        rx = rng.randrange(0, GRID - 2)
        ry = rng.randrange(0, GRID - 2)
        ok = True
        for room in existing:
            xs = [p[0] for p in room]
            ys = [p[1] for p in room]
            if not (
                rx >= max(xs) + 2 or min(xs) >= rx + 4
                or ry >= max(ys) + 2 or min(ys) >= ry + 4
            ):
                ok = False
                break
        if ok:
            return rx, ry, {(rx + dx, ry + dy) for dx in range(3) for dy in range(3)}
    return None


def derive_counts(grid):
    rows = [sum(1 for c in row if c == WALL) for row in grid]
    columns = [sum(1 for r in range(GRID) if grid[r][c] == WALL) for c in range(GRID)]
    return rows, columns


def derive_clues(grid):
    rows, columns = derive_counts(grid)
    chests = [[x, y] for y in range(GRID) for x in range(GRID) if grid[y][x] == TREASURE]
    monsters = [[x, y] for y in range(GRID) for x in range(GRID) if grid[y][x] == MONSTER]
    return rows, columns, chests, monsters


# ---------------------------------------------------------------------------
# Uniqueness: count solutions consistent with the clues (cap 2)
# ---------------------------------------------------------------------------

def _rows_as_masks(rows, must_open):
    masks = []
    for y in range(GRID):
        opts = []
        for m in range(1 << GRID):
            if bin(m).count("1") != rows[y]:
                continue
            if m & must_open[y]:
                continue
            opts.append(m)
        masks.append(opts)
    return masks


def count_solutions(rows, columns, chests, monsters, cap=2):
    monster_set = {(x, y) for x, y in monsters}
    must_open = [0] * GRID
    for x, y in monsters + chests:
        must_open[y] |= 1 << x

    # Conservative exempt zone for 2x2 pruning: any tile that could belong to a
    # chest room (union of all 3x3 windows containing the chest = 5x5 box).
    exempt = set()
    for cx, cy in chests:
        for y in range(max(0, cy - 2), min(GRID, cy + 3)):
            for x in range(max(0, cx - 2), min(GRID, cx + 3)):
                exempt.add((x, y))

    options = _rows_as_masks(rows, must_open)
    # Fewest options first would break row order; instead order rows normally
    # but rely on pruning.
    chosen = [0] * GRID
    count = 0

    def dead_end_row_ok(y):
        # Full dead-end check for row y (needs rows y-1, y, y+1 all assigned).
        row = chosen[y]
        for x in range(GRID):
            if row & (1 << x):
                continue  # wall
            walls = 0
            for dx, dy in DIRS:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GRID and 0 <= ny < GRID):
                    walls += 1
                elif chosen[ny] & (1 << nx):
                    walls += 1
            if (x, y) in monster_set:
                if walls != 3:
                    return False
            elif walls == 3:
                return False
        return True

    def two_by_two_ok(y):
        # 2x2 blocks formed by rows y-1 and y.
        if y == 0:
            return True
        top, bot = chosen[y - 1], chosen[y]
        for x in range(GRID - 1):
            bits = (1 << x) | (1 << (x + 1))
            if (top & bits) or (bot & bits):
                continue
            block = [(x, y - 1), (x + 1, y - 1), (x, y), (x + 1, y)]
            if any(t in exempt for t in block):
                continue
            return False
        return True

    def rec(y, col_sums):
        nonlocal count
        if count >= cap:
            return
        if y == GRID:
            if dead_end_row_ok(GRID - 1):
                grid = [
                    [WALL if chosen[r] & (1 << c) else OPEN for c in range(GRID)]
                    for r in range(GRID)
                ]
                for x, y2 in monsters:
                    grid[y2][x] = MONSTER
                for x, y2 in chests:
                    grid[y2][x] = TREASURE
                if not rule_check(grid, rows, columns):
                    count += 1
            return
        for m in options[y]:
            new_sums = [col_sums[c] + ((m >> c) & 1) for c in range(GRID)]
            ok = True
            remaining = GRID - 1 - y
            for c in range(GRID):
                need = columns[c] - new_sums[c]
                if need < 0 or need > remaining:
                    ok = False
                    break
            if not ok:
                continue
            chosen[y] = m
            if y > 0 and not two_by_two_ok(y):
                continue
            if y > 0 and not dead_end_row_ok(y - 1):
                continue
            rec(y + 1, new_sums)
            if count >= cap:
                return

    rec(0, [0] * GRID)
    return count


# ---------------------------------------------------------------------------
# Difficulty analysis: logic-only solver
# ---------------------------------------------------------------------------

def _propagate(rows, columns, chests, monsters, use_neighbors):
    state = [[UNKNOWN] * GRID for _ in range(GRID)]
    for x, y in monsters:
        state[y][x] = MONSTER
    for x, y in chests:
        state[y][x] = TREASURE

    def neighbor_info(x, y):
        walls = opens = unknowns = 0
        unknown = []
        for dx, dy in DIRS:
            nx, ny = x + dx, y + dy
            if not (0 <= nx < GRID and 0 <= ny < GRID):
                walls += 1
                continue
            v = state[ny][nx]
            if v == WALL:
                walls += 1
            elif v == UNKNOWN:
                unknowns += 1
                unknown.append((nx, ny))
            else:
                opens += 1
        return walls, opens, unknowns, unknown

    changed = True
    while changed:
        changed = False

        # Row/column count deduction.
        for y in range(GRID):
            known = sum(1 for x in range(GRID) if state[y][x] == WALL)
            unknown = [x for x in range(GRID) if state[y][x] == UNKNOWN]
            need = rows[y] - known
            if need < 0:
                return "contradiction"
            if unknown:
                if need == 0:
                    for x in unknown:
                        state[y][x] = OPEN
                    changed = True
                elif need == len(unknown):
                    for x in unknown:
                        state[y][x] = WALL
                    changed = True
        for x in range(GRID):
            known = sum(1 for y in range(GRID) if state[y][x] == WALL)
            unknown = [y for y in range(GRID) if state[y][x] == UNKNOWN]
            need = columns[x] - known
            if need < 0:
                return "contradiction"
            if unknown:
                if need == 0:
                    for y in unknown:
                        state[y][x] = OPEN
                    changed = True
                elif need == len(unknown):
                    for y in unknown:
                        state[y][x] = WALL
                    changed = True

        if not use_neighbors:
            continue

        # Dead-end / neighbour deduction.
        for y in range(GRID):
            for x in range(GRID):
                v = state[y][x]
                if v == WALL or v == UNKNOWN:
                    continue
                walls, opens, unknowns, unknown = neighbor_info(x, y)
                if v == MONSTER:
                    # Exactly 3 wall neighbours.
                    if walls > 3 or opens > 1:
                        return "contradiction"
                    if unknowns:
                        if walls == 3:
                            for nx, ny in unknown:
                                state[ny][nx] = OPEN
                            changed = True
                        elif walls + unknowns == 3:
                            for nx, ny in unknown:
                                state[ny][nx] = WALL
                            changed = True
                else:
                    # Must not be a dead end (exactly 3 walls).
                    if walls == 3:
                        return "contradiction"
                    if walls == 2 and unknowns:
                        for nx, ny in unknown:
                            state[ny][nx] = OPEN
                        changed = True

    for y in range(GRID):
        for x in range(GRID):
            if state[y][x] == UNKNOWN:
                return "stuck"
    return "solved"


def difficulty_tier(rows, columns, chests, monsters):
    if _propagate(rows, columns, chests, monsters, False) == "solved":
        return 1
    if _propagate(rows, columns, chests, monsters, True) == "solved":
        return 2
    return 3


TIER_NAMES = {1: "easy", 2: "medium", 3: "hard"}
NAME_TIERS = {v: k for k, v in TIER_NAMES.items()}


# ---------------------------------------------------------------------------
# Daily assembly
# ---------------------------------------------------------------------------

def build_level(rng, difficulty_name):
    target = NAME_TIERS[difficulty_name]
    for attempt in range(1, 3001):
        grid = generate_grid(rng)
        if grid is None:
            continue
        rows, columns, chests, monsters = derive_clues(grid)
        if count_solutions(rows, columns, chests, monsters, cap=2) != 1:
            continue
        tier = difficulty_tier(rows, columns, chests, monsters)
        if tier != target:
            continue

        monster = rng.choice(MONSTERS)
        boss = rng.choice(BOSSES)
        while boss == monster:
            boss = rng.choice(BOSSES)
        boss_pos = rng.choice(monsters)
        return {
            "name": "THE DAILY DUNGEON",
            "difficulty": difficulty_name,
            "columns": columns,
            "rows": rows,
            "chests": chests,
            "monsters": monsters,
            "monster": monster,
            "boss": boss,
            "boss_pos": list(boss_pos),
            "solution": [
                "".join("#" if grid[y][x] == WALL else "." for x in range(GRID))
                for y in range(GRID)
            ],
        }, attempt
    return None, 3000


def main():
    parser = argparse.ArgumentParser(description="Generate a daily dungeon puzzle.")
    parser.add_argument(
        "date", nargs="?", default=None,
        help="puzzle date as YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--difficulty", choices=["easy", "medium", "hard"], default="medium",
        help="target difficulty tier (default: medium)",
    )
    parser.add_argument(
        "--out", default=None,
        help="output directory (default: <repo>/daily)",
    )
    args = parser.parse_args()

    if args.date is None:
        day = date.today()
    else:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
            parser.error("date must be YYYY-MM-DD")
        try:
            day = date.fromisoformat(args.date)
        except ValueError:
            parser.error("date must be a real calendar date")
    date_str = day.isoformat()

    rng = random.Random(f"maps-and-monsters-daily-{date_str}-{args.difficulty}")
    level, attempts = build_level(rng, args.difficulty)
    if level is None:
        print(f"No {args.difficulty} puzzle found for {date_str} after 3000 attempts")
        return 1

    out_dir = Path(args.out) if args.out else Path(__file__).resolve().parent.parent / "daily"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{date_str}.json"
    out_path.write_text(json.dumps(level, indent=1) + "\n", encoding="utf-8")

    print(f"{date_str}: {args.difficulty} ({attempts} attempts)")
    print(f"  walls {sum(level['rows'])}  monsters {len(level['monsters'])}  "
          f"chests {len(level['chests'])}  {level['monster']} / boss {level['boss']}")
    print(f"  wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
