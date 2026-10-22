# Andys Preview

A quality-of-life mod for Balatro that previews the score and money of a hand before you play it.

This is a fork of [Fantoms Preview](https://github.com/Fantom-Balatro/Fantoms-Preview) by Fantom and Divvy, based on its v2.5.0 release.

## Changes compared to Fantoms Preview

### Money preview

The original had its money preview disabled in the code. This fork brings it back.

- The money a hand will earn shows on its own line under the score preview.
- It shows a single value like `+$3`, or a `min - max` range when the result depends on chance.
- Gains are coloured gold, losses red, and no change grey.
- The HUD stays the same height. The room comes from trimming empty space around the hand name.
- It can be turned off in the mod settings.

### Faster, on-demand simulation

- The simulation runs only when you click Calculate Score or press `s`.
- Turn the button off with "Show Calculate Score Button" in the Game tab of the settings. That keeps the HUD shorter, so it stays clear of anything other mods draw above the blind box, and `s` still works. With andy-bot-balatro installed the button starts out off, so the HUD stays clear of its streak bar.
- The original re-ran the full simulation on every card selection, reorder, consumable use, and joker sale. Those actions now only hide the outdated preview.
- The 5 second wait after asking for a preview is gone. The result shows immediately.
- A per-discard reset that caused noticeable lag is removed.

### Simulation fixes

- **Matador** now pays out on scoring hands when the boss blind triggered, such as The Arm, The Ox, The Flint, or debuffed scoring cards. It no longer pays out for The Hook or The Tooth.
- **The Hook** now simulates exactly the discards the game makes. Mail-In Rebate, Trading Card, and Green Joker react to those discards, and state no longer leaks between simulated discards.
- **Mail-In Rebate** and **Hit the Road** compared a card field that does not exist, so they never matched. They now check the rank correctly.
- The simulation no longer changes the real blind's triggered flag.
- **Midas Mask** and **Vampire** now remove the old enhancement's bonus chips when they change a card, as the game does. A Bonus Card turned Gold or Base no longer keeps its +30 chips, and a vampired Stone Card no longer scores its 50 chips on top of its rank.
- Debuffed cards no longer count as face cards. Midas Mask skips them, and Photograph and Ride the Bus now match the game.

### Crash safety

- Every entry point runs through an error guard: the simulation, preview texts, HUD setup, the keybind, and the per-frame hooks.
- An error is logged once with an `[AndysPreview]` prefix instead of crashing the game.
- A failed simulation restores the game state and shows an unknown preview.
- If the HUD setup fails, you get the regular game HUD without the preview.

### Project

- Renamed to Andys Preview. The internal mod id is still `FantomsPreview`, so existing settings carry over.
- Releases are automated with a release script and a GitHub Actions workflow.
## Install

1. Install [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector).
2. Download `Andys-Preview.zip` from the [latest release](../../releases/latest).
3. Extract it into your Balatro `Mods` folder.
4. Remove the original Fantoms Preview if you have it. Both mods share the same mod id and cannot run together.

## Releasing

Run the release script from the repo root on a clean, up to date `main`:

```
bash release.sh patch
```

Use `minor`, `major`, or an explicit version like `3.0.0` instead of `patch`. Add `--dry-run` to see the new version without changing anything.

The script bumps `version` in `FantomsPreview.json`, commits, tags, and pushes. The release workflow then builds the zip and publishes the release.
