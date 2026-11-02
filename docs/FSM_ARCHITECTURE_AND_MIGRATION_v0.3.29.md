# ARTIC AI — FSM Architecture & Migration Specification
## Target branch: v0.3.29-alpha

This document defines the target ARTIC AI runtime architecture and the migration sequence from the v0.3.27 step-loop implementation.

The guiding principle is:

> ARTIC owns decisions, tactical plans, role assignments, synchronisation and coarse navigation.  
> Arma owns short-range locomotion, local obstacle avoidance, animation and model/path-LOD traversal.

The purpose of this revision is to eliminate the problems observed in the latest benchmark:
- section roles changing during an active attack;
- repeated/restarted manoeuvre scripts under the same plan;
- section-level "H-hour" behaviour instead of platoon-owned synchronisation;
- vanilla ATTACK planning fighting ARTIC movement;
- long-range route/path ownership ambiguity;
- failed plans being retried without clear plan-version ownership.

---

# 1. Runtime hierarchy

```text
ARTIC Commander State Machine
        |
        v
ARTIC Platoon State Machine
        |
        +-------------------------------+
        |               |               |
        v               v               v
ARTIC Section SM   ARTIC Section SM   ARTIC Section SM
        |
        +-----------------------+
        |                       |
        v                       v
ARTIC Fireteam SM A       ARTIC Fireteam SM B
        |
        v
ARTIC local navigation gate
        |
        v
Arma path / locomotion / animation
```

Recommended runtime:
- Commander / Platoon / Section / Fireteam logic: CBA state-machine layer.
- Local low-level movement: short stable destinations, optionally a small BI `commandFSM`/`doFSM` leaf controller after separate testing.
- CBA Events for upward/downward signalling.
- CBA PFHs for short-lived monitoring only, not permanent AI decision loops.

The BI `.fsm` diagrams remain useful as the visual design source, but the high-level runtime should be CBA state machines rather than hundreds of independent `execFSM` instances.

---

# 2. Authority model

## Commander owns
- strategic objective selection;
- operational intent;
- platoon allocation;
- reserve commitment;
- operation-level reassessment;
- support priorities.

## Platoon owns
- current immutable plan;
- scheme of manoeuvre;
- attack axis;
- section role assignments;
- section corridors;
- synchronisation / H-hour;
- tactical reassessment;
- plan replacement.

## Section owns
- execution of one assigned task from one platoon plan;
- fireteam tasking;
- local section formation;
- reporting READY / FAILED / COMPLETE upward;
- short local adaptation that does not change platoon intent.

A Section may report failure. It may not change its own platoon role.

## Fireteam owns
- local method;
- short movement / bounds;
- deployment;
- local fire-control task;
- casualty reorganisation;
- report READY / FAILED upward.

A Fireteam may not change section or platoon scheme.

## Soldier owns
- weapon handling;
- stance / animation;
- local cover/locomotion execution;
- no independent operational/tactical plan.

---

# 3. Immutable PlatoonPlan model

Every active tactical plan must have a unique ID and revision.

Example:

```sqf
createHashMapFromArray [
    ["planId", "B1_PL_00017"],
    ["revision", 17],
    ["battlefieldId", "BF_EAST_CMD_043038_60"],
    ["scheme", "DOUBLE_ENVELOPMENT"],
    ["axis", 206],
    ["phase", "DEPLOY"],
    ["createdAt", time],

    ["sectionAssignments", [
        ["Alpha 1-1", "MANOEUVRE_RIGHT"],
        ["Alpha 1-2", "MANOEUVRE_LEFT"],
        ["Alpha 1-3", "BLOCK"]
    ]],

    ["sectionCorridors", createHashMap],
    ["blockPosition", []],
    ["assaultLines", createHashMap],
    ["fcl", []],
    ["loa", []],

    ["requiredReady", ["Alpha 1-1","Alpha 1-2","Alpha 1-3"]],
    ["readySet", []],
    ["completeSet", []],

    ["failureHistory", []],
    ["failedSchemes", []],

    ["status", "ACTIVE"]
]
```

Core rule:

> Once a plan enters DEPLOY or EXECUTE, section role assignments and corridors are frozen.

They change only when:

```text
ACTIVE PLAN
    |
    v
REASSESS
    |
    v
OLD PLAN -> SUPERSEDED
    |
    v
NEW PLAN ID / REVISION
```

This prevents role swapping under a live attack.

---

# 4. Platoon state machine

```text
INIT
  |
  v
WAIT_INTENT
  |
  v
ASSESS_BATTLEFIELD
  |
  v
SELECT_SCHEME
  |
  v
BUILD_PLAN
  |
  v
REPOSITION
  |
  v
DEPLOY
  |
  v
READY_CHECK
  |
  +---- not ready ----> DEPLOY
  |
  v
H_HOUR
  |
  v
EXECUTE
  |
  v
ASSESS_EXECUTION
  |             |
  | success     | failure
  v             v
CONSOLIDATE   REASSESS
                  |
                  v
             SELECT_SCHEME
```

Important:
- H-hour is a Platoon state, never a Section decision.
- A Section cannot launch itself because it thinks it is ready.
- A Section completion report does not cause the same task to restart.
- Reassessment creates a new plan revision.

---

# 5. Platoon event contract

Recommended CBA events:

```text
ARTIC_platoonIntentReceived
ARTIC_planCreated
ARTIC_sectionReady
ARTIC_sectionFailed
ARTIC_sectionComplete
ARTIC_sectionIneffective
ARTIC_hHour
ARTIC_planSuperseded
ARTIC_contactUpdate
ARTIC_routeFailure
ARTIC_fixNoLOS
ARTIC_fixIneffective
ARTIC_assaultStalled
ARTIC_blockInvalid
```

All subordinate events must include the plan ID.

Example payload:

```sqf
[
    _platoonId,
    _sectionId,
    _planId,
    "MANOEUVRE_ROUTE_FAILED",
    _context
]
```

Events referring to an obsolete plan ID are ignored.

---

# 6. Section state machine

```text
INIT
  |
  v
WAIT_TASK
  |
  v
ACCEPT_TASK
  |
  v
ASSESS
  |
  +--> MOVE
  +--> FIX
  +--> MANOEUVRE
  +--> BLOCK
  +--> RESERVE
  +--> HOLD
  +--> WITHDRAW
  |
  v
DEPLOY
  |
  v
READY
  |
  v
WAIT_H_HOUR
  |
  v
EXECUTE_TASK
  |
  v
ASSESS_PROGRESS
  |        |
  |        +--> FAILED
  |
  +--> COMPLETE
```

Section task contract includes:
- `planId`;
- `taskId`;
- `role`;
- `corridor`;
- `destination`;
- `facing`;
- `sector`;
- `FCL/LOA`;
- `syncKey`;
- `rules`;
- `deadline`.

A Section can only enter EXECUTE_TASK after receiving the H-hour for its active plan unless its role is explicitly exempt (e.g. preliminary BLOCK occupation or reconnaissance).

---

# 7. Fireteam task schema

Versioned task:

```sqf
[
    "ARTIC_FT_TASK_V2",
    _planId,
    _taskId,
    _type,
    _issuedAt,
    _issuer,
    _priority,
    _destination,
    _corridor,
    _threatPos,
    _target,
    _facing,
    _sector,
    _frontage,
    _spacing,
    _tolerance,
    _deadline,
    _syncKey,
    _rules,
    _meta
]
```

Task types:
- MOVE
- FOLLOW
- BOUND
- DEPLOY
- OBSERVE
- SUPPRESS
- ENGAGE
- ASSAULT
- BLOCK
- HOLD
- WITHDRAW
- REORGANISE

---

# 8. Fireteam state machine

```text
IDLE
  |
  v
RECEIVE_TASK
  |
  v
ASSESS
  |
  +--> PLAN_LOCAL_MOVE --> MOVE -----------> READY
  |
  +--> BOUND_MOVE -------> BOUND_SET -------+
  |                                         |
  +--> DEPLOY ------------> READY            |
  |                                         |
  +--> ASSAULT_PREP --H-HOUR--> ASSAULT --> CONSOLIDATE --> READY
  |
  +--> SUPPRESS ----------> READY / ACTIVE
  |
  +--> HOLD --------------> READY / ACTIVE
  |
  +--> BREAK_CONTACT -----> READY
  |
  +--> REORGANISE --------> READY
```

High-priority interrupts:
- new plan revision;
- abort;
- team combat ineffective;
- route blocked;
- deadline exceeded;
- leader casualty;
- section superseded.

---

# 9. Synchronisation model

A true platoon synchronisation gate replaces the current section-level H-hour logic.

Example:

```text
PLAN B1_PL_00017
DOUBLE_ENVELOPMENT

Alpha 1-1 RIGHT: READY
Alpha 1-2 LEFT:  READY
Alpha 1-3 BLOCK: READY
          |
          v
PLATOON READY MASK = 3/3
          |
          v
ARTIC_hHour(B1_PL_00017)
          |
          +----------+----------+
          |          |          |
          v          v          v
      RIGHT GO    LEFT GO    BLOCK ACTIVE
```

The same mechanism applies to later phase transitions.

---

# 10. Reassessment model

Reassessment should be failure-driven, not triggered by ordinary intel jitter.

Formal failure reasons:

```text
FIX_NO_LOS
FIX_INEFFECTIVE
FIX_SUPPRESSION_TIMEOUT
MANOEUVRE_ROUTE_FAILED
MANOEUVRE_SYNC_FAILED
ASSAULT_STALLED
BLOCK_INVALID
BLOCK_NOT_READY
SECTION_COMBAT_INEFFECTIVE
TARGET_MOVED_MATERIALLY
ROUTE_EXPOSURE_UNACCEPTABLE
```

New contact reports update the battlefield picture, but do not rewrite section roles inside an active plan.

On failure:

```text
EXECUTE
  |
  v
ASSESS_EXECUTION
  |
  v
REASSESS
  |
  +--> mark failed scheme/axis
  +--> update combat effectiveness
  +--> update battlefield geometry
  +--> evaluate alternate schemes
  |
  v
NEW PLAN REVISION
```

---

# 11. Tactical schemes

Initial supported library:

## SUPPORT_MANOEUVRE
- FIX
- MANOEUVRE_LEFT
- MANOEUVRE_RIGHT

## DOUBLE_ENVELOPMENT
- MANOEUVRE_LEFT
- MANOEUVRE_RIGHT
- BLOCK / SUPPORT / RESERVE

## SINGLE_ENVELOPMENT
- MANOEUVRE
- BLOCK / SUPPORT
- RESERVE

## ISOLATE_AND_ASSAULT
- BLOCK_LEFT
- BLOCK_RIGHT
- ASSAULT

## DIRECT_BOUNDING_ATTACK
- ASSAULT
- SUPPORT
- RESERVE

Tactical scheme selection evaluates:
- SBF quality;
- manoeuvre route quality;
- route exposure;
- terrain masking;
- slope;
- enemy frontage;
- enemy depth;
- likely enemy egress;
- friendly combat effectiveness;
- available weapons/support.

---

# 12. BLOCK redesign

BLOCK must be a real battlefield task.

A blocking position should be chosen from:
- enemy rear/egress geometry;
- road network / likely withdrawal routes;
- terrain channels;
- masking and cover;
- safe friendly-fire geometry;
- supportable distance from other sections.

If no meaningful blocking position exists:
- downgrade BLOCK to SUPPORT, or
- retain as RESERVE.

Do not use a nominal midpoint merely to satisfy a role slot.

---

# 13. Navigation ownership

## ARTIC owns
- coarse route;
- corridor;
- lane side;
- threat avoidance;
- terrain cost;
- route exposure;
- tactical gates.

## Arma owns
- local path around objects;
- local collision avoidance;
- building/path-LOD traversal;
- animation;
- short-range locomotion.

ARTIC should no longer rely on one long `calculatePath` result as a full route.

---

# 14. ARTIC navigation field

For each operation, generate a local tactical navigation field rather than a whole-island navmesh.

Candidate costs:

```text
distance
slope
elevation change
water
road preference/penalty
vegetation/masking
building density
open-ground exposure
enemy LOS
enemy proximity
friendly lane ownership
formation width
objective exclusion
friendly-fire geometry
```

Recommended approach:
- 10–20 m tactical cells or graph nodes;
- Weighted A* or Theta* for coarse route;
- path smoothing;
- stable corridor/gates;
- short Arma navigation between gates.

---

# 15. Actual engine-path debugging

Attach `PathCalculated` to the real section/fireteam leader.

Debug layers:

```text
COLOURED:
ARTIC tactical route / corridor

WHITE:
actual leader PathCalculated output

CIRCLES:
current ARTIC gate / lookahead target

TEXT:
planId
section state
fireteam state
movement owner
current gate
route failure timer
```

This makes it clear whether a bad movement originates from:
- ARTIC tactical planning; or
- Arma local navigation.

---

# 16. Vanilla AI ownership by state

ARTIC should explicitly control vanilla AI features by state.

Example policy:

```text
MOVE / REPOSITION / DEPLOY
- TARGET disabled
- AUTOCOMBAT disabled
- vanilla autonomous ATTACK suppressed
- movement/path kept enabled

OBSERVE
- TARGET disabled unless specifically required

SUPPRESS / ENGAGE / ASSAULT
- TARGET enabled as required
- ARTIC fire-control owns target choice
- explicit fire-control commands

CONSOLIDATE
- state-dependent
```

The exact command matrix must be tested in isolation before broad deployment.

---

# 17. ACE/CBA integration

## CBA
Use:
- CBA state machines;
- CBA targeted/local events;
- CBA PFH for temporary monitors;
- CBA XEH for init/locality;
- CBA settings for tunable doctrine/debug/navigation parameters.

## ACE
Consume public ACE data/events rather than duplicating systems.

Examples:
- medical/combat-effectiveness state;
- unconscious/death state;
- AI firing events for future suppression scoring;
- headless/locality implications.

Do not install competing damage handlers that can conflict with ACE Medical.

---

# 18. Migration sequence from v0.3.27

## Phase 0 — freeze benchmark
Keep v0.3.27 as the reference branch.

Benchmark:
- Stratis Air Station / radar area;
- three 8-man sections;
- same UAS/intel setup;
- no competing AI mods.

---

## Phase 1 — data model only
Add:
- `PlatoonPlan`;
- `planId/revision`;
- immutable section role mapping;
- task IDs;
- failure history.

Do not change movement yet.

Success:
- roles cannot change without a new plan revision;
- telemetry always prints current planId.

---

## Phase 2 — live Platoon CBA state machine
Move ownership of:
- plan creation;
- phase;
- ready mask;
- H-hour;
- reassessment;
- plan supersession.

Old section execution remains temporarily.

Success:
- one H-hour per plan;
- no section may self-release;
- completed section task cannot restart under same taskId.

---

## Phase 3 — Section CBA state machine
Move:
- task acceptance;
- deployment;
- ready reporting;
- task completion/failure;
- role-specific state.

Remove equivalent repeated logic from old `groupStep`/manoeuvre scripts.

Success:
- each Section shows one explicit state;
- role remains stable;
- failures report upward once.

---

## Phase 4 — vanilla authority matrix
Implement state-based AI controls.

Test separately:
- MOVE state;
- CONTACT during MOVE;
- ASSAULT state;
- HOLD state.

Success:
- no unsolicited `ATTACK / LEADER PLANNED` during ARTIC movement;
- firing remains possible when ARTIC deliberately enables combat state.

---

## Phase 5 — Fireteam CBA state machine
Introduce two fireteams per normal section.

Move:
- local bounds;
- tactical deployment;
- suppression task;
- assault task;
- reorganisation.

Success:
- Section controls fireteams, not individual soldiers;
- travel no longer requires constant per-soldier destination updates.

---

## Phase 6 — navigation rewrite
Replace long synthetic path ownership with:
- ARTIC tactical cost field;
- stable corridor;
- short gates;
- actual leader `PathCalculated` telemetry.

Success:
- no cross-map role-driven path flips;
- no frequent route churn;
- actual leader path visibly follows ARTIC corridor intent.

---

## Phase 7 — BLOCK / SUPPORT / RESERVE geometry
Implement real battlefield role locations.

Success:
- BLOCK has a valid egress/terrain reason;
- no nominal stationary block when geometry does not support it.

---

## Phase 8 — reliable fire-control
Only after state/movement ownership is stable:
- explicit engage;
- suppressive fire;
- MG tasking;
- AT tasking;
- suppression from actual firing/events.

Success:
- tactical release reliably creates real fires.

---

## Phase 9 — remove obsolete loop ownership
Retire or reduce:
- repeated `*Step.sqf` decision loops;
- duplicate plan checks;
- per-soldier constantly refreshed movement ownership;
- duplicated ready/sync logic.

Keep only monitoring functions that have a clear single owner.

---

# 19. Telemetry standard

Every important log line should contain:

```text
plan=<planId>
plState=<state>
section=<name>
secState=<state>
ft=<A/B>
ftState=<state>
task=<taskId>
role=<role>
```

Example:

```text
[ARTIC][B1_PL]
plan=B1_PL_00017
plState=READY_CHECK
ready=2/3

[ARTIC][Alpha 1-2]
plan=B1_PL_00017
secState=READY
role=MANOEUVRE_LEFT
task=SEC_A12_004

[ARTIC][Alpha 1-2/FT-A]
ftState=BOUND_SET
task=FTA_0009
```

This is essential for debugging state ownership.

---

# 20. Definition of success for the first FSM benchmark

The first live FSM benchmark is successful if:

1. One plan ID is created for the initial attack.
2. Section roles remain unchanged while that plan is active.
3. All required sections report READY against the same plan ID.
4. Platoon emits exactly one H-hour for that plan.
5. Sections do not restart completed tasks under the same taskId.
6. If a manoeuvre fails, the Platoon enters REASSESS.
7. A new plan ID is created before any role changes.
8. No unsolicited vanilla ATTACK planning overrides movement-state ownership.
9. Debug paths distinguish ARTIC corridor vs actual engine path.
10. Reassessment can produce a different scheme without sending a section on a contradictory cross-map route.

---

# 21. Recommended next build

The next implementation branch should be:

```text
ARTIC_AI_v0.3.29-alpha-FSM-runtime
```

Scope:
- CBA state-machine runtime foundation;
- PlatoonPlan v1;
- Platoon FSM live;
- plan/revision ownership;
- section task IDs;
- platoon-owned H-hour;
- CBA event bus;
- state telemetry;
- old movement retained temporarily.

Do NOT yet combine:
- full Fireteam runtime;
- navigation rewrite;
- reliable fire-control.

The purpose of v0.3.29 is to prove state ownership first.
