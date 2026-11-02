# Credits

OPORD's own code is licensed under the **GNU General Public License v2.0 only** (see `LICENSE`).
Copyright (C) 2026 OPORD contributors.

## Code adapted into OPORD

Files containing adapted code keep the original copyright notice in their header.

| Source | Licence | Adapted into | Notes |
| --- | --- | --- | --- |
| ARTIC AI v0.6.8 (OPORD contributors' own earlier work) | GPL-2.0-only | `main`, `defence`, `test` (Phase 3) | Foundation, defence, test menu |
| DCO Soldier FSM (Yipman, Deebs, Jihem, Tally; Dragon Company; code by Leo Hartgen / Tally-1) | BSD-3-Clause | `soldier`, `soldier_module` | Forked and bundled; see `addons/soldier/SOURCE.md` |

## Mods OPORD works with (called at runtime, no code copied)

| Mod | Licence | Used for |
| --- | --- | --- |
| CBA_A3 | GPLv2 | Events, settings, per-frame handlers |
| ACE3 | GPLv2 | Crew-served weapons, interaction |
| Gruppe Adler Trenches | (see its repository) | Trench earthworks |
| POOK Camonets | (see its Workshop page) | Camouflage nets |
| TerrainLib (Seb105) | GPLv2 | Terrain trenches and ditches |
| DCO UnitScanner | none (not bundled) | Weapon, magazine, ammo and vehicle data for the soldier layer (temporary external dependency) |
| IEDD Notebook (Prisoner) | AGPL-3.0 | IED devices (optional, planned) |
