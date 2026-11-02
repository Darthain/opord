# ARTIC AI — Platoon State Machine (as running in v0.3.30)

This is the live platoon runtime: a CBA state machine on the server, one item per platoon logic
object (`fn_startPlatoonCBAStateMachine`). It owns the attack **plan**; sections own **execution**
through their plays (FIX, BLOCK, platoon manoeuvre). This document states who owns what, every
transition, and the rules sections must follow.

## 1. Ownership

| Decision | Owner |
|---|---|
| Scheme, roles, corridors, deployment points, task IDs | Platoon (`PlatoonPlan`, frozen for the plan's life) |
| When a section may start its play | Platoon (`ARTIC_tacticalExecutionArmed`) |
| Whether all required elements are ready, and when they have failed to get ready | Platoon (READY_CHECK) |
| H-hour | Platoon (exactly one per plan) |
| Aborting a plan | Platoon (first recorded failure) |
| Choosing the replacement plan | Platoon (REASSESS → `fn_buildBattleContext`) |
| Moving, occupying, firing, reporting READY / FAILED / COMPLETE | Section play |
| Ending a play whose plan/task is no longer current | Section play (`ARTIC_fnc_isPlayStale`) |

A section never decides that another section has failed, and never times out the platoon's H-hour.

## 2. States and transitions

```text
                 HAS_ACTIVE_PLAN
   WAIT_INTENT ------------------> DEPLOY
                                     |  EXECUTION_ARMED (any section armed)
                                     v
                                 READY_CHECK ----- HHOUR_ISSUED -----> EXECUTE ---- PLAN_COMPLETE ---> CONSOLIDATE
                                     |                                     |                              |
            FAILURE_SETTLED          |  FAILURE_SETTLED                    | FAILURE_SETTLED              | FAILURE_SETTLED
   DEPLOY ------------------+        |                                     |                              |
                            v        v                                     v                              v
                          +----------------------------- REASSESS <-------------------------------------+
                          |   (supersede plan; build replacement)
                          |
                          +--- NEW_ACTIVE_PLAN ---> DEPLOY
```

| State | On entry / each tick |
|---|---|
| WAIT_INTENT | nothing; waits for the first plan |
| DEPLOY | re-applies the frozen plan to the sections; sections march / deploy under platoon control |
| READY_CHECK | re-applies the plan; `fn_tryIssuePlatoonHHour`: ready mask, progress watch, H-hour or readiness failure |
| EXECUTE | re-applies the plan; sections execute after H-hour |
| CONSOLIDATE | all required manoeuvre sections COMPLETE |
| REASSESS | `fn_supersedePlatoonPlan` with the root-cause reason, then waits for a new plan ID |

Conditions (`fn_platoonRuntimeCondition`):

- **FAILURE_SETTLED** — the plan has a recorded failure younger than 180 s **and no section play is
  active**. Because the first failure aborts every play of the plan (section 4), this is reached within
  seconds.
- **NEW_ACTIVE_PLAN** — an active plan whose ID differs from the one REASSESS superseded.

## 3. READY_CHECK

Required elements: FIX, BLOCK and every manoeuvre section of the plan.

- FIX is ready while it is firing (`ARTIC_fixReady` and `ARTIC_fixReadyUntil`, refreshed every second).
- BLOCK is ready while its fire line is occupied and observing (`ARTIC_blockReady`; set only by the BLOCK play).
- A manoeuvre section is ready when it has signalled READY for this plan ID (after its FIX gate in
  SUPPORT_MANOEUVRE).

All ready → H-hour: `ARTIC_hHourPlanId = planId` on every section, timing-retry budget reset.

Not all ready → progress watch. A required, not-ready section **progresses** when it closes on its plan
deployment point by more than 5 m, or its FIX / BLOCK / manoeuvre phase changes. Failure only after:

- 45 s with no progress by any required section (and at least 60 s in READY_CHECK), or
- 300 s in READY_CHECK.

The failing element is chosen BLOCK → FIX → manoeuvre and gets `BLOCK_NOT_READY`, `FIX_NOT_READY`,
`FIX_SUPPRESSION_TIMEOUT` (FIX firing, manoeuvre still waiting for effect) or `MANOEUVRE_NOT_READY`.

## 4. Failure, abort and reassessment

Failures reach the platoon three ways, all through `ARTIC_fnc_recordPlatoonFailure`:

1. a section play reports one (`ARTIC_sectionFailed` CBA server event);
2. READY_CHECK records one (section 3);
3. the contact response records `CONTACT_ON_DEPLOYMENT` (section 5).

The **first** failure of a plan is the abort reason: `ARTIC_planAbortId = planId` is published to every
section, and every play of that plan ends quietly. Later failures are history only.

Classes (`ARTIC_fnc_classifyPlanFailure`) decide the replacement:

| Class | Reasons | Replacement |
|---|---|---|
| TIMING | `BLOCK_NOT_READY`, `FIX_NOT_READY`, `MANOEUVRE_NOT_READY`, `READY_TIMEOUT`, `MANOEUVRE_SYNC_FAILED` | same scheme once (`RETRY_AFTER_TIMING_*`) if still feasible; then scheme change |
| CONTACT | `CONTACT_*` | contact-aware plan (section 5) |
| TACTICAL | everything else | scheme change (v0.3.27 rules) |

Contact-aware commitment is evaluated for every new plan, whatever the class.

## 5. Contact-aware planning

Section contact state (`ARTIC_fnc_assessSectionContact`): **ENGAGED** (direct contact, call within
200 m), **CLOSE** (live known enemy within 100 m), **NONE**.

When a plan is built, ENGAGED/CLOSE sections are **committed in place**:

- the best placed (ENGAGED first, then nearest, ≥ 3 fit) is the FIX at its own position, `sbfMode CONTACT`,
  scheme `SUPPORT_MANOEUVRE` if a flank route exists;
- committed sections deploy where they are, get no approach route and no platoon march slot, and are
  armed as soon as the plan is active;
- a committed manoeuvre section keeps only the corridor points ahead of it.

Replan trigger: before H-hour, a manoeuvre section calling a contact within 150 m aborts the plan
(once per plan, not in the first 12 s). After H-hour sections fight through.

## 6. Rules every section play must follow

1. Capture `[planId, taskId]` at start; do not start if `ARTIC_planAbortId == planId`.
2. Check `ARTIC_fnc_isPlayStale` inside **every** wait and after every movement leg; pass the identity to
   `ARTIC_fnc_moveSectionTactical`.
3. On stale: end quietly (no failure report), `finishPlan`.
4. Decide gate outcomes inside the gate, **exit at script level**. Never use `exitWith` inside
   `if/then` as a script exit.
5. Report failures with `ARTIC_fnc_signalSectionFailure`; report READY with `ARTIC_fnc_signalSectionReady`.
6. Do not time out platoon decisions (readiness of other elements, H-hour); the platoon owns those.
   Section-side caps exist only as safety nets and must outlast the platoon's.
7. Record task completion (`ARTIC_sectionCompletePlanId`, `ARTIC_fixDoneTaskId`, `ARTIC_blockDoneTaskId`)
   so groupStep does not restart a finished task under the same task ID.

## 7. Next: Section state machine

The section-level timing still inside the plays (FIX gate, partner phase waits, stage sequencing) is what
a Section state machine replaces. Proposed states, driven by the platoon's task and H-hour:

```text
ASSIGNED -> DEPLOY -> OCCUPY -> READY -> (H-hour) -> EXECUTE[stage n] -> CONSOLIDATE
                \________ any state: STALE -> IDLE (quiet) ;  FAILED -> report -> IDLE
```

Soldier level stays a priority stack rather than a state machine: immediate reaction > assigned task >
formation slot.
