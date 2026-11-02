# OPORD plan

The single place to look for where the project stands.

## Aim and scope
OPORD is an open-source (GPL-2.0-only) AI framework for Arma 3 milsim. It makes AI fight like trained soldiers
following real doctrine (Australian DATE tactics hub, US ATP 3-21.8), scaled by doctrine type and training
level. It is one mod that replaces NR6 HAL (high command) and LAFS (fire and air support), with a maintained
fork of DCO Soldier FSM as the soldier brain. It is public from the start.

Layers, bottom to top:
1. **Soldier**: fork of DCO Soldier FSM (BSD-3-Clause): cover, suppression, fighting positions, CQB, healing, morale.
2. **Section**: formations and drills, skewed by training level.
3. **Platoon**: attack schemes, plan lifecycle with H-hour, contact-aware replanning, in-combat coordination.
4. **Defence and engineering**: battle positions, support by fire, statics (incl. ACE crew-served), trenches,
   camo nets, AI-placed minefields and IEDs.
5. **Commander**: Eden/Zeus commander modules, ORBAT, area of operations, sites and objectives.
6. **Vehicles**: core, not optional: mechanised infantry, transport, vehicle tactics.
7. **Support**: logistics (repair, resupply, refuel, transport, QRF, reinforcements), fires, CAS and drones.
8. **Information network**: radio-based contact sharing, situation picture, fire deconfliction.

## Sources
| Source | Use |
| --- | --- |
| ARTIC AI v0.6.8 (artic-ai repo) | Foundation, DCO adapter, defence, test menu: carried over in this session |
| ARTIC AI v0.3.30.2 (archived) | Commander modules, ORBAT, objectives, platoon attack, contact sharing: ported in later stages |
| DCO Soldier FSM (Workshop 2825929474) | Soldier layer, forked (BSD-3) |
| Squad FSM (github.com/Tally-1/Squad-FSM, BSD-3) | Parts for transport, reinforcements, artillery/AT requests, resupply: support stage |
| Tally's Vehicle FSM | Behaviour reference only: no licence, no code may be used |

## Addon layout
| Addon | Status | Content |
| --- | --- | --- |
| `main` | done (0.1.0) | Version, CBA settings, logging, shared helpers, soldier adapter (function tag `OPORD`) |
| `soldier` | done (parity) | Fork of DCO `soldierFSM` (PBO prefix `soldierFSM`), BSD-3-Clause |
| `soldier_module` | done (parity) | Fork of DCO `fipo_module` (PBO prefix `fipo_module`), BSD-3-Clause |
| `defence` | done (parity) | Battle positions, support by fire, statics, trenches |
| `test` | done (parity) | Checkpoint test menu |
| `commander` | later | Eden/Zeus commander modules, ORBAT, objectives |
| `infantry` | later | Formations, section drills, platoon attack |
| `vehicles` | later | Core vehicle behaviour |
| `support` | later | Logistics, fires, CAS, drones |
| `intel` | later | Information network |

## Decisions so far
Phase 2 (soldier layer) and Phase 3 (foundation):
- **DCO UnitScanner is a temporary external Workshop dependency.** Soldier FSM calls 8 of its functions
  (`objScan_fnc_*`: `weaponData`, `magazineData`, `getAmmoData`, `Decimals`, `VehicleType`, `vehicleData`,
  `infGearData`, `Fnc_average`) at 36 call sites; SQF ignores case. It has no licence, so it is never bundled,
  copied or read; the user loads it from the Workshop. The "DCO unitScanner not detected" startup check stays.
  The 8 functions / 36 call sites get replaced after parity (see "After parity").
- **PapaReap code removed (no licence) and replaced.** The `functions/PR` folder, its `cfgFunctions` classes, the
  `PR_*` CBA settings, the `serverInit` block and the `fn_groupTasks` branch are gone. New code (BSD-3, OPORD
  contributors) selects the machine: Soldier FSM runs on the first connected headless client if there is one,
  otherwise on the server; if that headless client disconnects the server takes over. One CBA setting, "Run
  Soldier FSM on a headless client" (`SFSM_runOnHeadlessClient`, default on). Any headless client name works.
- **Group ownership on a headless client:** `fn_setGroupOwner.sqf` (PapaReap, never registered, its only caller
  never ran) was deleted with no replacement. `fn_groupTasks` no longer transfers on a headless client (the old
  branch never worked); on the server it still pulls non-local, non-`SFSM_Excluded` groups to itself. Groups only
  move to a headless client at creation (`fn_initGroup` / `fn_handleNewGroup`, Tally's code, untouched). The
  decision on ownership is deferred to the multi-headless-client work.
- **R3vo's two slider helpers removed** (`fn_slider_onattributeload/save.sqf` and the unused `configFnc.hpp`):
  no licence notice and never referenced; the module sliders use the vanilla `control = "Slider"`.
- **Build compatibility edits** to the soldier source (semicolons, whitespace around string literals, a
  nameless config block commented out, `requiredVersion` 2.18): listed in `addons/soldier/SOURCE.md`.
- **ARTIC AI renamed to OPORD** (`ARTIC_` -> `OPORD_`, "ARTIC AI" -> "OPORD"); every renamed public name is in
  `CHANGELOG.md`. The ARTIC checks that read `PR_HC1` / `PR_HeadlessClients` now use `OPORD_fnc_soldierHost`.
- The ARTIC workarounds for the two DCO bugs are kept for parity (`OPORD_fnc_dcoGuard`, `OPORD_fnc_lockPosture`).
- LAMBS Danger and VCOM AI remain unsupported alongside OPORD.

## Stage order
Each stage ends with checkpoint tests in the test menu.

| # | Stage | Status |
| --- | --- | --- |
| 1 | Foundation | Built and committed (0.1.0-alpha). Builds with HEMTT; **not yet run in game** |
| 2 | Soldier: parity run, then the "After parity" fixes | Parity test written (`docs/PARITY_TEST.md`), not yet run |
| 3 | Commander: port the v0.3 Eden/Zeus commander modules, ORBAT, objectives, information network | Not started |
| 4 | Defence under the commander (the commander orders defence instead of the test menu) | Not started |
| 5 | Infantry attack: formations, section drills, platoon attack | Not started |
| 6 | Vehicles | Not started |
| 7 | Support: logistics, fires, CAS and drones | Not started |
| 8 | Depth: doctrine and training profiles, urban, morale; then 1.0 | Not started |

## Next steps
1. **Parity test.** Run the Stage 1 defence checkpoint tests with OPORD loaded and the Workshop DCO and ARTIC AI
   unloaded, and compare with the ARTIC AI v0.6.8 baseline. Procedure and results table: `docs/PARITY_TEST.md`.
2. **After parity** (below).

## After parity
Known problems, deliberately **not** fixed in the parity build:
- `fn_canFipoSuppress`: reads `allowsuppression` without a default (script error).
- `move.fsm`: reads `FSM_startPos` without a default (script error on scripted moves).
- The 5 later changes in <https://github.com/Tally-1/soldier-FSM> (list to be confirmed from that repo): debug
  bullet-list guards for machines without an interface (fixes an unbounded list on servers/headless clients);
  short-path shortcut in `fn_pathCalculated`; `fn_calculatePath` path-agent deletion (keep deleting, guarded with
  `isNull`).
- **Replace UnitScanner with OPORD's own functions** (8 functions, 36 call sites). Inventory every call site
  case-insensitively; trace every hashmap key read from each result (including later lines and through wrappers
  such as `SFSM_fnc_getAmmoData`); find the vehicle-type vocabulary the code compares against (e.g.
  `SFSM_hijackVehicleTypes`). Show the contracts before implementing. Never open or download UnitScanner's
  source. Re-run the checkpoint tests after the switch. Then drop the requirement from the README.
- **Remove OPORD's workarounds for the two DCO bugs** (`OPORD_fnc_dcoGuard`, `OPORD_fnc_lockPosture`) once the
  bugs are fixed in the soldier layer.
- **Headless-client ownership and multi-headless-client support:** run per owning machine instead of pulling all
  groups to one; decide group ownership when Soldier FSM runs on a headless client (today groups only move there
  at group init/creation, never re-pulled later).

Found while building, still open:
- Not tested in game: machine selection and disconnect take-over, the coexistence warning (the layout of
  `getLoadedModsInfo` was not checked), the 45 whitespace edits and the `3DmarkersSFSM` change.
- `activationType.hpp` had a nameless `class : Edit` block (commented out): check the Eden module still shows
  the same attributes.
- User-visible strings carried over from ARTIC still say "DCO" (CBA setting and module descriptions): reword when
  the soldier layer is renamed in the UI.
