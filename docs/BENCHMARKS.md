# ARTIC AI Regression Benchmarks

ARTIC v0.3 onward is judged with fixed missions rather than one-off visual impressions.

## Core v0.3 test set
Run each mission **5 times** for a candidate build.

1. **OPEN** — Stratis open hillside/radar attack, daylight.
2. **WOODS** — close-country approach with masked routes and short sight lines.
3. **VILLAGE** — movement through streets/buildings before a platoon attack. This is not full urban combat; it is a basic routing/cohesion gate.
4. **NIGHT** — same force sizes with reduced visibility and tighter formations.

Keep force composition, placements and objective geometry fixed between versions where possible.

## v0.3 measurable exit criteria
These are initial engineering targets and may be tightened once several baselines exist.

### Support-by-fire
- valid SBF established in >= 80% of OPEN/WOODS runs and >= 70% of VILLAGE/NIGHT runs when terrain provides a feasible position;
- median time from tactical release to `fixReady` <= 60 s;
- 90th-percentile SBF establishment <= 90 s;
- an SBF with <10% known-enemy visibility must not be accepted as assault-ready.

### Movement / cohesion
- tactical guide move failure rate <= 10%;
- mean soldier-to-assigned-slot error <= 8 m OPEN/WOODS and <= 10 m VILLAGE/NIGHT while moving;
- no fit soldier remains >100 m from his assigned section guide/slot for >10 s unless an explicit danger/casualty state explains it;
- no section enters a sustained 150m+ dispersion state;
- formation-regroup events trend downward between candidate builds and do not repeat indefinitely for the same phase.

### Attack outcome
For scenarios where ARTIC assesses `assaultAllowed=true` and friendly combat power >= 1.5x assessed enemy power:
- >=70% of attacks complete the planned assault/consolidation sequence rather than aborting due to movement failure;
- aborted attacks must produce an explicit reason in RPT.

### Spatial-plan fidelity
- FIX / LEFT / RIGHT guides remain in their assigned battlefield corridor unless the plan explicitly replans;
- tactical release occurs at/near the release/HOLD area, or because an explicit emergency-contact criterion is met;
- platoon section routes remain distinguishable and sections do not intermingle before the assault phase.

## RPT telemetry
v0.3.16 emits periodic lines like:

`METRICS slotAvg=... slotMax=... moves=completed/attempted moveFail=... sbf=success/attempts attacks=completed/attempted abort=...`

For candidate comparisons record:
- slotAvg / slotMax;
- movesCompleted / movesAttempted / movesFailed;
- average move duration (`moveSeconds / movesAttempted` when inspected from group state);
- sbfSuccess / sbfAttempts and SBF establishment time;
- attacksCompleted / attacksAttempted / attacksAborted;
- casualties as context, not as the only success measure.

## Performance / locality regression
At the end of each milestone:
- 150 AI total across dedicated server + at least one HC;
- 30-minute soak;
- compare server/HC FPS with an equivalent no-ARTIC run;
- inspect RPT for script errors, locality errors, duplicated plan execution and orphaned groups;
- force at least one ownership/locality transfer during movement if practical.

Initial target: <=15% sustained simulation-FPS penalty versus the matched baseline, with no recurring locality errors or duplicate tactical ownership.
