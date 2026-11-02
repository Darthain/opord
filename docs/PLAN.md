# OPORD plan

Stub from Phase 1; the full plan is written in Phase 4.

## Planned addon layout
| Addon | Status | Content |
| --- | --- | --- |
| `main` | Phase 3 done | Version, CBA settings, logging, shared helpers, soldier adapter (function tag `OPORD`) |
| `soldier` | Phase 2 done | Fork of DCO `soldierFSM` (PBO prefix `soldierFSM`), BSD-3-Clause |
| `soldier_module` | Phase 2 done | Fork of DCO `fipo_module` (PBO prefix `fipo_module`), BSD-3-Clause |
| `defence` | Phase 3 done | Battle positions, support by fire, statics, trenches |
| `test` | Phase 3 done | Checkpoint test menu |
| `commander` | later | Eden/Zeus commander modules, ORBAT, objectives |
| `infantry` | later | Formations, section drills, platoon attack |
| `vehicles` | later | Core vehicle behaviour |
| `support` | later | Logistics, fires, CAS, drones |
| `intel` | later | Information network |

## Temporary external dependency: DCO UnitScanner
Soldier FSM calls eight functions of the Workshop mod "DCO UnitScanner" (`objScan_fnc_*`: `weaponData`,
`magazineData`, `getAmmoData`, `Decimals`, `VehicleType`, `vehicleData`, `infGearData` and `Fnc_average`, 36 call
sites; SQF ignores case). It has no licence, so it is never bundled, copied or read. For the parity test the user
loads it from the Workshop next to OPORD. The startup check "DCO unitScanner not detected" stays.

## After parity
Known problems, deliberately **not** fixed in the parity build:
- `fn_canFipoSuppress`: reads `allowsuppression` without a default (script error).
- `move.fsm`: reads `FSM_startPos` without a default (script error on scripted moves).
- The 5 later changes in <https://github.com/Tally-1/soldier-FSM> (list to be confirmed from that repo):
  debug bullet-list guards for machines without an interface (fixes an unbounded list on servers/headless
  clients); short-path shortcut in `fn_pathCalculated`; `fn_calculatePath` path-agent deletion (keep deleting,
  guarded with `isNull`).
- Multi-headless-client support: run per owning machine instead of pulling all groups to one. Fold in: decide
  group ownership when Soldier FSM runs on a headless client. Today groups are only moved there at group
  init/creation by `fn_initGroup` / `fn_handleNewGroup`, never re-pulled later (`fn_groupTasks` does no transfer
  on a headless client).
- **Replace UnitScanner with OPORD's own functions.** Inventory every call site case-insensitively; trace every
  hashmap key read from each result (including later lines and through wrappers such as `SFSM_fnc_getAmmoData`);
  find the vehicle-type vocabulary the code compares against (e.g. `SFSM_hijackVehicleTypes`). Show the contracts
  before implementing. Never open or download UnitScanner's source. Re-run the checkpoint tests after the switch.

Items found while building (Phase 2):
- Not tested in game: headless client selection, disconnect take-over, the coexistence warning (the layout of
  `getLoadedModsInfo` was not checked), and the 45 whitespace edits and the `3DmarkersSFSM` change.
- `activationType.hpp` had a nameless `class : Edit` block (commented out); check the Eden module still shows the
  same attributes.
- `fn_3dDebug.sqf` used a variable name starting with a digit; replaced with `setVariable` (same variable).
