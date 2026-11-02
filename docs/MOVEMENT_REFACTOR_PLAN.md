# ARTIC AI — v0.3 movement refactor plan

This sequence exists to finish the tactical-execution foundation before v0.4 adds a deeper per-soldier combat brain. Each step is benchmarked against the fixed regression missions in `BENCHMARKS.md`.

## v0.3.16 — Spatial ownership consolidation (this build)

Goal: make the current platoon attack use one continuous spatial reference from approach to combat.

- preserve the section guide through approach -> contact -> tactical handover;
- prevent long-range contact from cancelling the planned section routes before HOLD/release;
- treat section guide, desired fireteam guides and soldier slots as the active hierarchy;
- retire the old live majority-cluster anchor governor from the normal platoon benchmark path;
- keep legacy `moveElement` / old anchor helpers only for older standalone tactics until they are migrated;
- replace unitless/global-scaled formations with bounded real-metre templates;
- keep CMD/MEDIC/2IC inside the formation envelope;
- gate formation changes to route/control-point windows except urgent contact states;
- reject/hold a planned assault when no useful support-by-fire position can see the known enemy;
- make reload-cover predictive and remove explicit forced `reload` calls that produced weapon/muzzle errors;
- emit movement/attack/SBF/cohesion metrics and periodic locality/performance telemetry.

Exit signal: the OPEN benchmark no longer produces routine 100-400 m section dispersion or a movement-owner reset at tactical release.

## v0.3.17 — Tactical element-guide migration

Goal: remove the last compatibility movement path from active infantry tactics.

- migrate remaining standalone tactics from `moveElement` private destinations to persistent element/fireteam guides;
- represent support, manoeuvre and reserve elements as guide-owned tactical elements;
- make fighting withdrawal, standalone suppress-and-flank and other older tactics use the same slot hierarchy;
- delete/disable the old `sectionAnchor` / `fireteamAnchorA/B` governor once no active tactic requires it;
- add explicit movement-owner assertions so two systems cannot own the same soldier in one scheduler tick.

Exit signal: no active infantry tactic in the benchmark suite calls the legacy movement governor.

## v0.3.18 — Terrain-plan fidelity

Goal: make a good debug plan correspond to a physically executable plan.

- strengthen section-route corridor enforcement;
- score whole routes, not only control points, for slope, masking, exposure, cover and crossing conflicts;
- improve urban/village routing so fences, walls, compounds and streets do not destroy formation cohesion;
- require FIX/SBF quality thresholds before manoeuvre release;
- re-plan invalid SBF/assault geometry instead of repeatedly timing out;
- expand debug to show planned vs actual guide tracks and corridor violations.

Exit signal: planned FIX/LEFT/RIGHT routes are followed within corridor tolerances in OPEN, WOODS and VILLAGE benchmarks.

## v0.3.19 — Regression / HC / performance gate

Goal: prove the tactical foundation is stable enough to receive the v0.4 individual brain.

- run each fixed v0.3 benchmark at least five times;
- compare SBF success/time, move failures, slot error and attack completion against the gate in `BENCHMARKS.md`;
- run the 150-AI dedicated-server + HC 30-minute soak;
- exercise locality transfer while groups are moving;
- fix recurring locality errors, duplicate ownership and orphaned plan state;
- profile the most expensive per-frame/per-unit searches before adding more individual reasoning.

Exit signal: v0.3 benchmark and performance gates pass consistently.

## v0.3.20 — v0.3 release candidate / freeze

Goal: freeze the tactical-execution interfaces used by v0.4.

- only stabilization, diagnostics and benchmark regressions;
- document public movement/task interfaces;
- freeze battle-context, guide, tactical-element and individual-task contracts;
- no new tactical feature families unless required to satisfy the exit gate.

Once this candidate passes, development moves to v0.4: individual combat brain, basic morale, casualty drills and basic urban competence.
