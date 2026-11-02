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
| ARTIC AI v0.3.30.2 (archived) | Commander modules, ORBAT, objectives, platoon attack, contact sharing: ported in later stages. Kept unchanged on the branch `legacy/artic-ai-v0.3` (tag `artic-ai-v0.3.30.2`); see "Port map" |
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
- **Legacy source kept, not built:** v0.3.30.2 lives on `legacy/artic-ai-v0.3`, never merged into `main`. In-combat
  coordination is specified in `docs/specs/in-combat-coordination.md` (to be re-based before implementation).
- **ARTIC AI renamed to OPORD** (`ARTIC_` -> `OPORD_`, "ARTIC AI" -> "OPORD"); every renamed public name is in
  `CHANGELOG.md`. The ARTIC checks that read `PR_HC1` / `PR_HeadlessClients` now use `OPORD_fnc_soldierHost`.
- The ARTIC workarounds for the two DCO bugs are kept for parity (`OPORD_fnc_dcoGuard`, `OPORD_fnc_lockPosture`).
- LAMBS Danger and VCOM AI remain unsupported alongside OPORD.

## Port map (ARTIC AI v0.3.30.2 -> OPORD)
The v0.3.30.2 source is kept unchanged on the branch `legacy/artic-ai-v0.3` (tag `artic-ai-v0.3.30.2`). It is
never merged into `main` and never built. Later stages read it there and port it into OPORD's addons under OPORD
names (`ARTIC_` -> `OPORD_`). Paths below are under `source/artic_ai_core/`; function names omit `fn_`.

Rules for every port:
- v0.6.8 code already carried over wins wherever the two overlap (see "Overlaps").
- The v0.3 individual layer is dropped: the bundled soldier layer (DCO fork) handles individual behaviour. Code
  that called it (listed under "Does not fit") must be re-based on the soldier adapter (`OPORD_fnc_unitFree`).
- Each stage ends with checkpoint tests; the v0.3 benchmarks (`docs/BENCHMARKS.md` on the legacy branch) are
  the starting point for them.

| v0.3.30.2 area | Functions | OPORD addon | Stage | Notes |
| --- | --- | --- | --- | --- |
| `functions/core` | `getDoctrine`, `getTraining`, `initDoctrineLibrary` | `main` | 3 (used), 8 (full depth) | Doctrine and training profiles; the library is first read by the commander |
| | `getSyncedByClass`, `sideFromIndex`, `clearGroupWaypoints`, `isCombatEffectiveTarget` | `main` | 3 | Shared helpers |
| | `debug` | `main` | done | Overlap: `OPORD_fnc_log` is kept |
| | `preInit`, `postInit` | the addon that owns each part | with each stage | Settings and event registration are split per addon, as in v0.6.8 |
| `functions/capabilities` | `scanGroupCapabilities` | `main` | 3 | Group role scan used by ORBAT, sections and support |
| | `applyRoleOverrides` | `commander` | 3 | Backs the Role Override module |
| | `scanVehicleCapabilities` | `vehicles` | 6 | Artillery, ammo and fuel roles; also read by support (7) |
| `functions/commander` | `commanderStep`, `serverManager`, `updateCommanderIntel`, `classifyBattlefields`, `assignObjective`, `evaluateObjective`, `refreshSiteControl`, `drawCommanderDebug` | `commander` | 3 | `updateCommanderIntel` is also the base of the information network (`intel`, 3) |
| | `considerUAS` | `support` | 7 | Commander hook into drones |
| `functions/modules` | `moduleCore`, `moduleCommander`, `moduleFormation`, `moduleAO`, `moduleFrontline`, `moduleObjective`, `moduleReserve`, `moduleSite`, `moduleRoleOverride` | `commander` | 3 | Eden/Zeus modules; `config.cpp` module classes go with them |
| | `moduleSupport` | `support` | 7 | Sync support assets; registered by the commander (3) |
| `functions/orbat` | `rebuildORBAT`, `getFormationGroups`, `buildFormationNode` | `commander` | 3 | ORBAT |
| | `applyFormationProfile`, `assignFormationIntent` | `infantry` | 5 | |
| | `assessBattlefield`, `buildBattleContext`, `getBattleEnvelope`, `findBattleControlPoint`, `battleSight`, `generateBattleCOAs`, `selectAttackScheme`, `planSectionRoute`, `platoonMovementStep`, `assessSectionContact`, `platoonContactResponse`, `findWithdrawalLanes` | `infantry` | 5 | Platoon attack, plan lifecycle, contact-aware replanning |
| | `evaluateSbfFireLine`, `findSupportArc` | `infantry` | 5 | Support-by-fire for the attack (FIX section). Overlap with v0.6.8 SBF siting: v0.6.8 is kept for defence |
| | `buildDefenceContext` | `defence` | 4 | Defence under the commander; overlap with `planLayout`, see "Overlaps" |
| `functions/formation` | all 8 (`getFormationTemplate`, `selectFormation`, `assignFormationSlots`, `formationSlotWorld`, `fireteamSlotWorld`, `sectionFormationStep`, `setSectionDestination`, `assertMovementControl`) | `infantry` | 5 | Formations and drills; see `docs/reference/FORMATIONS.md` |
| `functions/tactics` | `executePlatoonManoeuvre`, `executeFixingAction`, `executeBlockingAction`, `executeSuppressAndFlank`, `executeFightingWithdrawal`, `chooseFlankPlan`, `assignElements`, `assessAttackSupport`, `findSupportPosition`, `moveSectionTactical`, `moveFireteamTactical`, `suppressElement`, `finishPlan`, `endPlayQuietly`, `isPlayStale`, `isSectionPlayActive`, `markDeployProgress` | `infantry` | 5 | Section plays |
| | `findCoverPosition`, `findThreatRelativeCover`, `coverScore`, `assessExposure`, `hasLineOfSight` | `infantry` | 5 | Section-level position choice only; individual cover is the soldier layer's |
| | `executePrepareBattlePosition`, `executeDefendBattlePosition` | `defence` | 4 | Rewritten as the commander's order into `OPORD_fnc_prepareBattlePosition`; v0.6.8 builds the position |
| `functions/combat` | `buildFireLine`, `assignFirePositions`, `sectionReactFire`, `fireHE` | `infantry` | 5 | Section fire control. Partial overlap with fighting positions (see "Overlaps") |
| `functions/engineering` | `registerObstacle`, `createIED`, `detonateIED` | `defence` | 4 | Obstacle registry, IED (optional IEDD); no v0.6.8 equivalent. Minefields are new work in this stage |
| | `chooseBattlePositionLayout`, `createConcealment`, `createFightingPosition`, `getCamoPattern` | none | n/a | Dropped: v0.6.8 is kept (see "Overlaps") |
| `functions/planner` | `setGroupOrder`, `clearGroupOrder` | `commander` | 3 | Commander-to-group order interface |
| | `localPlanner`, `groupStep` | `infantry` | 5 | Per-group executor; the individual parts of `groupStep` are re-based on the soldier adapter |
| | `reportContact`, `findTarget` | `intel` | 3 | Contact reports; see `docs/specs/in-combat-coordination.md` |
| | `getProfile` | `main` | 3 | Doctrine and training lookup |
| `functions/individual` | `individualStep`, `processIndividualAI`, `setUnitTask`, `clearUnitTask` | none | n/a | **Dropped (DCO handles it)**: the individual layer |
| | `getMovementProfile` | `infantry` | 5 | Terrain cohesion leash for formations, not individual behaviour |
| | `initFireteams` | `infantry` | 5 | Stable fireteam membership |
| | `isFit` | `main` | 5 | Fitness check (alive, not incapacitated or ACE-unconscious, on foot) |
| `functions/fsm` + `fsm/*.fsm` | `startCommanderFSM`, `commanderFSMCondition`, `commanderFSMEnterState`, `ARTIC_Commander.fsm` | `commander` | 3 | |
| | `registerFSMEvents` | `main` | 3 | Shared FSM event plumbing |
| | `startPlatoonFSM`, `startPlatoonCBAStateMachine`, `platoonFSM*`, `platoonRuntime*`, `createPlatoonPlan`, `applyPlatoonPlan`, `getPlatoonPlan`, `getPlatoonLogicList`, `supersedePlatoonPlan`, `tryIssuePlatoonHHour`, `recordPlatoonFailure`, `classifyPlanFailure`, `findFormationNode`, `ARTIC_Platoon.fsm` | `infantry` | 5 | Plan lifecycle with H-hour |
| | `startSectionFSM`, `sectionFSM*`, `abortSectionTask`, `setSectionTaskState`, `signalSectionFailure`, `signalSectionReady`, `startFireteamFSM`, `fireteamFSM*`, `fireteamTaskGet`, `makeFireteamTask`, `setFireteamTask`, `validateFireteamTask`, `getFireteamMembers`, `ARTIC_Section.fsm`, `ARTIC_Fireteam.fsm` | `infantry` | 5 | |
| `functions/support` | `requestSupport`, `processSupportRequests`, `executeFireMission`, `localArtilleryFire`, `supportDiagnostic` | `support` | 7 | Fires; Squad FSM (BSD-3) has parts for artillery/AT requests |
| `functions/uas` | `requestUAS`, `processUASRequests`, `findUASProvider`, `executeReconUAS`, `executeFPVStrike`, `consumeUASItem`, `getCrocusClass`, `scanUnitUASCapabilities` | `support` | 7 | Drones; the Crocus integration stays runtime-only |
| | `reportUASContacts` | `intel` | 3 | Feeds the shared picture (hook into `support` at 7) |
| `config.cpp` | module classes, faction category | the addon of each module | with each stage | `ARTIC_Module_*` -> `OPORD_Module_*` |
| `docs/` (legacy branch) | doctrine references | `docs/reference/` | done | `ATP_3-21.8_NOTES`, `BATTLEBOOK_DRILLS`, `DOCTRINE_MATRIX`, `FORMATIONS` copied. Patch specs, changelogs and build notes stay on the legacy branch |

### Overlaps between v0.3.30.2 and the carried-over v0.6.8 code
v0.6.8 is kept in every case.
1. **Battle position layout:** v0.3 `engineering/chooseBattlePositionLayout` (25 lines) against v0.6.8
   `defence/planLayout` (+ `refinePos`, `safeSnap`, `orientAlong`). Dropped.
2. **Battle position preparation:** v0.3 `tactics/executePrepareBattlePosition` and `executeDefendBattlePosition`
   against v0.6.8 `defence/prepareBattlePosition` and `moduleBattlePosition`. v0.3 is only the order hook.
3. **Fighting positions:** v0.3 `engineering/createFightingPosition` (a sandbag or GRAD object) against v0.6.8
   `main/createFipo`, `defence/trenchFipo` (DCO fighting positions, plus the GRAD parapet logic). Dropped.
4. **Concealment:** v0.3 `engineering/createConcealment` against v0.6.8 `defence/conceal`. Dropped.
5. **Camouflage pattern:** v0.3 `engineering/getCamoPattern` against v0.6.8 `main/getCamoPattern` (same job,
   same POOK variants). Dropped.
6. **Defence context and SBF siting:** v0.3 `orbat/buildDefenceContext` (threat axis and frontage for DEFEND) and
   `orbat/evaluateSbfFireLine`, `findSupportArc` against v0.6.8 `planLayout` (defence arc and the SBF line sited
   for line of sight). Defence keeps v0.6.8; the SBF functions are ported only for the attack's FIX section.
7. **Section fire positions:** v0.3 `combat/assignFirePositions`, `buildFireLine` pick positions for a section's
   shooters, which partly overlaps fighting-position placement. They stay for contact lines and FIX; v0.6.8 and
   the soldier layer's fighting positions own defence.
8. **Debug and logging:** v0.3 `core/debug` against v0.6.8 `main/log`. Dropped.
9. **Trenches:** v0.3 has only placement of single objects, no trench lines; v0.6.8 trench building has no
   v0.3 counterpart.

### Does not fit the map
- **Callers of the dropped individual layer** must be re-based, not copied: `combat/buildFireLine`,
  `sectionReactFire`, `formation/assertMovementControl`, `sectionFormationStep`, `setSectionDestination`,
  `planner/groupStep`, `localPlanner`, `tactics/endPlayQuietly`, `executeBlockingAction`,
  `executeFightingWithdrawal`, `executeFixingAction`, `executePlatoonManoeuvre`, `executeSuppressAndFlank`,
  `finishPlan`, `moveFireteamTactical`, `moveSectionTactical`, `suppressElement`. They set unit tasks and read
  `ARTIC_reactionState`; OPORD orders soldiers only through the soldier adapter.
- **`docs/specs/in-combat-coordination.md`** reads ARTIC's individual reaction state for the section combat
  state; the banner on that spec says to re-base it.
- **Vehicles (stage 6)** are mostly new work: v0.3 has no vehicle tactics, only `scanVehicleCapabilities`.
- **Information network (`intel`)** radio behaviour is new work: v0.3 has contact calls, the commander intel
  loop and UAS contact reports only.
- **Morale** is "reserved" in v0.3 and not implemented; it comes from the soldier layer.
- **Doctrine and training** exist only as a profile library in v0.3 (`initDoctrineLibrary`); applying them is stage 8.

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
