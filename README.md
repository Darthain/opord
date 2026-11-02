# ARTIC AI v0.3.30.2-alpha — Reassessment Safety

Built on the v0.3.30.1 ownership-hardening build. In the 0.3.30.1 Air Station run the plan lifecycle held up,
but reassessment flipped the attack axis 177° and the straight-line reposition march took the platoon through
the objective. This build rejects unsafe reposition axes, keeps the axis on timing retries, lets READY_CHECK
see fire-line occupation, gives BLOCK a bounded observation search, and extends contact replanning to FIX/BLOCK
still on the march. See `PATCH_SPEC_v0.3.30.2.md`.

New log markers: `COA reposition safety: …`, `/REPO_UNSAFE`, `COA TIMING retry: evaluating only the failed plan's axis …`,
`BLOCK: … moving the fire line N m to an observation point …`.

---

# ARTIC AI v0.3.30.1-alpha — Task Ownership Hardening

This is a focused hardening pass over v0.3.30. It does **not** rewrite navigation yet. Its purpose is
to make every section play belong to exactly one immutable `planId + taskId`, make FAILED / ABORTED /
COMPLETE terminal, and ensure the Platoon FSM waits for old script handles to finish before replacing
a failed plan.

### What changed

- **Authoritative task lifecycle** — `ASSIGNED -> DEPLOYING -> READY -> EXECUTING -> COMPLETE`, with
  `FAILED` and `ABORTED` terminal from any active state.
- **Identity-safe cleanup** — stale P1 scripts cannot reset movement/task state belonging to P2.
- **Play-handle settlement** — the Platoon FSM now treats a section play as active while either its
  tactical plan flag or its actual script handle is still alive.
- **Plan-wide abort** — the first plan failure marks the failed child `FAILED`, all other live children
  `ABORTED`, and waits for their scripts to unwind before supersession.
- **One H-hour consumption per task** — a duplicate manoeuvre consumer is rejected before Stage 1.
- **Tracked assist suppression** — platoon assist fire now participates in the same play ownership
  mechanism and stops when its plan/task becomes stale.
- **READY hardening** — terminal tasks cannot report READY; stale ready/failure events are rejected by
  plan/task identity.
- **Defensive guard** — an invalid plan with no required tactical elements or a required section that is
  no longer combat effective fails instead of deadlocking READY_CHECK.

### What is deliberately unchanged

The v0.3.30 contact-aware replanning, distance-scaled movement deadlines, progress-based READY_CHECK,
FIX/BLOCK behaviour, failure classification and route planner remain in place. The full tactical
navigation rewrite is deferred until task ownership is clean.

### Key test markers

```text
TASK STATE plan=B1_PL_P1 task=B1_PL_P1_SEC_2 ASSIGNED -> DEPLOYING
TASK STATE ... DEPLOYING -> READY
FSM H-HOUR plan=B1_PL_P1 ...
TASK STATE ... READY -> EXECUTING
```

On a plan failure:

```text
TASK STATE ... -> FAILED
FSM PLAN ABORT plan=B1_PL_P1 ...
FSM TASK ABORT plan=B1_PL_P1 task=... state=ABORTED ...
PLAY QUIET END plan=B1_PL_P1 task=... sameTask=true ...
PLATOON CBA FSM ... -> REASSESS
FSM PLAN SUPERSEDED plan=B1_PL_P1 ...
FSM PLAN CHILDREN SETTLED plan=B1_PL_P1
FSM PLAN CREATED plan=B1_PL_P2 ...
```

After `P2` is created there should be no P1 Stage 1 / Stage 2 / assault movement. A duplicate H-hour
consumer should produce `H-HOUR DUPLICATE IGNORED` and must not start another Stage 1.

Use the unchanged Air Station benchmark.

---

# ARTIC AI v0.3.30-alpha — Plan Lifecycle + Contact-Aware Replanning

v0.3.29 gave every platoon attack one immutable plan and one platoon-owned H-hour. Its Air Station run
showed the machinery around that plan failing: plays that kept running after they failed, fixed stage
timeouts, each section running its own BLOCK/FIX clock, FIX ending when its first target died, and
replans that marched an engaged section back out through the enemy. v0.3.30 fixes those and makes
replanning aware of which sections are already in the fight.

### What changed

- **Play lifecycle** — plays end quietly when their plan/task is replaced or aborted; gates exit at
  script level; one play per section (tracked by script handle); the first failure aborts the whole plan.
- **Movement** — leg deadlines scale with distance and extend while the section closes; early fail only
  on real no-progress.
- **Readiness** — the platoon READY_CHECK waits while sections are deploying and fails only on lack of
  progress, naming the late element.
- **Failure classes** — TIMING retries the same scheme once; CONTACT replans around the engaged section;
  TACTICAL changes scheme.
- **Contact-aware replanning** — engaged/close sections are committed in place; the best placed one fixes
  where it stands and opens fire at once; no deployment march for committed sections.
- **FIX** — sustained fire with retargeting / area fire; lifts when the assault goes in.
- **BLOCK** — real fire line covering the objective and withdrawal lanes; ready only when occupied.
- **Contact calls** during plays.

### Expected test markers

```text
FSM PLAN CREATED plan=B1_PL_P1 ...
FSM H-HOUR plan=B1_PL_P1 READY 3/3; platoon execution released
FIX target down; switching fire to ...      /  area fire on ...
FIX lifting fire after N s: manoeuvre section assaulting the objective
BLOCK occupying at ... withdrawal lanes ...  ->  BLOCK READY  ->  BLOCK opening fire (trigger=H_HOUR)
```

On failure or contact:

```text
FSM SECTION FAILED ... class=TIMING|CONTACT|TACTICAL
FSM PLAN ABORT plan=... ; ending this plan's section plays before reassessment
... play ended: plan ... is no longer current
FSM READY_CHECK timeout plan=... holding=Alpha 1-3 (BLOCK) -> BLOCK_NOT_READY
TACTICAL SCHEME selected=DOUBLE_ENVELOPMENT reason=RETRY_AFTER_TIMING_BLOCK_NOT_READY
CONTACT REPLAN: Alpha 1-2 (MANOEUVRE_LEFT) engaged at 67 m before its manoeuvre ...
CONTACT-AWARE PLAN: committed=[Alpha 1-2 ENGAGED 67m]; Alpha 1-2 fixes in place at ...
```

Use the normal Air Station benchmark. See `PATCH_SPEC_v0.3.30.md` (pass conditions at the end) and
`docs/PLATOON_STATE_MACHINE.md`.

---

# ARTIC AI v0.3.29-alpha — Live Platoon FSM Runtime

This is the first **live CBA state-machine migration build**. The v0.3.27 movement executor is retained,
but platoon plan identity, role immutability, READY/H-hour synchronization, completion and tactical
supersession are now owned by a server-side CBA platoon state machine.

The main test is no longer whether ARTIC can invent an envelopment — v0.3.27 proved it can. The test is
whether one selected plan remains coherent while it is executed.

### New runtime guarantees

- Every attack gets a unique `planId` / revision.
- Section roles/corridors/task IDs are frozen for the life of that plan.
- Sections report READY; only the Platoon FSM issues H-hour.
- A completed section task cannot restart under the same plan ID.
- Tactical failure is consumed once, supersedes the old plan, and permits a new plan revision.
- Hasty-contact cleanup cannot overwrite roles owned by an active plan.

### Expected test markers

```text
FSM PLAN CREATED plan=B1_PL_P1
PLATOON CBA FSM WAIT_INTENT -> DEPLOY
PLATOON CBA FSM DEPLOY -> READY_CHECK
FSM SECTION READY ...
FSM H-HOUR plan=B1_PL_P1 ...
PLATOON CBA FSM READY_CHECK -> EXECUTE
FSM SECTION COMPLETE ...
```

On failure, look for:

```text
FSM SECTION FAILED ...
PLATOON CBA FSM ... -> REASSESS
FSM PLAN SUPERSEDED plan=B1_PL_P1 ...
FSM PLAN CREATED plan=B1_PL_P2 ...
```

Use the normal Air Station benchmark. See `PATCH_SPEC_v0.3.29.md` and
`docs/FSM_ARCHITECTURE_AND_MIGRATION_v0.3.29.md`.

> The visual `.fsm` files remain architecture/reference diagrams. v0.3.29's live Platoon runtime uses
> the CBA state-machine clockwork. Section/Fireteam runtime migration comes after this test.

---


> **FSM Editor note:** The four ARTIC `.fsm` files in this corrected build include Bohemia FSM Editor decompile/layout metadata and should render as editable state graphs rather than an empty canvas.

# ARTIC AI v0.3.28-alpha — FSM Architecture Foundation

This branch adds the concrete `.fsm` hierarchy and Fireteam task contract discussed after the v0.3.27 pathfinding review. It is **disabled by default** and does not replace the current movement authority yet. See `docs/FSM_ARCHITECTURE.md` and `PATCH_SPEC_v0.3.28.md`.

# ARTIC AI v0.3.27-alpha — Corridor Movement + Dynamic Tactics Test Build

This build combines the next two architecture steps exposed by the 0.3.26 radar benchmark:

1. **Route execution must follow a safe corridor without repeatedly chasing exact control points.**
2. **A failed FIX/SBF plan must trigger a different tactical scheme, not an endless retry.**

Weapon-fire reliability is intentionally deferred until the platoon can first arrive, deploy,
choose a sensible tactic and launch it coherently.

## Route execution

The coloured Zeus route is the high-level ARTIC **PLAN**. Control points are now corridor gates,
not coordinates the guide must touch exactly. A gate is considered passed when the section enters
the corridor radius or crosses its forward plane toward the next gate.

Local metre-by-metre navigation remains Arma `calculatePath`. When debug markers are enabled,
ARTIC now draws that result separately as a white **LIVE NAV** route plus a NAV TARGET. This makes
it possible to distinguish a bad tactical plan from a bad engine nav path.

The route watchdog now re-plans only after roughly 35 seconds of real physical no-progress instead
of repeatedly throwing away a route when distance to one CP does not shrink. Long COA repositioning
also uses a faster transit pace than final deployment.

## Dynamic attack schemes

The platoon now selects both an attack axis and a scheme of manoeuvre:

- `SUPPORT_MANOEUVRE` — FIX + LEFT/RIGHT manoeuvre where a credible SBF exists.
- `DOUBLE_ENVELOPMENT` — BLOCK + LEFT + RIGHT when both safe flank corridors exist but useful SBF
  does not.
- `SINGLE_ENVELOPMENT` — BLOCK + one manoeuvre flank + reserve when only one safe flank exists.

The scheme selector scores actual safe approach routes. Absence of a useful SBF no longer makes the
whole attack impossible when terrain supports envelopment instead.

## Synchronization and reassessment

Envelopment uses a true READY / H-HOUR gate. Manoeuvre sections wait until the BLOCK element is in
position and, for double envelopment, synchronize each phase with the opposite flank. Suppression
score is required only by `SUPPORT_MANOEUVRE`.

Tactical failures are now explicit. Examples include:

```text
FIX_NO_LOS
FIX_SUPPRESSION_TIMEOUT
MANOEUVRE_ROUTE_FAILED
MANOEUVRE_SYNC_FAILED
BLOCK_NOT_READY
```

After the active plays finish, a new failure unlocks the otherwise stable battle plan and records the
failed scheme. The next review deliberately considers another tactic rather than immediately replaying
the same failure.

## What to look for in the RPT

Healthy planning / movement:

```text
TACTICAL ROLES scheme=...
Platoon ... REPOSITION_FOR_ATTACK ...
... deployment route planned ... corridor gate(s)
Platoon ... section deployment corridors ...
```

If local navigation differs from the coloured tactical route, the white LIVE NAV line should explain
what `calculatePath` is actually doing. Replanning should now be rare and appear as:

```text
CORRIDOR REPLAN physicalNoProgress=...
```

A support-plan failure should produce:

```text
Fixing element failed to establish useful sight; requesting platoon tactic change
TACTICAL REASSESSMENT: failure=FIX_NO_LOS failedScheme=SUPPORT_MANOEUVRE
TACTICAL ROLES scheme=DOUBLE_ENVELOPMENT: ...
```

An envelopment should then show READY/H-HOUR synchronization instead of waiting for FIX suppression.

## Test objective

Use the same Air Station benchmark. The key questions are:

1. Do PLAN and LIVE NAV clearly explain the route actually taken?
2. Do sections stop jinking around missed route points?
3. Is the long reposition noticeably faster and more direct?
4. If a valid SBF exists, does SUPPORT_MANOEUVRE deploy coherently?
5. If FIX cannot see or suppress, does the platoon reassess into an envelopment rather than stalling?
6. Do all elements report ready before a synchronized attack begins?

Reliable individual firing is deliberately the next test after these behaviours are proven.

Pack `source/artic_ai_core` unbinarized for the current test workflow.
