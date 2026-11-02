# ARTIC AI v0.3.30.2-alpha — Reassessment safety (built on v0.3.30.1 hardening)

## What happened in the 0.3.30.1 Air Station run (2026-10-02 21:26)

No script errors. The 0.3.30.1 task lifecycle worked: every abort was followed by quiet play endings,
children settled in the same second, no duplicate H-hour, no stale-plan movement. The failure was in
the *tactical* decisions around reassessment:

| time | event | problem |
|---|---|---|
| 21:31:56 | P1 DOUBLE_ENVELOPMENT, axis 204. BLOCK deploys to the platoon HOLD centre 044040, 235 m from the objective in urban terrain | BLOCK position chosen for cover, not observation |
| 21:34:02 | BLOCK arrives, occupies its fire line (no lane observable) | |
| 21:34:38 | `BLOCK: 0/4 shooters see …; moving the fire line 20 m forward` | a 20 m creep cannot fix a position 235 m back |
| 21:35:02 | `FSM READY_CHECK timeout … waited=60s noProgress=59s … BLOCK_NOT_READY` (TIMING) | READY_CHECK could not see the occupation/creep as progress and fired 6 s before BLOCK's own verdict (`BLOCK_NO_LOS`, TACTICAL) |
| 21:35:09 | P2 `RETRY_AFTER_TIMING` — but a full COA re-search picks **axis 21, 177° from P1** | a "retry" that is a completely new plan; still forces DOUBLE_ENVELOPMENT although an SBF (38 %) now existed |
| 21:35:25 | `REPOSITION_FOR_ATTACK -> RELEASE 042035` in FILE | the reposition march is a straight line from 044040 to 042035, which runs through the objective at 043038 |
| 21:36:36 | contact at 63–76 m (`tactical release (CONTACT) nearestThreat=63m`); BLOCK's call answered "on the objective; plan continues" | |
| 21:36:56 | Alpha 1-1 contact at 64 m → `CONTACT REPLAN` (worked as designed) | three casualties by 21:37:18 |
| 21:37:03 | P3 contact-aware: Alpha 1-3 fixes in place at 043038, Alpha 1-1 committed | correct reaction, but from inside the enemy position |

Root cause: reassessment could choose an axis on the far side of the enemy, and the reposition march to it
has no route — it walks straight across the objective. The mislabelled first failure (TIMING instead of
TACTICAL) made it worse by triggering a "retry" that was not a retry.

## Fixes

### 1. Reposition safety in the COA search (`fn_generateBattleCOAs`)
Any candidate axis that turns 35° or more from the platoon's current bearing (which triggers the straight
FILE reposition march) is rejected for both support and manoeuvre if the march line passes closer to a known
enemy position than `ARTIC_repositionStandoff` (150 m), or closer than the platoon already is.
Log: `COA reposition safety: N axis candidate(s) rejected …`; candidates show `/REPO_UNSAFE`.

Checked against this run's layout: axis 21 (chosen in P2) is rejected (march passes 0 m from the enemy);
own side and ±60° turns stay valid; a 90° turn from 200 m is rejected, the same turn from 700 m out is allowed.

### 2. A TIMING retry keeps the failed plan's axis
`fn_supersedePlatoonPlan` stores `lastFailedAxis`; on a TIMING retry the COA search evaluates only that axis
(turn and reposition safety are still measured from where the platoon actually is). If the scheme is not
feasible on that axis the retry budget is spent and the next cycle runs the full search.
Logs: `COA TIMING retry: evaluating only the failed plan's axis …`, `COA TIMING retry of … not feasible …`.

### 3. READY_CHECK sees occupation progress
New `ARTIC_fnc_markDeployProgress` increments `ARTIC_deployProgressSeq` (a counter — no cross-machine clock
comparison) whenever FIX/BLOCK make progress: soldiers reaching firing points, a fire line moving, the FIX
approach closing, BLOCK deployment closing. READY_CHECK includes it in its progress signature, so an element
that is still occupying is not timed out and reports its own verdict (`BLOCK_NO_LOS` = TACTICAL → scheme change).

### 4. BLOCK observation search
Instead of one blind 20 m creep, a BLOCK that cannot see searches up to `ARTIC_blockObsSearch` (60 m) forward
and 25 m either side for the point with the best sight of the objective/lanes, never closer than
`ARTIC_blockMinStandoff` (80 m) to known enemy, re-occupies there, and only then decides. No such point →
`BLOCK_NO_LOS` at once.
Logs: `BLOCK: … moving the fire line N m to an observation point at … (sight X%)`, or `… no point within 60 m … sees it`.

### 5. Contact replan covers FIX/BLOCK still marching
Before H-hour, a FIX or BLOCK section whose play has not started (still deploying) that calls a contact
inside 150 m also triggers `CONTACT REPLAN`.

### 6. Housekeeping
- `ARTIC_VERSION` / CfgPatches / both mod.cpp / FSM start line: 0.3.30.2-alpha (0.3.30.1 still reported
  `Version 0.3.30-alpha` from preInit).
- `TACTICAL ROLES plan=` shows `PENDING` while a replacement plan is being built (it printed the superseded ID).

## New settings
| variable | default | meaning |
|---|---|---|
| `ARTIC_repositionStandoff` | 150 | reposition march may not pass closer than this to known enemy |
| `ARTIC_blockObsSearch` | 60 | how far forward BLOCK searches for observation |
| `ARTIC_blockMinStandoff` | 80 | BLOCK observation point never closer than this to known enemy |

## Files
New: `tactics/fn_markDeployProgress`.
Modified: `orbat/fn_generateBattleCOAs`, `orbat/fn_buildBattleContext`, `orbat/fn_platoonContactResponse`,
`fsm/fn_tryIssuePlatoonHHour`, `fsm/fn_supersedePlatoonPlan`, `fsm/fn_startPlatoonCBAStateMachine`,
`tactics/fn_executeBlockingAction`, `tactics/fn_executeFixingAction`, `planner/fn_groupStep`,
`core/fn_preInit`, `config.cpp`, both `mod.cpp`.

## Benchmark — same Air Station mission
Pass if:
1. No `REPOSITION_FOR_ATTACK` march whose line crosses the objective; any large axis change after first
   deployment is either rejected (`REPO_UNSAFE`) or approaches from a clear side.
2. A BLOCK that cannot see reports `BLOCK_NO_LOS` (class TACTICAL) or finds an observation point — no
   `BLOCK_NOT_READY` while its fire line is still being occupied.
3. Any `RETRY_AFTER_TIMING` plan has the same axis as the plan it retries.
4. If the platoon still meets the enemy before H-hour, `CONTACT REPLAN` fires on the first close call,
   whichever role made it.

Still open (not addressed here): the planner places BLOCK at the platoon HOLD centre rather than choosing an
observation position; engine `UNITCTRL CONFLICT cmd=ATTACK plan=LEADER PLANNED` commands in contact.
