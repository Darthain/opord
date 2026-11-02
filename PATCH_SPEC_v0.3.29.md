# ARTIC AI v0.3.29-alpha — Live Platoon FSM Runtime

## Purpose

v0.3.29 is the first live migration away from the independent step-loop ownership model.
It does **not** yet replace section/fireteam movement or reliable weapon employment.
Its job is to prove one thing first: a platoon attack must remain one coherent, versioned plan
from selection through execution.

The 0.3.27 benchmark showed that tactical reasoning could correctly select DOUBLE_ENVELOPMENT
and later SINGLE_ENVELOPMENT, but the same active battle context repeatedly reassigned LEFT/RIGHT
roles, sections could re-enter completed manoeuvre scripts, and section-local READY logic acted like
multiple H-hours. v0.3.29 fixes ownership before the navigation/fire-control rewrite.

## Runtime architecture introduced

High-level platoon lifecycle is now run by a **CBA state machine** on the server:

```text
WAIT_INTENT
    -> DEPLOY
    -> READY_CHECK
    -> EXECUTE
    -> CONSOLIDATE

DEPLOY / READY_CHECK / EXECUTE
    -> REASSESS on settled tactical failure

REASSESS
    -> DEPLOY only after a new plan revision exists
```

CBA's clockwork iterates platoon logic objects. The existing v0.3.27 local movement executor remains
in place during this migration build.

## Immutable PlatoonPlan V1

An attack plan now receives a unique plan ID, e.g.:

```text
B1_PL_P1
B1_PL_P2
```

The plan freezes:

- scheme of manoeuvre;
- attack axis;
- section role assignment;
- section corridor;
- section deployment position;
- section task ID;
- required READY elements;
- required COMPLETE elements;
- failure history;
- H-hour state.

Once the plan is active, ordinary intel refreshes and contact calls may update the battlefield picture,
but they cannot silently swap LEFT/RIGHT/BLOCK/FIX assignments. Roles change only after the current
plan enters REASSESS and is superseded by a new plan revision.

## Platoon-owned H-hour

Manoeuvre sections now report READY against their current `planId` and `taskId` through a CBA server
event. The platoon READY_CHECK state builds the ready mask and issues exactly one H-hour when every
required element is ready.

A manoeuvre section may not self-release. It waits for:

```text
ARTIC_hHourPlanId == its immutable planId
```

The default READY wait is 90 seconds (`ARTIC_hHourReadyTimeout`) so one flank can wait for the other
without creating a premature synchronization failure.

## Task completion

When a platoon manoeuvre reaches COMPLETE, the section records:

```text
ARTIC_sectionCompletePlanId
ARTIC_sectionTaskState = COMPLETE
```

`groupStep` treats that task as terminal for that plan. It may not launch the same manoeuvre again
until a new PlatoonPlan/task ID replaces it.

## Failure/reassessment ownership

Sections report formal failure reasons to the server using `ARTIC_sectionFailed`.
The CBA platoon state machine waits until the local tactical play has actually ended, then enters
REASSESS and supersedes the plan.

The consumed section failure latch is cleared during supersession so stale failure data cannot
immediately kill the replacement plan.

## Contact compatibility

Hasty-contact logic is no longer permitted to restore/rewrite pre-plan section roles while a live
PlatoonPlan owns the formation. Existing hasty metadata may expire, but the immutable plan is
re-applied instead.

## Deliberately unchanged in this build

- v0.3.27 corridor/guide movement remains the movement executor.
- Long-range `calculatePath` architecture is not yet replaced.
- Section and Fireteam CBA state machines are not live yet.
- Vanilla TARGET/AUTOCOMBAT state matrix is not yet implemented.
- Reliable `doFire` / suppressive-fire control is not yet implemented.
- BLOCK geometry is still the v0.3.27 implementation.

Those are subsequent migration phases after plan ownership is proven.

## Expected RPT sequence

Healthy initial plan:

```text
FSM PLAN CREATED plan=B1_PL_P1 ...
PLATOON CBA FSM WAIT_INTENT -> DEPLOY plan=B1_PL_P1
...
PLATOON CBA FSM DEPLOY -> READY_CHECK plan=B1_PL_P1
FSM SECTION READY plan=B1_PL_P1 section=Alpha 1-1 ...
FSM SECTION READY plan=B1_PL_P1 section=Alpha 1-2 ...
FSM H-HOUR plan=B1_PL_P1 READY 3/3; platoon execution released
PLATOON CBA FSM READY_CHECK -> EXECUTE plan=B1_PL_P1
... H-HOUR RECEIVED plan=B1_PL_P1 ...
FSM SECTION COMPLETE plan=B1_PL_P1 ...
```

Healthy failure/reassessment:

```text
FSM SECTION FAILED plan=B1_PL_P1 ... reason=MANOEUVRE_ROUTE_FAILED
PLATOON CBA FSM EXECUTE -> REASSESS plan=B1_PL_P1
FSM PLAN SUPERSEDED plan=B1_PL_P1 ...
FSM PLAN CREATED plan=B1_PL_P2 ...
PLATOON CBA FSM REASSESS -> DEPLOY plan=B1_PL_P2
```

## Benchmark pass conditions

Use the same Stratis Air Station test. v0.3.29 passes its intended scope if:

1. section roles never change while the same plan ID is active;
2. exactly one platoon H-hour is issued per plan;
3. a completed section does not restart the same task;
4. any role/scheme change is accompanied by a new plan ID;
5. a settled tactical failure causes REASSESS -> SUPERSEDED -> new plan;
6. no stale failure immediately supersedes that replacement plan.

Do not judge this build primarily on firing reliability or final navigation quality; those are
intentionally later phases.
