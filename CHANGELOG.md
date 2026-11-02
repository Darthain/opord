# Changelog

## 0.1.0-alpha (unreleased)
- Repository skeleton: HEMTT project, `main` addon, CI.
- Soldier layer: bundled fork of Workshop DCO Soldier FSM (`soldier`, `soldier_module`), BSD-3-Clause, at parity.
  Replaces the Workshop mod; do not load both.
- Soldier layer: PapaReap headless-client code removed (no licence) and replaced: Soldier FSM runs on the first
  connected headless client, otherwise the server. CBA setting `SFSM_runOnHeadlessClient` replaces `PR_Allow_HC`,
  `PR_Use_HC` and `PR_HC1`.
- Warning at startup if the Workshop Soldier FSM is also loaded.
- DCO UnitScanner is still required as a separate mod (temporary).

### Foundation carried over from ARTIC AI v0.6.8 (rename, breaks existing missions)
`main` (core + soldier adapter), `defence` and `test` come from ARTIC AI v0.6.8. Everything named ARTIC is now
OPORD. **Missions built for ARTIC AI will not work unchanged**: the modules, settings and variables below were
renamed. Behaviour is otherwise identical, except the headless-client checks (see "Adapted").

Mod, addons and text:
- Mod "ARTIC AI" -> "OPORD"; addons `artic_ai_core` -> `opord_main`, `opord_defence`, `opord_test`; PBO prefix
  `zrtic_aiddons\core` -> `z\opordddons\<addon>`.
- Log tag `[ARTIC AI]` -> `[OPORD]`; chat prefixes `ARTIC:` / `ARTIC AI:` -> `OPORD:`; test output `[ARTIC TEST]` ->
  `[OPORD TEST]`; ACE self-interaction "ARTIC tests" -> "OPORD tests"; CBA settings category "ARTIC AI" -> "OPORD".

Module classes (Eden / Zeus) and faction category:
- `ARTIC_Module_BattlePosition` -> `OPORD_Module_BattlePosition`
- `ARTIC_Module_TrenchLine` -> `OPORD_Module_TrenchLine`
- `ARTIC_Modules` -> `OPORD_Modules`

CBA settings (variable names; saved values are lost):
- `ARTIC_bpTimeout` -> `OPORD_bpTimeout`
- `ARTIC_buildTimeScale` -> `OPORD_buildTimeScale`
- `ARTIC_debug` -> `OPORD_debug`
- `ARTIC_digSafeRadius` -> `OPORD_digSafeRadius`
- `ARTIC_sandbags` -> `OPORD_sandbags`
- `ARTIC_snapIntoPosition` -> `OPORD_snapIntoPosition`
- `ARTIC_staticAmmoCount` -> `OPORD_staticAmmoCount`
- `ARTIC_staticDefaultAmmo` -> `OPORD_staticDefaultAmmo`
- `ARTIC_staticRadius` -> `OPORD_staticRadius`
- `ARTIC_terrainBudget` -> `OPORD_terrainBudget`
- `ARTIC_testMenu` -> `OPORD_testMenu`
- `ARTIC_trenchDepth` -> `OPORD_trenchDepth`
- `ARTIC_trenchFipoMax` -> `OPORD_trenchFipoMax`
- `ARTIC_trenchFipoSpacing` -> `OPORD_trenchFipoSpacing`
- `ARTIC_trenchFipos` -> `OPORD_trenchFipos`
- `ARTIC_trenchRotationOffset` -> `OPORD_trenchRotationOffset`
- `ARTIC_trenchTimePer10m` -> `OPORD_trenchTimePer10m`

CBA events: `ARTIC_adminMessage`, `ARTIC_battlePositionReady`, `ARTIC_buildTrench`, `ARTIC_prepareBP`, `ARTIC_registerFipo`, `ARTIC_test` -> same names with `OPORD_`.

Public variables (mission, group, unit and object variables): `ARTIC_ammoCache`, `ARTIC_bpState`, `ARTIC_bp_*`, `ARTIC_bpStatics`, `ARTIC_camoPattern`, `ARTIC_claimed`, `ARTIC_controlled`, `ARTIC_cswAmmoCache`, `ARTIC_dco_*`, `ARTIC_dco_pinned_down`, `ARTIC_fipo`, `ARTIC_engineeringObject`, `ARTIC_ownerGroup`, `ARTIC_ownerSide`, `ARTIC_pinnedTimes`, `ARTIC_segLenCache`, `ARTIC_staticCache`, `ARTIC_terrainUsed`, `ARTIC_testGroup`, `ARTIC_testObject`, `ARTIC_testRuns`, `ARTIC_test_*`, `ARTIC_tests`, `ARTIC_tfCount_*`, `ARTIC_tlDone_*`, `ARTIC_trenchCounter`, `ARTIC_trenchLineDone`, `ARTIC_trenchLines`, `ARTIC_trenchMethodOverride` -> same names with `OPORD_`.

Functions (`ARTIC_fnc_<name>` -> `OPORD_fnc_<name>`): `assembleStatic`, `buildTrenchLine`, `conceal`, `conflictCheck`, `createFipo`, `createTrench`, `dcoGuard`, `debugMarkers`, `dropStaticAmmo`, `earthworkClear`, `eventBridge`, `findAmmoSource`, `findStaticKits`, `getCamoPattern`, `groupPinned`, `groupUnderFire`, `hasDco`, `hcCheck`, `isDcoHost`, `lockPosture`, `log`, `moduleBattlePosition`, `moduleTrenchLine`, `moveViaTrench`, `orientAlong`, `placeSandbags`, `planLayout`, `prepareBattlePosition`, `refinePos`, `registerFipo`, `safeSnap`, `segmentLength`, `setTrenchProgress`, `staticAmmoClasses`, `staticKitInfo`, `takeStaticAmmo`, `terrainDigSegment`, `testBattlePosition`, `testMenu`, `testReport`, `testRun`, `testTrenchMove`, `trenchFipo`, `trenchMethod`, `unitFree`.

Adapted (not identical):
- The ARTIC checks that read the removed PapaReap variables `PR_HC1` / `PR_HeadlessClients` now use the new
  `OPORD_fnc_soldierHost` (owner ID of the machine running Soldier FSM, from `SFSM_runnerOwner`):
  `OPORD_fnc_isDcoHost`, `OPORD_fnc_hcCheck` (now warns when a headless client is connected but Soldier FSM is not
  using it), and the ownership wait in `OPORD_fnc_moduleBattlePosition` and `OPORD_fnc_testRun`.
- Settings are registered by the addon they belong to (`main`: debug; `defence`: the rest; `test`: test menu).
- Requirements: CBA, ACE. Optional: GRAD Trenches, POOK Camonets, TerrainLib, IEDD. DCO Soldier FSM is no longer a
  requirement (bundled). LAMBS Danger and VCOM AI remain unsupported alongside OPORD.
- The two DCO workarounds (`OPORD_fnc_dcoGuard`, `OPORD_fnc_lockPosture`) are kept for parity and removed after it.
