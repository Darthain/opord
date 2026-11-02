# ARTIC AI Roadmap (revised at v0.3.16)

## Development rule: every phase has an exit gate
ARTIC does not advance because a feature exists; it advances when fixed regression missions show that the feature works repeatedly. See `BENCHMARKS.md`.

A performance/locality gate also runs at the end of every phase. Large-scale MP/HC work is not deferred to v1.0.

---

## v0.3.x — Tactical execution foundation (CURRENT)
Goal: one infantry platoon can approach, establish a battlefield, attack, consolidate and repeat without movement ownership collapsing.

Core scope:
- persistent battlefield context from objective / ground / UAS intelligence;
- platoon RELEASE / HOLD / PLD / SBF / ASSAULT / FCL / LOA control measures;
- persistent FIX / LEFT / RIGHT / RESERVE role assignment;
- terrain-informed section routes and corridors;
- one guide hierarchy: platoon -> section -> fireteam -> soldier slot;
- stable formations with role-aware slots;
- normal travel vs tactical approach vs combat movement;
- direct-fire sector ownership;
- shared tactical picture without making UAS intelligence equal direct contact;
- basic threat-relative cover and pre-emptive reload-cover behaviour;
- recon UAS / FPV / basic fires integration;
- debug plan + live guide visualisation;
- benchmark telemetry in RPT.

### v0.3.16 — Movement consolidation refactor
- preserve section guide across approach -> contact -> play handover;
- retire live majority-cluster anchors from active formation movement;
- formation templates use bounded real-metre geometry;
- protected roles stay inside the formation envelope;
- early/long-range contact does not automatically cancel the platoon approach;
- SBF positions with effectively zero enemy visibility are rejected / replanned;
- predictive reload-cover begins before the weapon is completely empty;
- formation changes are rate-limited and preferentially occur at control points;
- live section / FT guide markers and regression metrics.

### v0.3 refactor sequence

- **v0.3.16:** spatial ownership consolidation and persistent guide handover.
- **v0.3.17:** migrate remaining tactical elements away from legacy `moveElement`/majority-cluster movement.
- **v0.3.18:** terrain-plan fidelity and hard corridor/route validation.
- **v0.3.19:** fixed benchmark suite plus 150-AI server/HC performance-locality gate.
- **v0.3.20:** stabilization/release candidate and interface freeze before v0.4.

See `MOVEMENT_REFACTOR_PLAN.md` for the detailed versioned plan.

### v0.3 exit criteria
See `BENCHMARKS.md`. In short: repeatable SBF occupation, low move timeout/regroup rate, bounded slot error, acceptable attack completion rate, and no persistent 100m+ section fragmentation.

---

## v0.4 — Individual combat brain + basic morale
Goal: individuals react intelligently to danger without abandoning parent intent.

- persistent individual combat state;
- threat prioritisation;
- exposure / multi-shooter awareness;
- threat-relative hard-cover choice;
- FiredNear / Hit / explosion response;
- stance choice and short tactical repositioning;
- predictive reload / ammunition-state decisions;
- pinned / suppressed / rally states;
- grenade reaction and grenade employment rules;
- casualty awareness;
- target quality / incapacitated filtering;
- local initiative bounded by fireteam/section intent;
- **basic morale model moved forward here:** cohesion shock, casualties, suppression, leadership/training effects, break/rally thresholds;
- **casualty drills:** care-under-fire -> extract to cover -> treatment handoff; full medical priority/sustainment stays later;
- **basic urban competence:** doors/streets/buildings should not destroy formation routing or cover behaviour.

### DCO study
Use the same clean-room approach as LAMBS: inspect how DCO solves relevant problems, document behaviour and interfaces, then implement ARTIC-native logic. Do not copy code/assets unless licensing and attribution explicitly permit it.

---

## v0.5 — Tactical library expansion
Goal: tactics become reusable combinations of the same movement/fire/individual primitives.

- contact drill;
- hasty and deliberate attack;
- frontal attack;
- suppress and flank;
- single / double envelopment;
- section/fireteam assault;
- recon attack;
- raid;
- ambush: annihilation / harassment / containment;
- break contact;
- fighting withdrawal;
- delay;
- counterattack;
- screen / guard / observe;
- consolidation / reorganisation;
- **offensive static-weapon employment:** backpack HMG / mortar / crew-served weapon deployment into SBF positions;
- tactics expose generic element capabilities rather than assuming every element is infantry, preparing for vehicles later.

---

## v0.6 — Doctrine and training depth
- CONVENTIONAL;
- INSURGENT;
- MILITIA;
- RECON;
- POSITIONAL;
- SPECIAL_FORCES;
- POOR / REGULAR / VETERAN / ELITE execution differences;
- commander aggression / caution / initiative / adaptability;
- morale thresholds and recovery modified by doctrine/training.

Doctrine determines preference; training determines execution quality; morale determines willingness/cohesion.

---

## v0.7 — Defence, engineering and static weapons
- simple/complex battle positions;
- primary / alternate / supplementary positions;
- GRAD trench integration;
- camouflage / Pook nets;
- static weapon emplacement and relocation;
- obstacles / mines / IEDs / safe lanes;
- reverse-slope defence;
- reserve / counterattack positions;
- deception / dummy positions;
- fallback / withdrawal plans.

---

## v0.8 — Commander / ORBAT depth
- battalion/task force -> company -> platoon -> section hierarchy;
- objectives / sites / AO / dynamic frontline;
- task organisation and temporary attachments;
- reserves / QRF;
- support allocation by echelon;
- command degradation / HQ or RTO loss;
- last-order continuation and initiative.

---

## v0.9 — Fires, UAS and support depth
- mortars / artillery / smoke / illumination;
- CAS;
- UAS reconnaissance / target handoff / adjustment / BDA;
- AP / AT FPV and droppers;
- support priorities and deconfliction;
- danger-close and fire-shift control;
- physical ammunition and provider state.

---

## v0.10 — Vehicles and mechanised combat
Vehicle support is designed into tactical element interfaces from v0.5 onward so this is an extension, not a rewrite.

- mounted / dismounted movement;
- vehicle formations;
- convoy logic;
- mechanised approach / dismount points;
- IFV / armour SBF and overwatch;
- infantry-vehicle coordination;
- AT / armour threat reactions;
- recovery and vehicle casualty logic.

---

## v0.11 — Full urban / complex terrain tactics
- street / alley routing;
- covered crossings;
- building assignment;
- breach / enter / clear / consolidate;
- rooftop / upper-floor threats;
- urban SBF;
- strongpoint attack/defence;
- urban mechanised integration.

---

## v0.12 — Sustainment, advanced morale and persistence
- ammunition / fatigue / supply state;
- full medical priorities and evacuation;
- repair / refuel / rearm;
- unit reorganisation after contact;
- degraded formations;
- surrender / panic / rally depth;
- persistent battlefield and logistics state.

---

## v1.0 — Hardening / release
- optimisation and long-duration soak tests;
- CBA settings;
- server / HC scaling and failover;
- Zeus / Eden workflow;
- diagnostics and documentation;
- compatibility matrix;
- optional-mod failure safety;
- signed / binarised release pipeline.

## Running performance / MP gate (every milestone)
At the end of each phase, run a 150-AI server+HC scenario for at least 30 minutes. Track:
- server and HC FPS against an equivalent no-ARTIC baseline;
- duplicate plans / locality errors / remote-exec errors;
- groups changing owner during active movement;
- orphaned guide/task state after locality transfer;
- RPT script errors;
- per-group decision-loop frequency and benchmark metrics.

Target: no more than ~15% sustained simulation-FPS loss against the same scenario without ARTIC, zero recurring locality/script errors, and no duplicated tactical ownership after transfer.
