# OPORD

Open-source AI framework for Arma 3 milsim. It makes AI fight like trained soldiers following real doctrine
(Australian DATE tactics hub, US ATP 3-21.8), scaled by doctrine type and training level. One mod that replaces
NR6 HAL (high command) and LAFS (fire and air support), with a maintained fork of the DCO Soldier FSM soldier
brain bundled in.

**Status: 0.1.0-alpha, foundation.** The bundled soldier layer and the defence work (battle positions, support by
fire, statics, trenches, camo nets) are carried over and awaiting a parity test. Not for live operations. The
plan and stages are in [`docs/PLAN.md`](docs/PLAN.md).

## Requirements
- **Required:** CBA_A3, ACE3, and **DCO UnitScanner** (Workshop). UnitScanner is a temporary requirement: the
  bundled soldier layer calls its functions, and OPORD does not include it. It goes away when OPORD's own
  replacement lands (`docs/PLAN.md`, "After parity").
- **Optional:** GRAD Trenches, POOK Camonets, TerrainLib, IEDD. Each feature falls back cleanly without them.
- **Do not load with OPORD:**
  - Workshop DCO Soldier FSM: OPORD bundles and replaces it. OPORD warns admins at startup if it is loaded.
  - ARTIC AI, any version: OPORD is its successor and the two conflict.
  - LAMBS Danger and VCOM AI: they control individual soldiers, which conflicts with the soldier layer.
    (LAMBS Turrets and LAMBS Suppression are fine.)

## Building
1. Install [HEMTT](https://github.com/BrettMayson/HEMTT) (tested with 1.23.1).
2. From the repository root run `hemtt check`, then `hemtt build` (development) or `hemtt release`.
3. The mod is in `.hemttout/build` (`mod.cpp` and `addons/opord_*.pbo`).
4. Official releases are signed by the maintainers; **never commit private keys**.

Every push is built by CI (`.github/workflows/build.yml`), including the licence-header check
(`python tools/check_headers.py`).

## Running the checkpoint tests
Turn on **Addon Options > OPORD > Testing > Test menu (admins)**. As the host or a logged-in admin open ACE
self-interaction > **OPORD tests** and pick a test. Its setup spawns about 90 m in front of you, facing you, and
the result is reported in chat and the RPT (`[OPORD TEST] ...`). Any small mission works: you, Zeus and, for
headless-client runs, a headless client slot.

| Entry | Checkpoint test |
| --- | --- |
| D1 / D1h / D1s | Deliberate defence with trenches / hasty defence / support by fire |
| D2 / D2t / D2c | Statics from backpacks (HMG + mortar) / from a truck / ACE CSW items + ammo crate |
| D3 | Sends an attacking squad at the most recent test position (from 400 m, in front of it) |
| D8 | Load test: 4 deliberate positions at once (watch `#monitor`) |
| Status / Clear | Running tests / remove test units and earthworks (fighting positions and dug terrain stay until restart) |

To compare OPORD with the ARTIC AI v0.6.8 baseline follow [`docs/PARITY_TEST.md`](docs/PARITY_TEST.md).

## Repository layout
- `addons/main`: version, logging, shared helpers and the soldier adapter
- `addons/soldier`, `addons/soldier_module`: the bundled soldier layer (BSD-3-Clause)
- `addons/defence`, `addons/test`: defence work and the test menu
- `tools/check_headers.py`: licence header check
- `docs/PLAN.md`, `docs/PARITY_TEST.md`; `CREDITS.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `CLAUDE.md`

## Credits and licence
OPORD's own code is **GPL-2.0-only** (`LICENSE`), Copyright (C) 2026 OPORD contributors. The soldier addons are a
fork of the Workshop DCO Soldier FSM and stay **BSD-3-Clause** (`addons/soldier/LICENSE`; provenance and changes in
`addons/soldier/SOURCE.md`). Credits: [`CREDITS.md`](CREDITS.md). Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md).
