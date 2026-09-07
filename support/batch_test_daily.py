import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, "support")
from convert_levels import rule_check, GRID, CELL_WALL

counts = Counter()
for d in ["2026-09-07", "2026-09-08", "2026-09-09", "2026-09-10", "2026-09-11", "2026-09-12",
          "2026-09-13", "2026-09-14", "2026-09-15", "2026-09-16"]:
    r = subprocess.run([sys.executable, "support/generate_daily.py", d], capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip())
    if r.returncode != 0:
        sys.exit(1)
    lv = json.loads(Path(f"daily/{d}.json").read_text())
    counts[len(lv["chests"])] += 1
    # Independent re-validation
    grid = [[CELL_WALL if c == "#" else 0 for c in row] for row in lv["solution"]]
    for x, y in lv["monsters"]:
        grid[y][x] = 2
    for x, y in lv["chests"]:
        grid[y][x] = 3
    problems = rule_check(grid, lv["rows"], lv["columns"])
    assert not problems, (d, problems)

print("chest counts across 10 days:", sorted(counts.items()))
print("all independent rule_check validations passed")
