# ARTIC AI v0.3.30.1-alpha — Ownership Hardening Patch

## Goal

This build hardens v0.3.30 before another long Air Station benchmark. It intentionally keeps the same
tactical schemes and route planner so the test can isolate state/task ownership.

## Implemented

### 1. Authoritative task lifecycle

New function:

`ARTIC_fnc_setSectionTaskState`

Lifecycle:

```text
ASSIGNED -> DEPLOYING -> READY -> EXECUTING -> COMPLETE

ASSIGNED / DEPLOYING / READY / EXECUTING
    -> FAILED
    -> ABORTED
```

`COMPLETE`, `FAILED`, and `ABORTED` are terminal for the same `planId + taskId`.

### 2. Plan/task identity validation

READY, FAILURE, completion, stale cleanup and H-hour execution all validate the immutable task identity.
A stale P1 event cannot mutate P2.

### 3. Identity-safe stale cleanup

New function:

`ARTIC_fnc_endPlayQuietly`

A superseded script only clears tactical state if the section still owns the exact plan/task it captured.
If a replacement task is already present, the stale script leaves it untouched.

### 4. Script-handle-aware settlement

New function:

`ARTIC_fnc_isSectionPlayActive`

Both `groupStep` and Platoon FSM failure settlement now consider the actual `ARTIC_playHandle`, not only
`ARTIC_currentPlan`.

### 5. Plan-wide child abort

New function:

`ARTIC_fnc_abortSectionTask`

The first tactical failure:

- marks the reporting child `FAILED`;
- marks other live children `ABORTED`;
- publishes the plan abort ID;
- withdraws tactical execution authority;
- waits for matching script handles to actually finish before REASSESS.

### 6. H-hour is consumed once per task

A manoeuvre task records:

```text
ARTIC_hHourConsumedPlanId
ARTIC_hHourConsumedTaskId
```

A duplicate consumer logs:

```text
H-HOUR DUPLICATE IGNORED ...
```

and cannot start Stage 1 a second time.

### 7. FIX / BLOCK lifecycle

FIX and BLOCK now publish task state:

```text
DEPLOYING -> READY -> EXECUTING -> COMPLETE
```

Failure transitions to `FAILED`.

### 8. Assist suppression ownership

Reserve/inter-play assist suppression now uses the same section play handle and checks task staleness.
It cannot invisibly overlap a replacement plan indefinitely.

### 9. Defensive READY_CHECK guards

- terminal tasks are not counted as ready;
- a required section that is no longer combat effective fails the plan;
- an invalid attack plan with zero required tactical elements fails instead of deadlocking.

## Deliberately unchanged

- contact-aware replanning;
- movement deadlines;
- progress-based READY_CHECK;
- tactical scheme selection;
- FIX and BLOCK tactical geometry;
- current route planner;
- individual AI movement;
- full Section CBA FSM cutover;
- navigation cost-field rewrite.

## Benchmark pass conditions

Use the same Air Station mission.

Pass if:

1. A task never transitions `FAILED/ABORTED/COMPLETE -> READY/EXECUTING`.
2. P1 child scripts are finished before P2 begins tactical execution.
3. There is no P1 Stage 1 / Stage 2 / assault movement after P2 is created.
4. H-hour begins one manoeuvre executor per task.
5. READY_CHECK detects missing/ineffective required sections instead of hanging.
6. Assist fire stops when its task becomes stale.
7. Remaining bizarre routes can be attributed to the navigation/planner layer rather than stale task execution.

## Expected RPT markers

```text
TASK STATE plan=B1_PL_P1 task=B1_PL_P1_SEC_2 ASSIGNED -> DEPLOYING
TASK STATE ... DEPLOYING -> READY
FSM H-HOUR plan=B1_PL_P1 ...
TASK STATE ... READY -> EXECUTING
```

Failure:

```text
TASK STATE ... -> FAILED
FSM PLAN ABORT plan=B1_PL_P1 ...
FSM TASK ABORT plan=B1_PL_P1 task=... state=ABORTED
PLAY QUIET END plan=B1_PL_P1 task=...
PLATOON CBA FSM ... -> REASSESS
FSM PLAN SUPERSEDED plan=B1_PL_P1 ...
FSM PLAN CHILDREN SETTLED plan=B1_PL_P1
FSM PLAN CREATED plan=B1_PL_P2 ...
```
