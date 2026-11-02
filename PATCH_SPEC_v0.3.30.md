# ARTIC AI v0.3.30-alpha — Plan lifecycle, platoon-owned readiness, contact-aware replanning

## Purpose

v0.3.29 proved that one platoon plan can keep its identity (plan IDs, frozen roles, one H-hour). The
Air Station run (Stratis, 16 min, no script errors) then showed what goes wrong *around* that plan:
six plans in about nine minutes, 57 section failures, no assault, and Alpha 1-2 reduced to one man.
The failures were mostly the plan's own machinery, not the enemy:

| 0.3.29 finding | Evidence in the RPT | v0.3.30 fix |
|---|---|---|
| Failed gates did not stop the manoeuvre script | duplicate `H-HOUR RECEIVED`, superseded plan P2 executed after P3 existed, movement before H-hour | gates exit at script level; plays end quietly when stale; plays tracked by script handle |
| Fixed stage timeouts | 23 × `MANOEUVRE_ROUTE_FAILED`, the first with no contact (75–80 s for 150–290 m legs) | distance-scaled, progress-aware movement legs |
| Each manoeuvre section ran its own BLOCK/FIX clock | 6 × `BLOCK_NOT_READY` (BLOCK given 18 s), 19 × `FIX_SUPPRESSION_TIMEOUT` | the platoon READY_CHECK owns readiness and fails it only when deployment stops progressing |
| FIX ended when its first target died | P4: open fire 5:49:12, complete 5:49:13; the only plan with a real SBF superseded | sustained fire: next target or area fire until the manoeuvre assaults |
| Replanning ignored where sections were | P2 routed Alpha 1-2 from the objective edge back round a 10-gate route in a platoon column; enemy met at 67 m and 6 m | contact-aware replanning: engaged/close sections are committed in place, best placed one fixes |
| Contact reporting gated by plays (0.3.28 item) | sections mid-play never called contacts | contact detection runs for every section |
| BLOCK had no firing positions (0.3.28 item) | ready on arrival within 35 m, RED, no orientation | new BLOCK play: fire line facing objective and withdrawal lanes |

## 1. Play lifecycle

### 1.1 Script-level exits (`fn_executePlatoonManoeuvre`)

In SQF, `exitWith` leaves only the scope it is in. Inside `if (...) then { ... }` it leaves the `then`
block, not the script. 0.3.27–0.3.29 had the FIX gate, the BLOCK gate and the H-hour gate written that
way, so after reporting a failure and calling `finishPlan` the script continued to READY, waited for
H-hour and moved — while `groupStep` (seeing `ARTIC_currentPlan` cleared) started a second copy.

Every gate now records its outcome (`_gateFail`, `_syncFail`) inside its block and the script exits at
top level. All remaining indented `exitWith` uses in the plays are inside `waitUntil` conditions or helper
functions, where leaving the local scope is the intent.

### 1.2 Play identity and staleness (`ARTIC_fnc_isPlayStale`)

Every FIX, BLOCK and manoeuvre play captures `[planId, taskId]` at start and checks inside every wait:

- group no longer local;
- `ARTIC_sectionTaskId` changed (new PlatoonPlan);
- `ARTIC_planAbortId == planId` (the platoon aborted this plan);
- the play started armed and `ARTIC_tacticalExecutionArmed` was withdrawn.

A stale play ends **quietly**: no failure report, `finishPlan`, log `play ended: plan … no longer current`
/ `ended quietly (…)`. `ARTIC_fnc_moveSectionTactical` takes the identity as an optional 7th argument and
returns at once (`ARTIC_lastMoveResult = ABORTED`).

### 1.3 Play tracking (`fn_groupStep`)

Plays are started through `_startPlay`, which stores the script handle in `ARTIC_playHandle`. A section
counts as playing while that handle is running **or** `ARTIC_currentPlan` is set. No second play can
start while the first script is alive, whatever `currentPlan` says.

### 1.4 Plan abort (`ARTIC_fnc_recordPlatoonFailure`)

The first failure of a plan (section-reported via `ARTIC_sectionFailed`, READY_CHECK timeout, or contact
on deployment) is classified, stored, and publishes `ARTIC_planAbortId = planId` on every section of the
platoon. All plays of that plan end within about a second, so `FAILURE_SETTLED` (no section play active)
is reached immediately instead of after the slowest play times out. Log: `FSM PLAN ABORT plan=… reason=… class=…`.

Supersession uses the **root cause** (`abortReason`, the first failure), not whichever consequence was
reported last.

FIX and BLOCK now report their own failures to the platoon (`ARTIC_fnc_signalSectionFailure`); in 0.3.29
FIX failures reached the FSM only through the group-variable fallback.

### 1.5 Phase latches

`fn_createPlatoonPlan` resets `ARTIC_manoeuvrePhase`, `ARTIC_fixState/fixReady`,
`ARTIC_blockState/blockReady`, `ARTIC_planAbortId` and `ARTIC_blockDoneTaskId` for every section. A stale
partner phase of `ABORT` from the previous plan could otherwise fail the next plan's synchronisation.

FIX and BLOCK record `ARTIC_fixDoneTaskId` / `ARTIC_blockDoneTaskId` when they finish; `groupStep` does not
restart a finished FIX/BLOCK task under the same task ID (a FIX restart during the assault would put
fire back on the objective).

## 2. Movement legs (`fn_moveSectionTactical`)

The timeout argument is now a minimum:

```text
deadline  = max(timeout, clamp(25 + distance / ARTIC_moveTimeoutPace, 30, 420))   pace = 1.1 m/s
extension = +12 s whenever the guide closes by 4 m near the deadline, up to 1.6 x deadline
early fail = NO_PROGRESS when the guide has not closed by 4 m for ARTIC_moveNoProgressSeconds (40 s)
arrival   = guide inside tolerance for 15 s with at least half the section on its slots
```

Unit FORMATION tasks are issued for the extended budget. The incomplete-move log now states the result
and the time allowed, e.g. `MANOEUVRE_LEFT STAGE1 guide movement incomplete (NO_PROGRESS after 52 s, allowed 260 s)`.

## 3. Platoon-owned readiness (`fn_tryIssuePlatoonHHour`)

READY_CHECK waits while any required, not-yet-ready section makes deployment progress:

- it closes on its plan deployment point by more than 5 m (best distance so far), or
- its FIX / BLOCK / manoeuvre phase changes.

It records a failure only after **45 s without progress** (`ARTIC_readyNoProgressTimeout`) and at least
60 s in READY_CHECK (`ARTIC_readyMinSeconds`), or after 300 s in total (`ARTIC_readyCheckMaxSeconds`).
The section holding the platoon up is named (BLOCK first, then FIX, then manoeuvre):

| situation | reason | class |
|---|---|---|
| BLOCK not ready | `BLOCK_NOT_READY` | TIMING |
| FIX not ready | `FIX_NOT_READY` | TIMING |
| FIX firing, manoeuvre still waiting for its effect | `FIX_SUPPRESSION_TIMEOUT` | TACTICAL |
| manoeuvre section not ready | `MANOEUVRE_NOT_READY` | TIMING |

Log: `FSM READY_CHECK timeout plan=… ready=1/3 waited=95s noProgress=46s holding=Alpha 1-3 (BLOCK) -> BLOCK_NOT_READY`.

In FSM mode the manoeuvre section therefore no longer runs a BLOCK gate (H-hour already requires BLOCK
READY) and its FIX gate has no 70 s clock; both remain only as safety caps (`ARTIC_hHourReadyTimeout`
390 s). The non-FSM path keeps the v0.3.27 gates, with the BLOCK gate extended while BLOCK progresses.

H-hour resets the platoon's timing-retry budget.

## 4. Failure classes and reassessment

`ARTIC_fnc_classifyPlanFailure`:

- **TIMING** — `BLOCK_NOT_READY`, `FIX_NOT_READY`, `MANOEUVRE_NOT_READY`, `READY_TIMEOUT`, `MANOEUVRE_SYNC_FAILED`.
  The plan was sound; an element was late. The first TIMING failure of a scheme retries the **same**
  scheme (`RETRY_AFTER_TIMING_<reason>`) if it is still feasible. A second one changes scheme.
- **CONTACT** — `CONTACT_ON_DEPLOYMENT`. Replanning is contact-aware (section 5).
- **TACTICAL** — everything else. Scheme change exactly as in v0.3.27.

`FSM PLAN SUPERSEDED` now states the class and what the platoon is waiting for.

## 5. Contact-aware replanning

### 5.1 Section contact state (`ARTIC_fnc_assessSectionContact`, server-safe)

- **ENGAGED** — direct contact (soldier LOS or being shot at) with the section's latest contact call
  inside 200 m (`ARTIC_engagedDistance`), or reacting to effective contact with a live known enemy inside it.
- **CLOSE** — a live known enemy within 100 m (`ARTIC_closeContactDistance`), seen or only shared.

### 5.2 Committed sections (`fn_buildBattleContext`)

When a new plan is built, ENGAGED and CLOSE sections are **committed in place**:

- the best placed one (ENGAGED before CLOSE, then nearest, at least 3 fit) becomes the FIX element where
  it stands: SBF = its position, `sbfMode = CONTACT`, no SBF hold behind it;
- the scheme is `SUPPORT_MANOEUVRE` (reason `CONTACT_FIX_IN_PLACE`) whenever a flank route is usable;
- committed sections deploy at their own position (`ARTIC_committedPos`) with **no deployment march**;
  a committed manoeuvre section keeps only the part of its corridor that lies ahead of it;
- committed sections never get a platoon march slot and are armed as soon as the plan is active
  (`fn_platoonMovementStep`), so the replan cannot walk them back out through the enemy in a column.

Logs: `CONTACT-AWARE PLAN: committed=[Alpha 1-2 ENGAGED 42m]; Alpha 1-2 fixes in place at …`,
`FSM PLAN CREATED … CONTACT-AWARE committed in place=[Alpha 1-2]`, `FIX committed in place at …: no deployment march`.

### 5.3 FIX in CONTACT mode

No approach move, fire line around its own position, no hold-fire phase: it opens fire at once
(`trigger=IN_CONTACT`). The rest of the FIX play is unchanged.

### 5.4 Replan trigger (`fn_platoonContactResponse`)

Before H-hour, a manoeuvre section that calls a contact closer than 150 m
(`ARTIC_contactReplanDistance`) invalidates the plan: the platoon records `CONTACT_ON_DEPLOYMENT`
(class CONTACT), aborts the plan, and the replacement plan commits that section in place. At most once
per plan, not within 12 s of plan creation, never for FIX/BLOCK (engaging is their job) and never after
H-hour (an executing manoeuvre fights through).

Log: `contact call from Alpha 1-2 … -> CONTACT REPLAN: Alpha 1-2 (MANOEUVRE_LEFT) engaged at 67 m before its manoeuvre; plan B1_PL_P2 aborted, replanning with Alpha 1-2 fixing in place`.

### 5.5 Contact response fixes

- A FIX in READY/SUPPRESS **or a BLOCK in READY/ENGAGE** that can see the contact shifts fire onto it.
- Assist calls go only to sections not running a play (they were silently ignored before).

## 6. Sustained FIX fire (`fn_executeFixingAction`)

After opening fire the FIX keeps the objective under fire:

- a target that drops is replaced by the next live known enemy within 200 m of the aim point
  (`FIX target down; switching fire to …`), otherwise area fire on the objective
  (`FIX target down; no other live contact known, area fire on …`);
- the fire helper restarts when its 80 s cycle ends; `ARTIC_fixReadyUntil` is refreshed every second;
- it **lifts** when a manoeuvre section reaches ASSAULT (`FIX lifting fire after N s: manoeuvre section assaulting`),
  and ends when the manoeuvre sections end, or after `ARTIC_fixFireMaxSeconds` (300 s).

The fire line is built by the shared `ARTIC_fnc_buildFireLine`.

## 7. Contact reporting during plays (`fn_groupStep`)

Contact detection and `ARTIC_fnc_reportContact` now run before the play gate, for every section, every
3 s while a play is running. A manoeuvre section that bumps the enemy mid-flank calls it in.

## 8. BLOCK play (`fn_executeBlockingAction`)

`groupStep` deploys the section to its BLOCK point (publishing `ARTIC_blockProgressAt`), then starts the play:

1. **OCCUPY** — fire line through the deployment point, each point scored on sight of the objective and of
   the likely withdrawal lanes (`ARTIC_fnc_findWithdrawalLanes`: REAR, REAR_LEFT/RIGHT, LEFT/RIGHT on the
   enemy side; scored by sight and roads; lanes within 70 m of a friendly manoeuvre corridor or FCL are
   dropped). Primary lane gets two watchers (MG first), the secondary one.
2. **READY** only when ≥ 75 % are on their points and ≥ 50 % of shooters see the objective or a lane
   (one 20 m creep, else `BLOCK_NO_LOS`).
3. **HOLD** (GREEN) until H-hour, an enemy inside a withdrawal lane, the section is engaged, or a redirect.
4. **ENGAGE** (RED): lane watchers engage enemies in their lane; others engage visible enemies or area-fire
   known positions. No fire within 60 m of a friendly manoeuvre soldier (`ARTIC_blockLiftDistance`);
   when the manoeuvre is on the objective BLOCK lifts and covers the lanes only.
5. Ends 10 s after the last manoeuvre play ends, after `ARTIC_blockMaxSeconds` (480 s), or quietly when stale.

Logs: `BLOCK occupying at … withdrawal lanes REAR (sight 60%, road), REAR_RIGHT (sight 35%)`, `BLOCK READY: …`,
`BLOCK opening fire (trigger=H_HOUR)`, `BLOCK engaging enemy withdrawing via REAR lane`,
`BLOCK lifting fire off the objective …`.

## New settings (all `isNil`-guarded in `fn_preInit`)

| variable | default | meaning |
|---|---|---|
| `ARTIC_hHourReadyTimeout` | 390 (was 90) | section-side safety cap waiting for H-hour |
| `ARTIC_readyMinSeconds` | 60 | minimum time in READY_CHECK before a readiness failure |
| `ARTIC_readyNoProgressTimeout` | 45 | READY_CHECK fails after this long without deployment progress |
| `ARTIC_readyCheckMaxSeconds` | 300 | absolute READY_CHECK cap |
| `ARTIC_moveTimeoutPace` | 1.1 | m/s budgeted per movement leg |
| `ARTIC_moveNoProgressSeconds` | 40 | movement leg fails early when the guide stops closing |
| `ARTIC_fixFireMaxSeconds` | 300 | sustained FIX fire cap |
| `ARTIC_blockMaxSeconds` | 480 | BLOCK play cap |
| `ARTIC_blockLiftDistance` | 60 | BLOCK never fires within this of friendly manoeuvre soldiers |
| `ARTIC_contactAwareReplan` | true | master switch for section 5 |
| `ARTIC_contactReplanDistance` | 150 | manoeuvre contact closer than this before H-hour aborts the plan |
| `ARTIC_engagedDistance` | 200 | ENGAGED threshold |
| `ARTIC_closeContactDistance` | 100 | CLOSE threshold |

## Files

New: `tactics/fn_isPlayStale`, `tactics/fn_executeBlockingAction`, `combat/fn_buildFireLine`,
`orbat/fn_assessSectionContact`, `orbat/fn_findWithdrawalLanes`, `fsm/fn_classifyPlanFailure`,
`fsm/fn_recordPlatoonFailure`.

Modified: `tactics/fn_executePlatoonManoeuvre`, `tactics/fn_executeFixingAction`,
`tactics/fn_moveSectionTactical`, `planner/fn_groupStep`, `orbat/fn_buildBattleContext`,
`orbat/fn_selectAttackScheme`, `orbat/fn_platoonMovementStep`, `orbat/fn_platoonContactResponse`,
`fsm/fn_tryIssuePlatoonHHour`, `fsm/fn_createPlatoonPlan`, `fsm/fn_supersedePlatoonPlan`,
`fsm/fn_registerFSMEvents`, `core/fn_preInit`, `config.cpp`, both `mod.cpp`.

## Benchmark — Air Station, same mission as 0.3.29

Pass conditions:

1. No duplicate `H-HOUR RECEIVED` for one section and plan; no `H-HOUR RECEIVED` for a plan ID that has
   been superseded.
2. Every `FSM PLAN ABORT` is followed within seconds by `play ended …` / `ended quietly` lines and then
   `REASSESS` — no play of the old plan logs anything after that.
3. No `MANOEUVRE_ROUTE_FAILED` from a leg that was still closing (incomplete-move lines should read
   `NO_PROGRESS`, not a timeout with the section moving).
4. `BLOCK READY` appears only after `BLOCK occupying …`, and no `BLOCK_NOT_READY` while BLOCK is still
   visibly deploying.
5. FIX fire continues past its first target (`switching fire` / `area fire`) and ends with `lifting fire`
   when a manoeuvre section assaults.
6. If a manoeuvre section meets the enemy before H-hour: `CONTACT REPLAN` → `CONTACT-AWARE PLAN` →
   that section `committed in place` as FIX, opening fire with `trigger=IN_CONTACT`, and no
   `REPOSITION_FOR_ATTACK` march for it.
7. Ideally: one or two plans, an H-hour, and an assault reaching `FSM SECTION COMPLETE`.

Useful counts for comparison with 0.3.29 (6 plans, 57 failures):
`FSM PLAN CREATED`, `FSM SECTION FAILED`, `class=TIMING`, `RETRY_AFTER_TIMING`, `CONTACT REPLAN`.
