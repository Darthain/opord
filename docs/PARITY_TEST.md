# Parity test: OPORD against ARTIC AI v0.6.8

Purpose: show that the bundled soldier layer and the carried-over defence work behave the same as before.
You run the **same Stage 1 checkpoint tests twice**, on the **same mission and map**: once with the old setup
(baseline) and once with OPORD. Then you compare the results and the RPT logs.

## Mod lists

| | Baseline run | OPORD run |
| --- | --- | --- |
| CBA_A3 | yes | yes |
| ACE3 | yes | yes |
| DCO UnitScanner (Workshop) | yes | yes |
| DCO Soldier FSM (Workshop 2825929474) | **yes** | **no (unloaded)** |
| ARTIC AI v0.6.8 (build of github.com/Darthain/artic-ai) | **yes** | **no (unloaded)** |
| OPORD (this repo, `.hemttout/build`) | no | **yes** |
| GRAD Trenches, POOK Camonets, TerrainLib | same in both runs (load all three) | same in both runs |
| LAMBS Danger, VCOM AI, ARTIC AI v0.3 | no | no |

Rules:
- Everything not listed in the table must be identical in both runs, in the same load order.
- Use a dedicated server for the main comparison; also repeat the local-host and dedicated + headless client
  variants (see "Environments").
- In the baseline, **do not** load OPORD. In the OPORD run, **do not** load the Workshop DCO Soldier FSM or
  ARTIC AI (OPORD warns admins if the Workshop DCO is loaded).

## Mission and settings
1. Use one small mission on one map. Slots: you (admin), Zeus, and for the headless-client variant a headless
   client slot. In the **baseline** the headless client unit must be **named `HC`** (ARTIC AI/DCO require
   it). In the **OPORD** run any name works; keep the same unit so the mission is the same.
2. Set the same CBA settings in both runs. Names differ only by prefix (`ARTIC_x` -> `OPORD_x`, category "ARTIC AI"
   -> "OPORD"). Use defaults, plus **Debug on** and **Test menu (admins) on**. On a dedicated server the
   server's CBA settings apply (Addon Options > Server tab, as admin).
3. For the OPORD run, check "Run Soldier FSM on a headless client" (default on).
4. Start the mission fresh for every run (restart the server between runs).

## Environments
Run the tests in as many of these as you can; label each result row:
- **L**: local host (you host, no dedicated server)
- **D**: dedicated server
- **D+HC**: dedicated server with a headless client

## Tests
Open ACE self-interaction > "ARTIC tests" (baseline) / "OPORD tests" (OPORD run). Run, in this order, waiting for
each result line before the next, and **Clear** between tests:

| ID | Entry |
| --- | --- |
| D1 | Deliberate defence with trenches |
| D1h | Hasty defence |
| D1s | Support by fire |
| D2 | Statics from backpacks (HMG + mortar) |
| D2t | Statics from a truck |
| D2c | ACE CSW statics + ammo crate |
| D3 | Attackers sent at the last test position |
| D8 | Load test, 4 positions (note `#monitor` server FPS before and during) |

Also place a **Battle Position / SBF** module and a **Trench Line / AT Ditch** module by hand once (Eden or
Zeus), synchronised as in the module description, and note whether the group builds and occupies.

## What to compare in the RPT
Collect the RPT from every machine (server, headless client, your client) for each run. Compare these lines.

**1. Test results** (one per test, written by the server):

```
[ARTIC TEST] <label>: READY after <n> s. Statics <n>, GRAD trench pieces <n>, soldiers alive <n>.
[OPORD TEST] <label>: READY after <n> s. Statics <n>, GRAD trench pieces <n>, soldiers alive <n>.
```
Expect the same state (`READY`, or `PARTIAL` if the baseline was `PARTIAL`), the same number of statics, and
the same soldiers alive. Times and trench piece counts vary a little between runs: record them and flag a
difference of more than about 25 %.

**2. OPORD log lines**, `[ARTIC AI][INFO|WARN|ERROR] <message>` in the baseline and `[OPORD][INFO|WARN|ERROR]
<message>` in the OPORD run. The messages are the same text apart from the renamed identifiers.

**3. Script errors.** Search each RPT for `Error` and `Undefined variable`. The OPORD run must show **no
error that the baseline run does not**. (ARTIC's workarounds for the two known DCO bugs stay in OPORD, so the
`allowsuppression` and `_startPos` errors should be absent in both runs.)

**4. Soldier FSM startup lines** (`***soldier FSM * ... ***`). These differ on purpose in the headless-client
cases:

| Situation | Baseline | OPORD |
| --- | --- | --- |
| Server, no headless client | `***soldier FSM * no HC active***`, `***soldier FSM * server loaded***` | `***soldier FSM * running on the server***`, `***soldier FSM * server loaded***` |
| Server, headless client | `***soldier FSM * server exited, headless client used***` | `***soldier FSM * running on headless client (owner N)***`, then `***soldier FSM * server exited, headless client used***` |
| Headless client | `***soldier FSM * Headless Client Loaded***` | `***soldier FSM * Headless Client Loaded***` |

OPORD also prints `***soldier FSM * headless client disconnected, server takes over***` if you disconnect the
headless client during the run (optional test: it should continue on the server).

**5. Admin messages.** Baseline: "A headless client is connected but DCO is not using it ..." appears when the
headless client is not named `HC`. OPORD: "... Soldier FSM is not using it ..." appears only if the headless
client connects late or the setting is off.

### Matching the logs line for line
Map the baseline names to OPORD names, strip time stamps, and diff. In PowerShell (adjust file names):

```powershell
$map = { $_ -replace 'ARTIC AI','OPORD' -replace 'ARTIC TEST','OPORD TEST' -replace 'ARTIC_','OPORD_' -replace '^\s*\d+:\d+:\d+ ','' }
Get-Content baseline.rpt | Where-Object { $_ -match 'ARTIC|soldier FSM|Error' } | ForEach-Object $map > a.txt
Get-Content opord.rpt    | Where-Object { $_ -match 'OPORD|soldier FSM|Error'  } | ForEach-Object { $_ -replace '^\s*\d+:\d+:\d+ ','' } > b.txt
Compare-Object (Get-Content a.txt) (Get-Content b.txt)
```
The `[ARTIC AI]` tag becomes `[OPORD]` (the rename of "ARTIC AI" is "OPORD", so the line `[ARTIC AI][INFO] x` is
`[OPORD][INFO] x`), and `ARTIC_` identifiers in messages become `OPORD_`. Anything else that differs needs a note.

## Also look at (visual checks)
- The squad moves out, assembles and mans statics, digs, puts up nets, and ends in fighting positions facing
  the threat.
- Soldiers fight from behind the parapet, not inside it; no soldier stuck, floating or clipping in trench
  models.
- D3 attackers reach the position and the defenders fight back.
- Zeus: the **Battle Position / SBF** module works when placed on a unit.
- Eden: the Soldier FSM modules (fighting position, activation zone, virtualisation zone) still show their
  attributes.

## Results

Fill one row per test per environment. "Same?" is yes if the RPT result line and the visual checks match the
baseline.

| Env | Test | Baseline result line | OPORD result line | Same? | Errors only in OPORD run | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| D | D1 | | | | | |
| D | D1h | | | | | |
| D | D1s | | | | | |
| D | D2 | | | | | |
| D | D2t | | | | | |
| D | D2c | | | | | |
| D | D3 | | | | | |
| D | D8 | | | | | |
| D | Module: Battle Position | | | | | |
| D | Module: Trench Line | | | | | |
| L | D1 | | | | | |
| L | D2c | | | | | |
| L | D3 | | | | | |
| D+HC | D1 | | | | | |
| D+HC | D2c | | | | | |
| D+HC | D8 | | | | | |
| D+HC | HC disconnect (OPORD only) | n/a | | n/a | | |

Run details to record at the top of your report: date, map, mission name, game version, server FPS, CBA settings
changed, mod versions (CBA, ACE, UnitScanner, GRAD Trenches, POOK Camonets, TerrainLib), and OPORD git commit
(`git rev-parse --short HEAD`).

## Verdict
- **Pass:** every row is "yes" and no error appears only in the OPORD run.
- **Fail:** any row differs in state, statics or soldiers alive beyond the tolerance, or any new error. Attach
  both RPT files and the row's notes, and open an issue.
