# Maps & Monsters

A Playdate port of **Dungeons & Diagrams**, the puzzle minigame from
[Last Call BBS](https://www.zachtronics.com/last-call-bbs/) by Zachtronics.

Place wall tiles to carve out a dungeon: the numbers say how many walls each
row and column needs, monsters demand dead ends, treasure needs 3x3 rooms
with a single entrance, and everything must stay connected.

All 64 original puzzles are included, extracted from the game's own data.

![screenshot placeholder]

## Playing

- **D-pad** move the cursor (hold to repeat); at the grid edges of the
  level select it changes year pages
- **A** place or remove a wall
- **B** place or remove an X marker (a note that a tile is floor)
- **System menu** reset the level, reveal the solution, or leave

Progress and best times are saved on the device. Levels unlock in order;
four "years" of sixteen puzzles each.

## Development

### Building

Install the [Playdate SDK](https://play.date/dev/) and build with:

```
pdc source Game.pdx
```

Or use the VS Code tasks (Build / Run / Build and Run) that come with this
repository. The bundle can then be opened in the Playdate Simulator or
sideloaded onto a device.

### Level data

The puzzles ship inside Last Call BBS as `Content/tokyo.dat`. The binary
format was reverse-engineered by Alan De Smet
([dundia](https://gitlab.com/AlanDeSmet/dundia)). To regenerate
`source/levels/levels.json`, point the converter at that file:

```
python support/convert_levels.py "path/to/tokyo.dat"
```

The converter validates every puzzle against the game rules before writing
anything, and each level embeds its official solution (used by the in-game
"Show solution" option).

### Tests

The game logic runs headlessly in a Lua 5.4 VM (`lupa`) with a small
Playdate shim, no SDK or simulator required:

```
python support/test_dungeon_lua.py   # all 64 solutions validate, mutations fail
python support/test_scenes_lua.py    # scripted playthrough of every scene
```

Both scripts exit non-zero on failure.

### Repository layout

- `source/` - the game (Lua for the Playdate SDK)
- `support/` - level converter and headless tests
- `.vscode/` - VS Code tasks, debug config, Playdate type stubs

### Playdate quirk worth knowing

`import` on the Playdate runs a file only once, and a **second `import` of the
same module does nothing** - it does not return the module's value again. That
is why the shared modules (`defs.lua`, `levels.lua`, `savedata.lua`,
`dungeon.lua`) expose plain globals (`LevelData`, `SavedData`, `Dungeon`, ...)
instead of returning tables.

## Credits

- Dungeons & Diagrams is by Zachtronics (Last Call BBS); this is an
  unofficial fan port for the Playdate.
- Puzzle data format reverse-engineered by Alan De Smet (dundia, MIT/GPL
  documentation; no code from it is used here).
- [roomy](https://github.com/tesselode/roomy) scene management by tesselode,
  Playdate adaptation by Robert Curry (MIT).
- Art: bundled 1-bit tiles (`support/1bit 16px patterns and tiles.png`).
