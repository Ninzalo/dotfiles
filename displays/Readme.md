# swapDisplays

True A<->B toggle for the two MAG 274QF X24 displays.

States (wallpapers and the main flag always follow the **virtual** sides):

- **A (your target):** physical-left MAG = virtual left, non-main,
  "Dunes left.png"; physical-right MAG = virtual right, **main**,
  "Dunes right.png".
- **B (swapped):** the two MAGs exchange their virtual sides.

One run flips to the other state; a second run flips back. Both MAGs are kept
at 120 Hz (change `TARGET_HZ` at the top of the source if that ever changes).

## 3rd display (iPad via Sidecar / Screen Mirroring)

Any other attached display is **strictly untouched**: no geometry, wallpaper,
refresh-rate, or main-display change. The script snapshots its position and
wallpaper before the swap and verifies both are unchanged after. It also
refuses to run if the main display is not one of the two MAGs.

## Identity (reconnect-safe)

The MAGs are identified by their **EDID serial numbers** (read live from
IORegistry each run: `CE4H245301931` = physical left, `CE4H245301978` =
physical right), not by CG display IDs or wallpaper-store UUIDs, which both
change after a cable reconnect. Serials only feed the report labels; the
flip itself is identity-free (virtual-left <-> virtual-right).

## How it works

1. Classify displays: CG snapshot + ioreg DCP->EDID serial map. Guard rails
   abort (zero changes) unless exactly the two MAG serials are present and the
   main display is a MAG.
2. Detect the current state (A or B) and build the plan.
3. Read the wallpaper list (System Events) and re-validate the desktop-slot
   ordering rule against the invariant "left.png on the virtual-left MAG,
   right.png on the virtual-right MAG".
4. Apply geometry (+ refresh) atomically via one CG transaction
   (`CGBeginDisplayConfiguration` / `CGConfigureDisplayOrigin` /
   `CGCompleteDisplayConfiguration(.forSession)`), then set the two MAG
   wallpaper slots.
5. Fight loop: WallpaperAgent re-applies its memory for a few seconds after a
   reconfiguration, so the script re-reads and re-sets until two consecutive
   clean reads agree.
6. Final verification: geometry, main flag, refresh, wallpaper on every
   display, and that every non-MAG display is byte-for-byte untouched.

## Usage

```
swapDisplays             perform the toggle
swapDisplays --dry-run   show the plan, change nothing
swapDisplays --state     show the current state report only
```

Run as `~/swapDisplays` (symlinked from `~` via the `upd` function in
`~/.zshrc`). Safe to call non-interactively from Apple Shortcuts. A lock file
refuses concurrent runs.

## Compile

```
swiftc -O swapDisplays.swift -o swapDisplays
```

## Exit codes

`0` success · `1` aborted or failed (a human-readable message on stderr says
exactly why; in that case no changes were made — except when noted, the
geometry may already be flipped while wallpaper convergence is still pending,
in which case re-running restores).
