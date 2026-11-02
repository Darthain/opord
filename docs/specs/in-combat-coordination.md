> **Status: design spec, not implemented. Re-base before implementing.**
> The section-side contract (`ARTIC_adjustOrder`, `ARTIC_adjustAck`, `ARTIC_combatState`, the section combat
> state derived from `ARTIC_reactionState` / `ARTIC_contactAction`, and the suspend hooks in `moveSectionTactical`,
> `_waitPartner` and `groupStep`) was written for the v0.3 soldier layer. OPORD drops that individual layer: the
> bundled DCO fork (`addons/soldier`) now runs individual behaviour. Before implementation, re-base the contract
> and the section combat state on the bundled soldier layer (its suppression, morale and fighting-position state),
> and rename `ARTIC_` to `OPORD_`. The rest of the text below is the original, unchanged.
> Planned stage: 5 (infantry attack), with the vicinity sharing and fire deconfliction in stage 3 (information
> network). See "Port map" in `docs/PLAN.md`.

# ARTIC AI — Spec: In-Combat Coordination (v0.3.31)

Oct 3, 2026 · @Darth

## Purpose and problem

v0.3.31 lets a platoon adjust a running plan when its sections get engaged, instead of aborting and replanning the whole attack. It also shares contacts and friendly positions by proximity, not only within the platoon.

Today every disturbance after a plan is created ends the same way: the plan aborts and the platoon replans from scratch. The two Air Station benchmarks show the cost:

- **0.3.29:** 6 plans in about 9 minutes, 57 section failures, no assault, Alpha 1-2 reduced to one man.
- **0.3.30.1:** the plan lifecycle held (clean aborts, no ghost plays), but 3 plans in 5 minutes. The second plan died on the first close contact, and the reposition before it walked the platoon to within 63 m of the enemy.

After H-hour there is no response short of an abort. If one flanking section is pinned, its partner waits at the next phase gate, times out with MANOEUVRE\_SYNC\_FAILED, and the plan is thrown away. A real platoon commander in actions on contact shifts fire, holds one element, moves the support element or commits the reserve first, and only then rewrites the plan.

## Scope and non-goals

v0.3.31 covers three things for the attack schemes. Today those are SUPPORT\_MANOEUVRE, SINGLE\_ENVELOPMENT and DOUBLE\_ENVELOPMENT, and more will be added (see open items). Everything below therefore works from section roles (FIX, BLOCK, manoeuvre, reserve), not from scheme names, so new schemes get it without changes:

1. **Section combat state** that every section publishes and the platoon aggregates (the situation picture).
2. **An adjustment ladder** inside the platoon EXECUTE state (and READY\_CHECK where noted) that changes how the current plan is carried out without replacing it.
3. **Vicinity sharing** of enemy contacts and friendly positions across formations.

Not in this version:

- The full Section CBA state machine cutover. Plays receive adjustment orders through a small contract (see the section-side contract below); the state machine can adopt the same orders later.
- New attack schemes (planned separately; see open items), route planning changes or COA search changes.
- Defence, delay and recon tasks. They can use the situation picture later.
- Company-level coordination between platoons beyond vicinity sharing and fire deconfliction.
- The engine ATTACK-command conflicts (UNITCTRL CONFLICT cmd=ATTACK).

## Current state (v0.3.30.2)

ARTIC shares the enemy picture well and adjusts well before H-hour; it barely adjusts during execution and shares almost nothing about friendly sections.

| Mechanism | Scope | When it acts | Limitation |
| --- | --- | --- | --- |
| Commander intel loop (`fn_updateCommanderIntel`) | Ground contacts within the same formation; UAS contacts to every group; 90 s freshness | Continuously | Formation-bound: a neighbouring platoon 100 m away gets nothing unless a UAS saw it |
| Contact call (`fn_reportContact` → `fn_platoonContactResponse`) | Platoon | First contact or new enemy group, also during plays | One-shot per call; only enemy information travels |
| Contact replan | Platoon | Before H-hour, contact under 150 m | Whole-plan abort, the only lever |
| Contact-aware commitment (`fn_assessSectionContact`) | Platoon | At plan creation only | Not re-read once the plan runs |
| FIX / BLOCK fire redirect | Platoon | During plays | Only when the firing section can see the called contact |
| Assist call | Platoon | When a section calls contact | Only to sections not running a play, so nobody during an attack |
| Battle assessment refresh | Platoon | Every few seconds | Can withdraw assault authority; cannot redistribute effort |
| Partner phase gates (`_waitPartner`) | Two manoeuvre sections | Each stage | Only sees the partner's phase name; a timeout aborts the plan |
| BLOCK lift rule | Own platoon siblings | During BLOCK fire | The only use of friendly positions for fire control |

The gaps this spec closes:

- No record of each section's combat state (engaged by what, suppressed, pinned, casualties, progress) after plan creation.
- No response after H-hour other than abort.
- No contact or friendly-position sharing across formations.
- Assist and redirect depend on line of sight from a section that happens to be idle or in position.

## Section combat state (data contract)

Each section publishes one compact public variable, `ARTIC_combatState`, computed by its owner every 2 s inside `groupStep` (which already runs contact detection during plays since v0.3.30).

| Field | Type | Meaning | Source |
| --- | --- | --- | --- |
| `seq` | integer | Increments on every publish; the server never compares clocks | owner counter |
| `state` | enum | CLEAR, AWARE, ENGAGED, SUPPRESSED, PINNED, BROKEN (below) | derived |
| `threatDir` | degrees | Bearing to the main threat (the enemy firing on the section, else nearest known) | `findTarget`, contact call |
| `threatDist` | m | Distance to the main threat | same |
| `threatCount` | integer | Live enemies the section knows within 300 m | `targets`, shared contacts |
| `fit` | integer | Fit soldiers now | `isFit` |
| `fitAtTask` | integer | Fit soldiers when the current task started | captured at task start |
| `reacting` | 0..1 | Share of fit soldiers in an ARTIC individual reaction: SEEK\_COVER, RELOAD\_COVER or PINNED | `ARTIC_reactionState` (individual layer) |
| `pinnedShare` | 0..1 | Share of fit soldiers in the individual PINNED reaction (no useful cover found, gone prone) | same |
| `drill` | enum | The section's own contact drill step: REACT, DEVELOP, CHOOSE\_ACTION, EXECUTE, or none | `ARTIC_contactAction` |
| `progressSeq` | integer | Same counter as `ARTIC_deployProgressSeq`, now also bumped by movement legs | `markDeployProgress`, `moveSectionTactical` |
| `pos` | position | Section reference position | `ARTIC_sectionReferencePos` |

States, checked top to bottom (first match wins):

1. **BROKEN** — fewer than 3 fit, or fit below half of `fitAtTask`.
2. **PINNED** — SUPPRESSED, and either at least a third of fit soldiers are individually PINNED, or the current movement leg has made no progress for `ARTIC_pinnedSeconds` (20 s).
3. **SUPPRESSED** — at least half of fit soldiers are in an individual reaction (seeking cover, reloading in cover, or pinned).
4. **ENGAGED** — direct contact (soldier LOS or danger pulse) with a live enemy within 300 m.
5. **AWARE** — a live known enemy within 300 m, no direct contact.
6. **CLEAR** — none of the above.

The states are read from ARTIC's own individual reaction layer and contact drill, not from raw engine suppression, so a section's state matches what its soldiers are actually doing (review decision).

Publish rule: on a state change, a threat bearing change over 30°, a fit change, or a threat distance crossing 50 / 100 / 200 m; otherwise a heartbeat every 15 s. At most one publish per 2 s per section.

## Platoon situation picture

A new server function, `ARTIC_fnc_updatePlatoonSituation`, runs every platoon state machine tick in DEPLOY, READY\_CHECK and EXECUTE. It reads each section's `ARTIC_combatState` and keeps a `situation` hashmap on the platoon node, keyed by group ID. All timings below use the server's own clock, stamped when the server first sees a value change.

Per section it records the latest state plus:

- **stateSince** — server time the current state was first seen, so the ladder can ask "pinned for how long".
- **threatSide** — the threat bearing relative to the plan axis: FRONT (within 45° of the axis toward the enemy), LEFT, RIGHT or REAR.
- **casualties** — `fitAtTask` minus `fit`.
- **unknown** — true when `seq` has not changed for 30 s (locality change, headless client hiccup). An unknown section is never the basis of an adjustment.

Platoon-level flags derived from those:

| Flag | True when |
| --- | --- |
| `manoeuvreBlocked` | A manoeuvre section is PINNED during STAGE1, STAGE2 or ASSAULT\_READY |
| `flankThreat` | Any section is ENGAGED or worse with threatSide LEFT, RIGHT or REAR and threatCount 2 or more |
| `fixIneffective` | FIX has been firing (SUPPRESS) for 45 s and the manoeuvre sections are still SUPPRESSED or PINNED |
| `effortBroken` | A required section is BROKEN |
| `quiet` | No section ENGAGED or worse for 20 s |

On any change to a section state or a platoon flag, the server logs one line, for example `SITREP B1_PL Alpha 1-1=PINNED(RIGHT 85m, -2) Alpha 1-2=ENGAGED(FRONT 140m) Alpha 1-3=ENGAGED(FRONT 160m) flags=[manoeuvreBlocked]`. The plan's frozen roles and corridors are not touched by the picture itself; only the adjustment ladder acts on it.

## Adjustment ladder

After H-hour the platoon answers trouble with the cheapest adjustment that fits, escalates only if the trouble persists, and aborts only when the ladder is exhausted. A new server function, `ARTIC_fnc_platoonAdjust`, runs each EXECUTE tick after the situation picture updates; rung 1 also runs before H-hour.

*(Diagram: the 5-rung adjustment ladder — see the rung table below; the original diagram is in the doc.)*

Rungs 1 to 4 keep the plan ID and, for most sections, the task; only rung 5 aborts, and its replacement plan is contact-aware.

| Rung | Trigger (from the situation picture) | Order issued | Ends when | Limit |
| --- | --- | --- | --- | --- |
| 1. SHIFT\_FIRE | A section ENGAGED or worse by a threat that is not FIX's current target. Before H-hour: a deploying section engaged under 150 m | FIX, a READY / engaged BLOCK, or a section not running a play fires on the threat. With no line of sight: area fire on the reported position, if it passes deconfliction | That section is back to ENGAGED or better for 10 s, or 60 s pass | Re-issued freely. Before H-hour: a 20 s window, then the contact replan if still needed |
| 2. HOLD\_PHASE | `manoeuvreBlocked`: a manoeuvre section PINNED | Pinned section: REACT\_IN\_PLACE — its leg is suspended and its own contact drill takes charge (cover, return fire, or break contact back to its last stage point). Partner: hold at its current stage point; its partner-gate clock is suspended | Pinned section unpinned for 10 s, then both resume | `ARTIC_holdPhaseMaxSeconds` (90 s) |
| 3. CONVERT\_TO\_SUPPORT | Still PINNED after rung 2 has run 45 s, or a manoeuvre section BROKEN with 3 or more fit | The pinned section becomes SUPPORT\_IN\_PLACE (FIX play in CONTACT mode on its threat). The remaining flank closes to its assault position and assaults on the support handover (below) | Plan completes or aborts | Once per plan |
| 4. COMMIT\_RESERVE | A RESERVE section exists and `flankThreat`, `effortBroken`, or rung 3 fired | Reserve takes a FIX task on the threat from the nearest covered point with sight (search up to 50 m) | Plan completes or aborts | Once per plan |
| 5. ABORT\_AND\_REPLAN | Both manoeuvre sections PINNED or BROKEN; the only manoeuvre section BROKEN; no handover SET in time; or rung limits exhausted with the trigger still true | Existing abort path; the replacement plan is contact-aware | — | — |

Rules that hold across the ladder:

- One active order per section at a time. A higher rung replaces a lower one for the same section.
- A rung escalates only when its trigger is still true after the lower rung's minimum time (rung 1: 20 s, rung 2: 45 s).
- At most `ARTIC_maxAdjustmentsPerPlan` (4) orders of rung 2 or higher per plan; the next trigger after that goes to rung 5.
- Orders never change the plan ID. Only rung 3 and rung 4 change a task: the affected section gets a new task ID (for example `B1_PL_P3_SEC_1_A1`), so its old play ends quietly through `isPlayStale` and the new play starts. Every other section keeps its task.
- Every order is recorded in the plan's `adjustments` history and logged (see telemetry).
- Before H-hour only rung 1 runs, behind `ARTIC_preHHourShiftFire` so it can be benchmarked against the plain contact replan. A deploying section engaged under 150 m gets SHIFT\_FIRE first; the contact replan aborts the plan only if the section is still engaged after 20 s, becomes PINNED or BROKEN, or the contact is under 50 m.

With three sections there is usually no RESERVE (SUPPORT\_MANOEUVRE and both envelopments use all three), so rung 4 mostly matters for larger platoons.

### Support handover after CONVERT\_TO\_SUPPORT

The remaining flank does not assault alone the moment its partner converts. It closes to a position from which it can assault, and the two callsigns hand over by message:

1. The flank continues its stages to its assault position (ASSAULT\_READY / final coordination line) and holds there in cover.
2. While moving, the flank publishes `ETA` every 5 s: seconds to its assault position from the remaining route distance at `ARTIC_moveTimeoutPace`.
3. The support callsign times its fire to that ETA. It builds fire for effect once the ETA is at or under `ARTIC_handoverLeadSeconds` (30 s), and reports `SET` when its suppression estimate reaches the threshold the FIX gate uses today.
4. The flank assaults when it is in position and has `SET`. It calls `ASSAULTING`, and support lifts or shifts its fire.
5. No `SET` within `ARTIC_handoverSetTimeout` (60 s) of the flank arriving goes to rung 5.

This is the exchange the SUPPORT\_MANOEUVRE FIX gate does today, driven by messages instead of a fixed gate; the same handover can replace that gate in a later version.

## Section-side contract

Plays receive orders through one public group variable and answer through another, using the same plan/task identity check as `isPlayStale`.

- **Order:** `ARTIC_adjustOrder` = `[orderId, planId, taskId, kind, args]`. A play acts only on an order whose `planId` and `taskId` match its own; anything else is ignored.
- **Answer:** `ARTIC_adjustAck` = `[orderId, ACCEPTED | DONE | REJECTED, reason]`. No answer within 10 s counts as REJECTED, and the ladder escalates.

| Kind | Sent to | What the play does | Clock effect |
| --- | --- | --- | --- |
| FIRE\_ON | FIX, BLOCK in READY / ENGAGE, or a section not running a play | Fires on the given object, else area fire on the given position (generalises today's `ARTIC_fireRedirect`) | None |
| REACT\_IN\_PLACE | Pinned manoeuvre section | Suspends its play; the section's own contact drill and its soldiers' individual reactions take over (seek cover, return fire, or break contact back to the last stage point) | Leg deadline and no-progress watchdog paused |
| HOLD\_PHASE | Partner manoeuvre section | Stops at its current stage point in cover; may fire at visible enemies | Partner-gate clock paused |
| RESUME | Both of the above | Continue the suspended leg or gate | Clocks restart from where they paused |

The handover after CONVERT\_TO\_SUPPORT is section to section, not a platoon order. Each side writes `ARTIC_handover` = `[planId, fromGid, kind, value]` on its own group and reads the other's:

| Message | From → to | Value |
| --- | --- | --- |
| ETA | Flank → support | Seconds to the flank's assault position, every 5 s |
| SET | Support → flank | Fire for effect established |
| ASSAULTING | Flank → support | Assault started; support lifts or shifts |

Code changes this needs in the plays:

1. **`moveSectionTactical`** gets a suspend hook next to its stale check. While suspended, the deadline and the no-progress timer stop, so a 45 s hold cannot fail the leg.
2. **`_waitPartner`** pauses its deadline under HOLD\_PHASE, and treats a partner whose role is no longer a manoeuvre role as no partner (after rung 3).
3. **`groupStep`** lets the contact drill run while a play is suspended under REACT\_IN\_PLACE (today it exits as soon as a play is live), and hands control back to the play on RESUME.
4. **FIX and BLOCK fire loops** read FIRE\_ON in place of `ARTIC_fireRedirect`, and may area-fire on a position they cannot see if it passes deconfliction.
5. **`groupStep`** handles a new role, SUPPORT\_IN\_PLACE: the FIX play in CONTACT mode at the section's own position, aimed at its threat, which also answers ETA with SET.
6. **The manoeuvre play**, when its partner has converted, publishes ETA and waits at its assault position for SET before assaulting.

## Vicinity sharing

Contacts and friendly positions are shared with every friendly ARTIC group close enough to care, not only with the reporting platoon. All of it is built in the existing commander intel loop on the server.

**Enemy contacts.** Today a ground contact goes only to sections of the reporting formation (UAS contacts already go to everyone). In v0.3.31 a ground contact also goes to any friendly group whose reference position is within `ARTIC_vicinityShareRadius` (400 m) of the contact:

- tagged source VICINITY with the reporting formation, so the receiver knows it is second-hand;
- confidence multiplied by 0.6;
- can mark a receiving section CLOSE, so it is committed in place in its platoon's next plan (review decision), but never starts a plan or a contact replan on its own;
- still never passed to the engine with `reveal`, to avoid the vanilla ATTACK orders that rule exists to prevent.

A contact call is relayed the same way: the server forwards it to other formations' sections inside the radius, with one log line per relay.

**Friendly positions.** The server keeps a friendly picture of every ARTIC group: group ID, formation, reference position, role, combat state and current leg destination. Each group receives `ARTIC_nearFriendlies`, the entries within `ARTIC_friendlyShareRadius` (600 m), refreshed every 5 s and republished only when an entry moves more than 25 m or changes state. Fire control (next section) reads it on the group's own machine, which matters for headless-client sections.

Cost is a pairwise check over ARTIC groups every 5 s; for a company-sized mission (about 15 groups) that is roughly 225 distance checks per cycle.

## Fire deconfliction

One check, `ARTIC_fnc_isFireSafe [shooterPos, aimPos, group]`, gates every aimed or area fire order from FIX, BLOCK, SUPPORT\_IN\_PLACE and `suppressElement`. It replaces BLOCK's private lift rule so all fire uses the same limits.

Fire at a point is refused when any of these holds:

1. **Danger close.** A friendly soldier of the shooter's own platoon is within `ARTIC_fireSafetyDistance` (60 m) of the aim point, or another formation's group reference position is within that distance plus 30 m (positions from `ARTIC_nearFriendlies`).
2. **Line of fire.** The line from shooter to aim point passes within 15 m of an own-platoon soldier, or within 40 m of another formation's group reference position.
3. **Unseen and uncertain.** Area fire on a position the shooter cannot see needs a contact report under 60 s old with confidence 0.5 or more (VICINITY-only reports never qualify), and an aim point within 250 m.

Lift and shift: when a friendly manoeuvre section in STAGE2, ASSAULT\_READY or ASSAULT has its leg destination within 60 m of the aim point, the firing section shifts its aim 40 m beyond the objective along its line of fire if that point passes the check, otherwise stops firing on it. FIX keeps its existing lift at ASSAULT.

Every refusal is counted per firing section and logged at most once per 30 s, so a benchmark shows how often deconfliction is stopping fire.

## Telemetry

New RPT lines, so a benchmark can be read without screenshots:

| Marker | Example | When |
| --- | --- | --- |
| `SITREP` | `SITREP B1_PL Alpha 1-1=PINNED(RIGHT 85m, -2) Alpha 1-2=ENGAGED(FRONT 140m) flags=[manoeuvreBlocked]` | Any section state or platoon flag change |
| `ADJUST` | `ADJUST plan=B1_PL_P3 #2 HOLD_PHASE -> Alpha 1-2 (partner Alpha 1-1 PINNED 22s)` | Order issued |
| `ADJUST ACK` | `ADJUST ACK plan=B1_PL_P3 #2 Alpha 1-2 ACCEPTED` | Section answers, or 10 s timeout as REJECTED |
| `ADJUST END` | `ADJUST END plan=B1_PL_P3 #2 RESUME (Alpha 1-1 unpinned 10s)` | Order resolved |
| `ADJUST ESCALATE` | `ADJUST ESCALATE plan=B1_PL_P3 Alpha 1-1 HOLD_PHASE -> CONVERT_TO_SUPPORT (pinned 47s)` | Rung change |
| `REACT_IN_PLACE` | `Alpha 1-1 REACT_IN_PLACE: leg suspended, contact drill REACT -> BREAK_CONTACT to stage 1` | Pinned section's own drill decision |
| `HANDOVER` | `HANDOVER Alpha 1-2 ETA 28s -> Alpha 1-1` / `HANDOVER Alpha 1-1 SET` / `HANDOVER Alpha 1-2 ASSAULTING` | Each handover message |
| `VICINITY` | `VICINITY contact from B1_PL relayed to B2_PL (Bravo 1-1 at 310m)` | Cross-formation relay |
| `FIRE SAFE REFUSED` | `FIRE SAFE REFUSED Alpha 1-3 aim 043038: danger close Alpha 1-1 (42m)` | Deconfliction refusal, max once per 30 s per section |

The existing `FSM PLAN ABORT` line gains the ladder history, for example `… after adjustments [SHIFT_FIRE, HOLD_PHASE, CONVERT_TO_SUPPORT]`.

## Settings

All `isNil`-guarded in `fn_preInit`, like the existing settings. The master switches let each part be benchmarked on its own.

| Variable | Default | Meaning |
| --- | --- | --- |
| `ARTIC_situationPicture` | true | Sections publish `ARTIC_combatState`; platoon aggregates it |
| `ARTIC_adjustLadder` | true | Run the adjustment ladder (needs the picture) |
| `ARTIC_preHHourShiftFire` | true | Try SHIFT\_FIRE before the contact replan aborts a plan; false = v0.3.30.2 behaviour, for A/B runs |
| `ARTIC_vicinitySharing` | true | Cross-formation contact and friendly sharing |
| `ARTIC_pinnedSeconds` | 20 | Suppressed (by ARTIC reactions) with no leg progress this long = PINNED |
| `ARTIC_combatStateHeartbeat` | 15 | Seconds between unchanged publishes |
| `ARTIC_holdPhaseMaxSeconds` | 90 | Longest HOLD\_PHASE / REACT\_IN\_PLACE before escalation |
| `ARTIC_handoverLeadSeconds` | 30 | Support builds fire for effect when the flank's ETA is at or under this |
| `ARTIC_handoverSetTimeout` | 60 | Flank in position this long without SET goes to rung 5 |
| `ARTIC_maxAdjustmentsPerPlan` | 4 | Orders of rung 2 or higher per plan before abort |
| `ARTIC_adjustAckTimeout` | 10 | Seconds before an unanswered order counts as REJECTED |
| `ARTIC_vicinityShareRadius` | 400 | Ground contacts shared to groups within this of the contact |
| `ARTIC_friendlyShareRadius` | 600 | Friendly picture radius per group |
| `ARTIC_fireSafetyDistance` | 60 | Danger-close distance; replaces `ARTIC_blockLiftDistance` |

## Phasing and pass conditions

Build in four steps, each benchmarked on Air Station before the next, so a bad threshold is found before anything acts on it.

1. **Picture only (v0.3.31-a).** Combat state, situation picture, SITREP lines. No behaviour change.
   - Pass: SITREP states match what you see on screen at the first contact, the first pinned section and the assault; no section stays `unknown` while alive and local.
2. **Rungs 1–2 and fire safety (v0.3.31-b).** SHIFT\_FIRE (including before H-hour), HOLD\_PHASE / REACT\_IN\_PLACE, the suspend hooks in `moveSectionTactical`, `_waitPartner` and `groupStep`, and `isFireSafe`.
   - Pass: no MANOEUVRE\_SYNC\_FAILED or MANOEUVRE\_ROUTE\_FAILED while an ADJUST order is active; every order gets an ACK; no fire on a point within 60 m of a friendly soldier.
   - A/B: two runs with `ARTIC_preHHourShiftFire` on and off; keep it on only if it means fewer plans per attack without more casualties before H-hour.
3. **Rungs 3–5 and the handover (v0.3.31-c).** CONVERT\_TO\_SUPPORT with the ETA / SET / ASSAULTING handover, COMMIT\_RESERVE, the escalation rules and abort with history.
   - Pass: a pinned flank converts to support, the other flank reaches its assault position, gets SET and assaults at least once in the run; aborts after H-hour show their ladder history.
4. **Vicinity sharing (v0.3.31-d).** Needs a two-platoon test mission.
   - Pass: a contact reported by one platoon appears in the other's shared picture within 5 s when inside 400 m; a VICINITY contact can commit a section in the next plan but never starts a plan or contact replan on its own.

Overall target against 0.3.30.1: fewer plans per attack (it took 3 in 5 minutes) and at least one assault reaching `FSM SECTION COMPLETE`.

## Review decisions and open items

Decisions from the first review, already applied above:

| Question | Decision | Applied in |
| --- | --- | --- |
| Ladder before H-hour | SHIFT\_FIRE first; the contact replan aborts only if the section is still engaged after 20 s, becomes PINNED or BROKEN, or the contact is under 50 m. Behind `ARTIC_preHHourShiftFire` for an A/B run, since this one is uncertain | Adjustment ladder, Settings, Phasing |
| PINNED threshold | Read from ARTIC's own individual reactions and contact drill, not engine suppression. A pinned section runs its own drill (cover, return fire, break contact) under REACT\_IN\_PLACE | Section combat state, Section-side contract |
| Rung 3 timing | The remaining flank closes to its assault position and assaults on a support handover: ETA, then SET, then ASSAULTING | Support handover |
| VICINITY and commitment | Yes: a VICINITY report can mark a section CLOSE for its next plan | Vicinity sharing |
| Cross-formation precision | Group reference positions plus 30 m is fine | Fire deconfliction |

Still open:

- [ ] **More attack schemes.** The current three are not enough and more will be added. Candidates from doctrine to scope later: frontal attack, penetration, infiltration, turning movement, attack by fire, raid, ambush, and the hasty attack from contact. Each new scheme must declare which section fills which role (FIX, BLOCK, manoeuvre, reserve) so the situation picture, ladder and handover apply to it unchanged.
- [ ] **Moving the support element.** Rebounding FIX to a new SBF mid-fight needs route and SBF search. Leave it for a later version?
- [ ] **Reserve.** Do your missions field a fourth section or weapons team that could act as reserve? (See the comment in the ladder section.)
- [ ] **Formation quality.** You reported that section formations have become disorganised and poor. That is outside this spec, but the situation picture relies on section reference positions and on sections holding together, so it should be looked at before or alongside phase 1. An RPT plus a note of when it shows (march, deployment, under fire) would pin it down.
