# BLEIFIX: crash fix for Bleifuss / Screamer (1995, DOS)

A small DOS patcher for the High Detail executable (`STARTH.EXE`) of the racing game **Bleifuss**, known internationally as **Screamer**.

It fixes two related memory corruption bugs in the game's renderer:

- a crash on the **Sunbeach Hill** track, typically near the crane by the harbour
- a crash directly after crossing the finish line on track Sandrock, after finishing a whole championship, while the camera moves over the car
- random crashes on other tracks

> This repository contains no game files. You need your own copy of the game.

## Symptoms

The main crashes happen at about the same spots at Sunbeach Hill, but they can look different each time:

- a complete freeze
- a freeze with repeating sound
- a return to DOS with a DOS/4GW register dump, such as `exception 06h (invalid opcode)`
- DOSBox closing by itself

The Sunbeach Hill crash is reported to have happened on real DOS machines as well as in DOSBox, so it is not an emulator problem. 
usual workarounds:
- quit the game before Sunbeach Hill and start the game with zhe Low Detail executable (`STARTL.EXE`)
- delete or rename MAP5H.DAT in the GFX folder and copy MAP5L.DAT over MAP5H.DAT, then the games loads the low reslution for this track, even the game is startet with STARTH.EXE. But this results in some glitches, where some buldings are not shown

## Usage

1. Download `BLEIFIX.COM` and copy it into your game folder, next to `STARTH.EXE`.
2. Run `BLEIFIX` in DOS or DOSBox.
3. Start the game with `STARTH.EXE` as usual.

| State of `STARTH.EXE` | What BLEIFIX does | File changed? |
|---|---|---|
| Original, supported version | Creates `STARTH.BAK`, patches the file, verifies the result | Yes |
| Patched with BLEIFIX 1.0 | Creates `STARTH.BAK` if missing, updates the file to 1.1 | Yes |
| Already patched with 1.1 | Reports this and exits | No |
| Different version | Reports an unknown version and exits | No |
| Write-protected | Reports this and exits | No |
| Not found | Reports an error and exits | No |

An existing `STARTH.BAK` is never overwritten. If you update from BLEIFIX 1.0 and no backup exists yet, the backup contains the 1.0 version, not the original. If the backup cannot be created, the executable is left untouched.

**To undo the patch**, copy `STARTH.BAK` back over `STARTH.EXE`.

## Supported version

Only this exact file is supported. BLEIFIX checks its size, a checksum and every patch location.

| File | Size | SHA-256 |
|---|---|---|
| Original `STARTH.EXE` | 1,034,923 bytes | `1246afc95463f96598d5fee764fc99c847b6d3e0bf8ca2268bd362c664bb28a3` |
| Patched with BLEIFIX 1.0 | 1,034,923 bytes | `31cab7b7ac9a8080d95f2c511f77ddebf20e4e29c99239ace1008217153b792e` |
| Patched with BLEIFIX 1.1 | 1,034,923 bytes | `27401844e474ee5fed7a04b24e9091827bf9c2afb734e446818956e4e353351a` |

Other releases or language versions may have different code addresses. If your file is reported as unknown, the fix would have to be adapted to that version.

## Root cause

Both bugs have the same pattern: a renderer loop writes one entry per screen row and trusts that the polygon was clipped to the screen before. When a polygon reaches it with coordinates far outside the screen, the loop writes far past the end of its buffer.

### Bug 1: the Sunbeach Hill crash

The renderer draws textured polygons column by column. Its inner loop writes a pixel, then moves down one row by adding the 640-byte screen pitch:

```asm
mov  [edi], al
add  edi, 0x280
```

These loops do not check the screen bounds themselves. In some scenes, a polygon reaches them with coordinates far below the screen. In the captured case, about 366 rows were still left to draw when the loop was already outside the picture.

The 640x480 video buffer is followed in memory by other game data, including the table of track object pointers. The overflow replaced those pointers with pixel values such as `E6E6E6E6`. The game crashed later when it used them, which is why the visible symptoms varied.

The write was caught in the DOSBox debugger with a memory breakpoint on a corrupted table entry:

```
DEBUG: Memory breakpoint : 0000:59C38 - 7C -> E6
```

**Why High Detail only?** In `MAP5H` the object table has 398 entries, so the corrupted slots are in use. In `MAP5L` it has only 360, so at least the slots seen in the crash dumps fall into unused reserve space. This likely explains why `STARTL.EXE` survives, though it was not confirmed separately in the debugger.

### Bug 2: the finish line crash on Sandrock

Before drawing, the renderer builds a list of polygon edges with 24 bytes per screen row. This list grows downward in memory from a fixed address and has room for about 1,200 rows.

The edge loops do not check whether a polygon ends far below the screen. The DOSBox log showed thousands of writes from the same instruction, starting at `FFFFFFFC` and counting down: the loop had run through all code and data down to address 0 and wrapped around.

The crash happened while the finish camera moved very close over the player's car. A likely explanation is that polygons right in front of the camera project to coordinates far outside the screen, but this was not verified.

## What the patch changes

All addresses are linked addresses in the LE executable's code object. The new code is placed in unused padding at the end of that object.

1. **Row clipping.** Six drawing paths now call a small routine that limits each column to screen rows 0–479 before drawing. Hook sites: `0xCDC66`, `0xD5CFC`, `0xDCB16`, `0xDBC4B`, `0xCCDBC`, `0xDA795`.
2. **Larger polygon list.** The per-frame polygon list is moved from an 8,000-byte buffer to a new 128 KB area, by updating its four relocation entries and extending the object size. This is a precaution: an overflow of the list was suspected but never proven.
3. **Edge list limit** (new in 1.1). All four edge builders of the renderer now limit each edge segment to the space left in the edge list. Hook sites: 12 entry jumps into the loops at `0xD5A49`, `0xDB9ED`, `0xCD9E9` and `0xDC89D`. Rows beyond the list are simply not computed. The routine is position-independent, so no new relocation entries are needed.

Compared to the original file, 291 bytes change, and the file size stays the same.

## Testing and known limitations

- **Testing:** In DOSBox 0.74-3, a test build of the crane fix ran 5 races without a crash. The 1.1 executable then completed 2 full championships without a crash, including the finish of the last track.
- **Real hardware:** Not tested. The patch adds only basic 386 instructions, but it needs 128 KB more memory.
- **Graphical glitches:** Brief glitches can still appear near the crane, elsewhere on the track and possibly on the car during the finish camera. The patch stops the memory damage, but it does not correct the bad polygon coordinates.
- **Other crashes:** The renderer may contain more loops without bounds checks. Only the paths that crashed in testing, and their direct siblings, were fixed.

If you still get a crash, please open an issue with your track, the location, any DOS/4GW dump and the first `Illegal read` or `Illegal write` lines from DOSBox. Starting DOSBox with `-noconsole` writes these lines to `stdout.txt`.

## Building from source

The patcher is written in 16-bit x86 assembly and assembles with [NASM](https://www.nasm.us/):

```sh
nasm -f bin BLEIFIX.ASM -o BLEIFIX.COM
```

The patcher was tested in a small custom DOS emulator with 12 scenarios, including updating from 1.0, a missing file, a wrong version, a write-protected file and a full disk. It has not yet been run under real DOS or DOSBox.

SHA-256 of the released `BLEIFIX.COM` 1.1: `46e1235a7d41d65dae6d348f57b15c9eedcf8fda2062980275b4be880a83298c`

## Changelog

- **1.1:** Fixes the crash after the finish line on Sandrock after complete championship. Updates files patched with 1.0. Detects write-protected files. English messages.
- **1.0:** Fixes the Sunbeach Hill crash near the crane.

## Legal

This is an unofficial fan project, not affiliated with or endorsed by the game's developers or publishers. Bleifuss and Screamer are trademarks of their respective owners. Use at your own risk and keep a backup.
