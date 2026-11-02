# Source and provenance: soldier and soldier_module

These two addons are a maintained fork of the Workshop mod "DCO Soldier FSM" and bundle it into OPORD.
Licence: BSD-3-Clause (see `LICENSE` in each addon). Existing file headers are unchanged. New files added
here carry "Copyright (C) 2026 OPORD contributors".

| OPORD addon | Original PBO | PBO prefix (kept) | Packed |
| --- | --- | --- | --- |
| `addons/soldier` | `soldierFSM.pbo` | `soldierFSM` | 2025-02-01 |
| `addons/soldier_module` | `fipo_module.pbo` | `fipo_module` | 2024-12-13 |

Origin: Steam Workshop item 2825929474. The PBOs were unpacked unchanged (Mikero ExtractPbo) and then edited. The
repository history starts from the edited state (the unlicensed code removed below is not in any commit), so the
unmodified source is only in the Workshop mod; every change is listed here. The internal PBO prefixes and the CfgPatches class names are kept, so every
existing path resolves unchanged and OPORD replaces the Workshop mod. Do not load both.

## Credits
Yipman, Deebs, Jihem, Tally (Dragon Company). Code: Leo Hartgen (Tally-1), copyright as in the file headers.
Upstream: <https://github.com/Tally-1/soldier-FSM>.


## Temporary external dependency: DCO UnitScanner
Soldier FSM calls eight functions from the Workshop mod "DCO UnitScanner" (`objScan_fnc_*`, 36 call sites; SQF
ignores case). UnitScanner has no licence: it is **not** bundled, copied or read. For now it stays a separate
Workshop mod that the user loads. The startup check "DCO unitScanner not detected" is kept. OPORD will replace it
with its own functions after the parity test (`docs/PLAN.md`, "After parity").

## Removed (no licence)
- PapaReap headless-client code: the `functions/PR` folder, the `SFSM_PR_hc` / `SFSM_PR_main` classes in
  `cfgFunctions.hpp`, the block between `papaReaps code` and `papaReaps code end` in `fn_serverInit.sqf`, the
  `PR_HC1` branch in `fn_groupTasks.sqf`, and `CBA_Options/PapaReap.sqf` (`PR_Allow_HC`, `PR_Use_HC`, `PR_HC1`)
  with its `#include`.
- `functions/misc/fn_setGroupOwner.sqf` (`SFSM_fnc_setGroupOwner`): header names PapaReap as author, no licence;
  never registered in `cfgFunctions.hpp`, so its only caller (the `remoteExec` in `fn_groupTasks`, headless-client
  branch) never ran; what it set (`SFSM_ClientOwner`, `serverUnits`) was read only by other PapaReap code. Group
  ownership is handled by Tally's own `fn_initGroup` and `fn_handleNewGroup`, left as they are. No replacement.

- `soldier_module/functions/` (`fn_slider_onattributeload.sqf`, `fn_slider_onattributesave.sqf`, `configFnc.hpp`):
  headed "Author: R3vo" with no licence notice. Registered only in `configFnc.hpp` as `DMOD_fnc_slider_*`, which
  nothing included, and never referenced anywhere (the module sliders use the vanilla `control = "Slider"`), so
  removal changes no behaviour. The empty `DMOD` class went with it.

## Changes by OPORD
Replacement code (new, BSD-3, OPORD contributors):
- Where Soldier FSM runs: `functions/headlessClient/` (`SFSM_fnc_selectRunner`, `connectedHCs`, `hcWatch`) and
  the rewritten top of `fn_serverInit.sqf`. The first connected headless client runs Soldier FSM, otherwise the
  server; with a headless client, the server only calls `SFSM_fnc_initSettings`. If that headless client
  disconnects the server takes over. Any headless client name works. CBA setting
  `SFSM_runOnHeadlessClient` ("Run Soldier FSM on a headless client", default on) in
  `soldier_module/CBA_Options/HeadlessClient.sqf` replaces `PR_Allow_HC` / `PR_Use_HC`.
- `fn_groupTasks.sqf`: server moves non-local, non-`SFSM_Excluded` groups to itself (`setGroupOwner 2`) as
  before; on a headless client no ownership transfer happens (the old branch never worked). Commented in code.
- Coexistence check `SFSM_fnc_coexistCheck`: RPT warning and a chat message to admins if Workshop 2825929474 is
  also loaded (`getLoadedModsInfo`).

Build compatibility (HEMTT; no intended behaviour change):
- One lowercase function tree: `Functions/` -> `functions/`; `cfgFunctions.hpp` paths and includes corrected to
  the real case (`overrun` -> `overRun`, `Players.sqf`, `dynamicFipo.hpp`, `bis_addoninfo.hpp`).
- `cfgFunctions.hpp`: missing semicolons added.
- 45 lines: a space added between a keyword and a string literal (`joinString""`, `get"x"`, `for"_i"from`).
- `fn_3dDebug.sqf`: `3DmarkersSFSM = true` -> `missionNamespace setVariable ["3DmarkersSFSM", true]`.
- `activationType.hpp`: the nameless `class : Edit { ... }` block (a leftover) is commented out.
- CfgPatches `requiredVersion` raised to 2.18 (the code uses `createHashMap` and 2.10 event handlers).
- Line endings normalised to LF.
- HEMTT packs each addon as `opord_<addon>.pbo`; the `$PBOPREFIX$` file inside keeps the original prefix.

## Known bugs (not fixed in the parity build)
Listed in `docs/PLAN.md`, "After parity".
