# swapDisplays

Swaps the two external displays: they exchange physical left/right positions,
**and the "main" display flag follows the swap** (main is always the display
at the origin `(0,0)`). Per-display wallpapers follow the swap too — the left
monitor keeps showing whatever the left monitor was showing, and same for the
right.

Works idempotently: run it again to restore the original arrangement.

## How it works
1. Reads both displays' current geometry (CoreGraphics) and desktop wallpapers
   (AppleScript / System Events).
2. Moves the non-main display to the origin `(0,0)` and the main display to
   the opposite side. macOS automatically re-assigns "main" to the display at
   the origin, so the main flag moves with the swap.
3. Re-applies the wallpapers to the (new) left/right positions. After a
   reconfiguration the wallpaper agent briefly re-applies its stored
   assignments, so the script re-sets the pictures and verifies (two reads 3 s
   apart) until they actually stick. When the state is already correct this
   takes ~4 s with no extra sets.

## Compile
```
swiftc swapDisplays.swift -o swapDisplays
```

Run as `~/swapDisplays` (symlinked from `~` via the `upd` function in
`~/.zshrc`). Safe to call non-interactively (e.g. from Apple Shortcuts):
no TTY, no permission prompts.

## Requirements
- Exactly **2 external** displays (built-in display is ignored).
- macOS with CoreGraphics + System Events automation.

## Exit codes
`0` OK · `1` wrong display count · `2` CGBegin failed · `3` ConfigureOrigin
failed · `4` Complete failed · `5` could not read wallpapers · `6` geometry
swapped but wallpapers did not converge · `8` display count changed mid-run
