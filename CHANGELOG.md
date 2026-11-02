## v0.3.30.2-alpha — Reassessment safety

From the 0.3.30.1 Air Station run: a BLOCK failure mislabelled TIMING triggered a "retry" that re-searched every
axis, flipped the attack 177° and marched the platoon in FILE straight through the objective (contact at 63–76 m).
See `PATCH_SPEC_v0.3.30.2.md`.

- COA search rejects axes whose reposition march passes within 150 m of known enemy (`ARTIC_repositionStandoff`).
- TIMING retries keep the failed plan's axis (`lastFailedAxis`); full search only if that axis is no longer feasible.
- READY_CHECK counts occupation progress via `ARTIC_deployProgressSeq` (`ARTIC_fnc_markDeployProgress`).
- BLOCK searches up to 60 m forward for an observation line (80 m standoff) before `BLOCK_NO_LOS`.
- Contact replan also covers FIX/BLOCK sections still marching to their positions.
- Version strings unified at 0.3.30.2-alpha; role log no longer shows the superseded plan ID.

# v0.3.30.1-alpha

- Added authoritative section task lifecycle keyed by immutable `planId + taskId`.
- Added terminal `FAILED`, `ABORTED`, and `COMPLETE` states with rejected reverse transitions.
- Added identity-safe stale-play cleanup (`fn_endPlayQuietly`) so superseded scripts cannot reset a replacement task.
- Added shared play-liveness helper using both `ARTIC_currentPlan` and the actual `ARTIC_playHandle`.
- Plan failure now terminally aborts child tasks and waits for matching handles to settle before supersession.
- Added one-time H-hour consumption per manoeuvre task.
- Added task-aware stale event validation and missing-required-section failure guard.
- Assist suppression now uses the section play handle and stops when its task becomes stale.
- Retained v0.3.30 tactical/navigation behaviour unchanged for clean A/B testing.

# ARTIC AI changelog

## v0.3.30-alpha — Plan lifecycle, platoon-owned readiness, contact-aware replanning

Built on v0.3.29 after the Air Station benchmark (6 plans in ~9 min, 57 section failures, no assault).
See `PATCH_SPEC_v0.3.30.md` and `docs/PLATOON_STATE_MACHINE.md`.

- Fixed manoeuvre gates (FIX, BLOCK, H-hour) that used `exitWith` inside `if/then` blocks and so kept
  running after reporting failure: duplicate H-hour lines, superseded plans executed, movement before H-hour.
- Added play identity (`ARTIC_fnc_isPlayStale`): FIX/BLOCK/manoeuvre plays end quietly when their task is
  replaced, their plan is aborted or execution authority is withdrawn. Movement legs abort with them.
- groupStep tracks plays by script handle (`ARTIC_playHandle`); a second copy can no longer start.
- First failure of a plan aborts all its plays (`ARTIC_fnc_recordPlatoonFailure`, `ARTIC_planAbortId`), so
  REASSESS follows in seconds; supersession uses the root-cause failure. FIX and BLOCK now report failures.
- Movement legs: distance-scaled deadline (1.1 m/s), extended while closing, early `NO_PROGRESS` after 40 s.
- READY_CHECK owns readiness: waits while required sections progress; fails after 45 s without progress
  (min 60 s) or 300 s, naming the section holding the platoon. Sections no longer run BLOCK 18 s / FIX 70 s clocks.
- Failure classes TIMING / CONTACT / TACTICAL; a first TIMING failure retries the same scheme.
- Contact-aware replanning: ENGAGED / CLOSE sections are committed in place; the best placed fixes where
  it stands (`sbfMode CONTACT`, opens fire immediately); no deployment march or platoon march slot for
  committed sections; manoeuvre contact < 150 m before H-hour aborts the plan (`CONTACT_ON_DEPLOYMENT`).
- FIX sustains fire: retargets or area-fires when a target drops, lifts when a manoeuvre section assaults,
  and is not restarted under the same task.
- Contact detection / contact calls now run for sections executing a play.
- New BLOCK play: fire line facing objective and withdrawal lanes, lane watchers, READY only when occupied
  and observing, hold fire until H-hour, lift within 60 m of friendly manoeuvre.
- Contact response: BLOCK can take fire redirects; assist calls only go to sections not running a play.
- Plan creation resets per-plan phase latches (a stale partner `ABORT` broke the next plan's sync).
- New settings: `ARTIC_readyMinSeconds`, `ARTIC_readyNoProgressTimeout`, `ARTIC_readyCheckMaxSeconds`,
  `ARTIC_moveTimeoutPace`, `ARTIC_moveNoProgressSeconds`, `ARTIC_fixFireMaxSeconds`, `ARTIC_blockMaxSeconds`,
  `ARTIC_blockLiftDistance`, `ARTIC_contactAwareReplan`, `ARTIC_contactReplanDistance`,
  `ARTIC_engagedDistance`, `ARTIC_closeContactDistance`; `ARTIC_hHourReadyTimeout` 90 -> 390.
- New telemetry: `FSM PLAN ABORT`, `FSM READY_CHECK timeout`, `CONTACT REPLAN`, `CONTACT-AWARE PLAN`,
  `RETRY_AFTER_TIMING_*`, `play ended`, `FIX target down`, `FIX lifting fire`, `BLOCK READY`, `BLOCK opening fire`.

## v0.3.29-alpha — Live CBA Platoon FSM + immutable plan ownership

- Enabled the first live CBA state-machine layer for platoons.
- Added `PlatoonPlan` V1 with unique plan/revision IDs and frozen section role/corridor/task ownership.
- Added server-side CBA READY and failure event handling.
- Moved H-hour ownership to the Platoon state machine; manoeuvre sections now wait for their plan ID.
- Added section task IDs and terminal completion latches so a completed manoeuvre cannot restart under the same plan.
- Added failure-driven `REASSESS -> SUPERSEDED -> replacement plan` lifecycle.
- Cleared consumed failure latches at supersession so stale failures cannot poison a new plan.
- Prevented hasty-contact cleanup from restoring old roles over an active immutable PlatoonPlan.
- Retained v0.3.27 corridor/local movement for this migration phase; navigation rewrite, Section/Fireteam runtime and reliable firing remain later phases.
- Added explicit FSM telemetry: `FSM PLAN CREATED`, `PLATOON CBA FSM`, `FSM SECTION READY`, `FSM H-HOUR`, `FSM SECTION FAILED`, `FSM PLAN SUPERSEDED`, `FSM SECTION COMPLETE`.

## v0.3.28-alpha — FSM architecture foundation

- Added scripted Commander, Platoon, Section and Fireteam FSM files.
- Added a network-safe Fireteam Task V1 schema and helper functions.
- Added opt-in FSM start/condition/state telemetry functions.
- FSM hierarchy is disabled by default to avoid competing with v0.3.27 movement ownership before integration.
- Added `docs/FSM_ARCHITECTURE.md` with exact task fields and transition contracts.


## v0.3.27-alpha — Corridor movement, dynamic attack schemes, tactical reassessment

This build combines the two problems exposed by the 0.3.26 Air Station test: sections
were physically wandering/jinking around high-level route markers, and the platoon could
only express FIX + LEFT + RIGHT even after FIX repeatedly failed to obtain LOS.

### Corridor-based route execution
- Battle routes are now treated as **corridor gates**, not exact points the section must
  touch. A section advances a gate when it enters a configurable corridor radius or crosses
  the gate plane toward the next gate.
- Replanning is based on **physical section movement**, not merely failure to reduce distance
  to one control point. Default no-progress timeout is 35 s. This removes repeated 15 s
  route churn and unnecessary turn-back/jinking around rocks and vegetation.
- `calculatePath` remains the local navigation layer. Its live path is now exported for
  debug separately from the tactical PLAN line.
- Reposition and deployment have explicit movement phases and faster guide paces:
  `ARTIC_repositionPace = 2.7`, `ARTIC_deployPace = 2.1`.
- Revised v0.3.23 route safety is retained: LEFT/RIGHT detours preserve lane ownership,
  slope is checked, and enemy exclusion routing stays on the safe side.

### Dynamic schemes of manoeuvre
- Added `ARTIC_fnc_selectAttackScheme`. The platoon now chooses a **scheme as well as an
  axis**.
- `SUPPORT_MANOEUVRE`: FIX + manoeuvre element(s), used when a credible SBF exists.
- `DOUBLE_ENVELOPMENT`: BLOCK + LEFT + RIGHT, used when both safe flank approaches exist
  but no credible SBF does.
- `SINGLE_ENVELOPMENT`: BLOCK + one manoeuvre flank + reserve, used when only one safe
  flank exists.
- SBF failure no longer means the platoon must keep inventing another SBF forever.

### Tactical reassessment
- Tactical scripts publish formal failure reasons such as `FIX_NO_LOS`,
  `FIX_SUPPRESSION_TIMEOUT`, `MANOEUVRE_ROUTE_FAILED`, `MANOEUVRE_SYNC_FAILED`, and
  `BLOCK_NOT_READY`.
- Once local plays finish, a fresh failure unlocks the otherwise stable battle plan. The
  failed scheme is remembered and the next review deliberately considers an alternate
  tactic instead of immediately replaying the same one.
- Envelopment schemes use a synchronized READY / H-HOUR gate. BLOCK must be in position
  before manoeuvre sections move; double envelopment keeps LEFT and RIGHT phase-synchronized.
- Suppression score is a gate only for `SUPPORT_MANOEUVRE`; envelopment does not wait for a
  fictional FIX suppression threshold.

### Debugging
- Coloured `PLAN` routes continue to show ARTIC tactical intent.
- White `LIVE NAV` routes show the current `calculatePath` result actually followed by the
  section guide, with a separate NAV TARGET marker.
- New RPT markers include `TACTICAL ROLES`, `TACTICAL REASSESSMENT`, scheme selection reason,
  `CORRIDOR REPLAN`, READY/H-HOUR synchronization, and route-quality diagnostics.

### Scope intentionally deferred
- Reliable weapon employment (`doFire` / suppression cadence / per-weapon fire control) is
  intentionally **not** the focus of this build. The test target is: sensible routes, a
  tactically appropriate scheme, synchronized launch, and a real alternate tactic after
  failure.

## v0.3.26-alpha — Attack authorisation: fire-line SBF planning

This build deliberately changes the **decision to attack**, not weapon employment.
`fn_sectionReactFire.sqf`, `doFire`, suppression cadence and individual engagement behaviour
are left for the next pass so the radar benchmark can isolate planner/release behaviour.

### SBF is evaluated as a section fire line
- Added `ARTIC_fnc_evaluateSbfFireLine`. The planner samples a representative five-point
  FIX line perpendicular to the attack axis and measures aggregate/union visibility against
  up to eight known enemy positions.
- One hostile position counts as covered if any usable point on the line can see it.
- Diagnostics include aggregate coverage, useful fire-line points, best single-point sight
  and mean single-point sight.
- The old single SBF-anchor `>= 40%` check no longer acts as the binary assault veto.

### Standard and limited SBF solutions
- `ARTIC_preferredSbfCoverage = 0.40`: preferred quality / scoring bonus.
- `ARTIC_minSbfCoverage = 0.25`: normal viable aggregate fire-line coverage.
- `ARTIC_minSbfUsefulPoints = 2`: at least two representative points must see enemy for a
  STANDARD solution.
- `ARTIC_limitedSbfCoverage = 0.125`: degraded fallback floor.
- A LIMITED solution is not accepted immediately. After one normal failed plan review
  (~22 s), it can be accepted only when the underlying battlefield assessment still allows
  assault and the friendly/enemy power ratio is >= 1.15.
- Zero-coverage fire positions still hold. Anti-armour/support/force-ratio vetoes remain
  authoritative.

### HOLD_FOR_FIRE_POSITION deadlock removal
- Failed SBF reviews are counted in the persistent battle context.
- A favourable platoon can progress from `HOLD_FOR_FIRE_POSITION` to a controlled LIMITED
  SBF after a repeated failed search instead of waiting forever for a perfect urban firing
  position.
- The selected context records `fixFireLineCoverage`, `fixFireLineUsefulPoints`, `sbfMode`
  and `sbfFailureCount`.

### RPT markers
Expect COA lines such as:
```text
COA search ... valid=true degraded=false anchor=13% fireLine=38% useful=3
```
or, after one failed review:
```text
COA LIMITED SBF accepted after 1 failed review(s): axis=... line=13% useful=1 ratio=2.64
```
followed by a normal tactical release rather than permanent
`HOLD occupied but assault not authorised (plan=HOLD_FOR_FIRE_POSITION)`.

## v0.3.25-alpha — Actions on contact: react, fire from cover, fire control

### Sections react to contact during the approach
- Effective contact (enemy within ~450 m, or the section is being shot at) takes the section
  out of the platoon march (`ARTIC_reacting`). 0.3.16-0.3.24 kept marching sections on
  their routes under fire ("maintaining section routes").
- The platoon HALTS while a section reacts: every section holds where it is. The halt ends
  in a release when the platoon decides on a hasty attack, or after 45 s of reaction.
- After developing the situation, a section not yet released by the platoon HOLDS its
  contact LINE and keeps firing from cover (`ARTIC_holdContactLine`) instead of starting
  its own play or walking toward the objective.

### Contact LINE with firing positions from cover
- The section faces the threat in LINE (the existing develop drill, now held as needed).
- `ARTIC_fnc_assignFirePositions`: each soldier's LINE slot is replaced by the best nearby
  firing position: his slot, behind nearby cover, or at the LEFT / RIGHT EDGE of that cover,
  each tried prone / kneeling / standing. Scored on sight of the enemy from that eye height
  and on whether his body is covered from the threat. Positions with no sight are not
  used; positions kept apart for grenade dispersion. Re-assigned every 20 s.
- Soldiers take the stance chosen for their position once there (prone behind low cover,
  kneeling behind waist-high cover, standing at corners). AI leaning cannot be scripted in
  Arma; edge positions plus stance are the equivalent.

### Fire control (`ARTIC_fnc_sectionReactFire`)
- Combat mode RED. MG / autorifle suppress continuously; riflemen engage a visible enemy,
  otherwise about half suppress the threat position.
- Grenadiers fire HE (`ARTIC_fnc_fireHE`: GL muzzle with a carried shotShell round, CBA
  invisible aim helper) at threats 50-350 m away that are grouped, in buildings or not
  directly visible; 15 s per grenadier.
- AT targets enemy vehicles / static weapons within 450 m.
- Hand grenades at enemy within 35 m; 15 s per soldier.

### What to look for in the RPT
- `Platoon ...: Alpha 1-x reacting to contact; platoon halts in place ...`
- `Contact drill: section returning fire from cover (fire control active)`
- `Contact drill: N soldier(s) given firing positions from cover`
- `Contact drill: holding contact LINE and returning fire while the platoon decides`
- then a contact-call response (hasty attack / hold) or `tactical release (CONTACT)`.

## v0.3.24-alpha — Plan stability, SBF fire line, contact calls and platoon coordination

Test RPT 2026-10-01 17:56 (0.3.23): the axis changed 179 -> 359 -> 86 -> 18 -> 46; a new
context was built 46 s after release; the chosen SBF saw 25 % for the planner but 0 % for
FIX; FIX occupied it as a formation in the open; both flanks aborted when FIX failed.

### Plan stability
- Battle plan LOCKED while any section runs a play or < 90 s after release (unless the
  enemy moved > 200 m). Suppressed re-plans are logged.
- COA hysteresis: a new axis (> 30 deg away) replaces a still-valid plan only when its score
  is at least 15 higher.
- SBF must see at least `ARTIC_minSbfSight` (default 40 %, was 20 %) of the known enemy.
- The planner's sight targets are published (`ARTIC_battleSightTargets`); FIX and the
  base-of-fire fallback judge sight against exactly the same positions.

### SBF fire line
- FIX reaches a covered point ~30 m behind the SBF, then occupies a fire line: one firing
  point per shooter across the line of fire, scored on its own sight and cover, at least
  the formation minimum separation apart, MG on the best point; short individual moves
  (HOLD tasks). Medic waits at the covered approach point. If too few shooters see the
  enemy, the whole fire line moves up to 25 m forward once.

### Contact calls and platoon coordination
- Sections send a contact call on first contact / a new enemy group:
  `CONTACT! Alpha 1-2: 3x enemy infantry incl. 1 MG, 1 AT - bearing 045, 210 m, grid 043038`
  (`ARTIC_contactCall`, `ARTIC_contactCalls`).
- `ARTIC_fnc_platoonContactResponse` (server): acknowledges each call, shares the contact
  with every other section immediately, then
  - attack under way + unexpected contact (> 80 m from the objective): FIX shifts fire onto
    it if established and able to see it (`ARTIC_fireRedirect`), else the nearest section
    that can see it supports by fire (`ARTIC_assistCall`);
  - not yet attacking: HASTY ATTACK (attack intents, not RECON, >= 2:1, > 150 m from the
    objective): the calling section becomes FIX, the others LEFT / RIGHT by where they
    stand, the battle re-centres on the contact; ends when nothing live is left there for
    60 s or after 5 min (original roles and objective return). Otherwise hold and report.
    `ARTIC_hastyAttack`.
- FIX shifts fire onto redirected contacts during suppression; manoeuvre sections waiting
  on FIX, and idle sections, answer assist calls by engaging from where they stand.

### Base-of-fire fallback
- If FIX fails, each manoeuvre section bids its own sight of the enemy; the better one
  (>= 25 %, ties to LEFT) becomes the base of fire and the other waits on it. Both abort
  only if neither can see.

### What to look for in the RPT
- `CONTACT! ...` then `Platoon ...: contact call from ... acknowledged -> ...`
- `Battle plan LOCKED during execution`, `COA change ... rejected`
- `FIX occupying fire line: N firing point(s) ...`
- `... taking over as BASE OF FIRE`, `FIX shifting fire onto contact called by ...`,
  `... assisting ...`, `HASTY ATTACK: ...`

## v0.3.23-alpha — SBF on the friendly side, routes go round the enemy

Test screenshot (0.3.22, during REPOSITION_FOR_ATTACK): FIX (Alpha 1-1) approach route ran
from the north straight through the Air Station to an SBF on the enemy's far
(south-southwest) side.

- `findSupportArc`: search +-55 deg around the platoon's side of the objective (was +-85 deg),
  and reject any SBF whose straight approach from the friendly side passes closer to the
  enemy focus than 75 % of the SBF's own distance (i.e. round or through the enemy).
- `planSectionRoute`: new stand-off (battle radius + 80 m). If the straight line to the
  destination passes inside it, the route goes round the circle the shorter way (waypoints
  every ~30 deg, each nudged outward to the best masked / covered spot) instead of four
  straight-line points nudged at most 42 m sideways.
- Both route-planning call sites (battle context and route-progress re-plan) pass the
  stand-off.

## v0.3.22-alpha — FIX occupies the SBF during deployment (test RPT 2026-10-01 07:58)

Test findings: COA search worked (axis 116, SBF 63 % sight) and tactical movement showed
0 conflicts / 0 stalls, but the attack still ended "FIX never achieved suppression":
FIX's hold (041039) was ~300 m from its SBF (041036); the SBF move had a fixed 55 s
timeout; the manoeuvres a fixed 80 s wait; FIX needed a live target (idle ~2 min 48 s
after release); and FIX used a different sight test than the planner.

### Support by fire as part of deployment
- FIX's battle HOLD / attack position is now a covered point ~35 m behind its validated
  SBF, so the platoon approach delivers the support element to its SBF. (Only once the
  SBF is validated against enemy intelligence.)
- `executeFixingAction` rewritten: OCCUPY (distance-scaled timeout, accept a short
  arrival that already sees the enemy) -> OBSERVE (`battleSight`, same test as the
  planner; creep once) -> READY_HOLD_FIRE (combat mode GREEN) -> OPEN FIRE on trigger
  (a manoeuvre section reports WAIT_FIX, FIX engaged, or 90 s) -> SUPPRESS.
  No live target needed: uses shared contacts, else area suppression on the battlefield.
- FIX starts at release from the validated SBF alone; it no longer walks toward the
  objective while it has no target.
- Armed sections without a local target use the freshest live shared contact, so plays
  start at release instead of waiting for a new UAS report or a local sighting.

### Coordination
- Manoeuvre sections publish `ARTIC_manoeuvrePhase = WAIT_FIX` and wait while FIX makes
  progress (`ARTIC_fixProgressAt`); abort only if FIX failed, or made no progress for 60 s
  after at least 80 s, 6 min hard cap.
- `suppressElement` counts a shooter if either the planner's sight test or the legacy
  check sees the target; area fire builds the suppression estimate the same way.

### Planning
- `findSupportArc` search capped at ~1.3x the envelope fire distance (was preferred +
  150 m, up to 360 m: an SBF ~280 m out in 160 m urban sight).

### Watchdog / noise
- UNITCTRL CONFLICT only when the soldier is > 4 m from his ARTIC target and the engine
  is running a command (or any ATTACK command). Logs engine planning mode and distance to
  target. Routine re-assertion every 3 s (was 1.6 s).
- Support requests stop for 3 min when no fire-support module is linked (was every 20 s);
  UAS "no provider" reported every 2 min.
- Incomplete tactical moves log remaining route length vs straight-line distance.

### What to look for in the RPT
- `FIXING_ACTION occupy SBF ... sight=N%`, `FIX in SBF, holding fire`, `FIX opening fire
  (trigger=MANOEUVRE_READY)`, then manoeuvres proceeding instead of "never achieved".
- METRICS: sbfSuccess / sbfAttempts and time-to-SBF.

## v0.3.21-alpha — Strategic/tactical separation and vanilla auto-attack lockout
- `CAPTURE` objectives now become strategic `SEIZE` purpose rather than immediate subordinate `ATTACK` execution orders. Unsupported objective types no longer default to ATTACK.
- Multi-section offensive formations keep persistent FIX / LEFT / RIGHT scheme roles but use a safe `PLATOON` execution state with no objective position until the platoon commander authorises tactical release.
- `fn_platoonMovementStep` now arms executable FIX / ATTACK / RESERVE section orders only at tactical release, eliminating the dormant `ATTACK -> Eden objective` fallback beneath `PLATOON_GUIDE`.
- ARTIC now enforces `group enableAttack false` while guide movement is owned, preventing vanilla group leaders from assigning automatic ATTACK commands to ordinary section members.
- Movement watchdog treats any engine `currentCommand == ATTACK` during guide movement as a control conflict, clears private target/watch state, and immediately restores the ARTIC slot destination.
- UAS and commander contact dissemination no longer calls `reveal`; shared intelligence remains in `ARTIC_sharedContacts`.
- Engine knowledge is seeded just-in-time only for explicit ARTIC SUPPRESS / ASSAULT tasks.
- `finishPlan` keeps vanilla automatic attack disabled while the group returns to ARTIC FORMATION ownership.
- `MOVEAUTH` telemetry now includes `attackCmd=` and `autoAttack=false`.

## v0.3.20-alpha — Single movement owner for every infantryman
- EAST commander intent is now persistent instead of being re-written every 120 seconds. The same objective is re-issued only when the objective changes or the commander's ARTIC group set changes.
- Strategic objective metadata (`ARTIC_strategic*`) is separated from executable group-order metadata (`ARTIC_execution*`). Platoon RELEASE/HOLD/route/guide movement remains authoritative while the strategic intent stays "seize OBJ_1".
- Movement ownership watchdog now covers every local fit soldier, not only the section commander. It compares each ARTIC slot target against engine `expectedDestination` / `currentCommand`, logs `UNITCTRL CONFLICT`, and immediately reasserts the ARTIC target.
- ARTIC now owns the infantry FSM layer by default while a section/platoon/tactical guide owns movement (`ARTIC_takeInfantryFSMControl = true`). Arma `MOVE` and `PATH` stay enabled for navmesh, obstacle avoidance and animation.
- Added per-soldier physical stall recovery (`UNITCTRL STALL`) and compact group `MOVEAUTH` summaries showing owner, guide velocity, unit count, conflicts, stalls, waypoint count, maximum engine/ARTIC destination delta, FSM state and reposition phase.
- FORMATION movement no longer falls back to vanilla `doFollow` when a slot is missing. ARTIC rebuilds the slot table and, if required, creates a deterministic emergency guide-relative slot.
- Moving FORMATION slots are reasserted on a short cadence without waiting for `unitReady`; a stale/missing engine command can no longer silently hand a subordinate back to vanilla movement.
- `ahead` pacing no longer issues sticky `doStop` while the guide is moving. Ahead soldiers are speed-limited instead; intentional halted formations may still use `doStop`.
- `REPOSITION_FOR_ATTACK` guide pacing now uses longitudinal median body lag only. Lateral/shape error remains diagnostic but cannot slow a column with `bodyLag=0`.
- Major section retasks reset movement-control watchdog state and cached commanded targets.

## v0.3.19-alpha — Authoritative movement ownership & elastic section guides
- Replaced the section-wide `SECTION_COHESION` hard halt with an elastic median-body leash. Cohesion can slow the virtual guide to a crawl but can no longer set guide velocity to zero.
- Section commanders now ride a forward-biased CMD target while the guide is moving and are exempt from the generic `ahead -> doStop` pacing rule. Deliberate tactical halts and survival reactions still stop them.
- `REPOSITION_FOR_ATTACK` now moves sections in FILE/COLUMN and only redeploys combat formations after the new release side is occupied, avoiding large WEDGE slot swings during major COA rotations.
- Material guide retasks clear cached `settled/stopped/catch-up/aim` state so a stale `doStop` cannot survive a new route or COA.
- ARTIC-controlled infantry groups now delete unexpected group-level waypoints at ownership handover and whenever the local watchdog detects one. This removes the parallel vanilla/Eden/Zeus waypoint movement owner.
- Added `ARTIC_fnc_assertMovementControl` with compact `CMDCTRL` telemetry comparing ARTIC target, engine `expectedDestination`, current command, guide velocity, leash state and waypoint count.
- Added automatic commander-stall recovery after >6 s physical no-progress while the guide is moving; the watchdog resets sticky stop state and reissues the current ARTIC target.
- Arma `PATH` and `MOVE` remain enabled as the local navigator. `ARTIC_takeLeaderFSMControl` is available for controlled benchmarks but defaults to `false` until telemetry demonstrates an FSM conflict.
- Fixed stale runtime version logging: preInit now reports `0.3.19-alpha`.

## v0.3.18-alpha — Dynamic attack COAs, section-command cohesion, route recovery
- Added `ARTIC_fnc_generateBattleCOAs`: the platoon now evaluates the current attack axis plus ±30°, ±60°, ±90° and reverse-axis candidates instead of treating its direction of travel as the only possible battle geometry.
- Every COA samples a full support-by-fire zone, enemy visibility, masked approach quality, terrain cover/slope, reposition distance and turn cost. A valid attack requires a useful SBF solution (20%+ observed enemy visibility); invalid partial solutions do not make the platoon wander.
- Added `REPOSITION_FOR_ATTACK`: when a materially better valid axis is selected, the platoon shifts to a new release side, reforms there, then regenerates FIX / LEFT / RIGHT lanes from the new geometry.
- `HOLD_FOR_FIRE_POSITION` is no longer permanent. Failed battle geometry is reviewed on a timer and immediately on new intelligence, >25% enemy-strength change or >55 m enemy-focus shift.
- Removed CMD/MEDIC/2IC as hard guide interlocks. A single protected role or straggler can no longer set section guide speed to zero; guide halts now require a genuine section-wide cohesion collapse.
- Platoon-owned FORMATION movement now counts as an advancing state for individual AI. Section commanders ignore distant danger pulses during the approach unless they are genuinely heavily engaged, hit, or need an exposed reload.
- Added section guide HALT/RESUME diagnostics with reason, average slot error, bad-member count, second-worst error and protected-role lag.
- Added route-progress watchdog: stale/overshot control points are advanced or replanned from the section's actual guide position after sustained no-progress.
- Added pathological guide-path rejection when engine path length is grossly disproportionate to the tactical corridor, preventing huge dog-leg excursions.
- Existing early LEFT/FIX/RIGHT lane separation is retained.

## v0.3.17-alpha
- Removed all runtime LAMBS compatibility variables and audited source for DCO/NR6/HAL/SoldierFSM runtime references.
- Removed retired majority-centroid movement functions (`moveElement`, old section/fireteam anchors, regroup override stack).
- Added persistent fireteam membership, deterministic fireteam slots and self-paced fireteam tactical guides.
- Migrated standalone suppress/flank and fighting withdrawal away from the retired movement path.
- Stopped calling Arma group `setFormation` while ARTIC guide formations are active.
- Locked platoon-owned approach formations through UAS/shared intelligence and long-range visual contact; WEDGE/FILE changes now require a sustained terrain change instead of local classifier flicker.
- Increased early LEFT/RIGHT route separation to stop sections crossing through the same centre lane.
- Reworked SBF selection into a broad friendly-side arc search; objective-only geometry cannot validate an SBF.
- Invalid SBF feasibility now persists across assessment refreshes; debug removes the active FIRE/ASSAULT/FCL/LOA/combat-corridor geometry while the attack is not authorised and marks the candidate as NO VALID SBF.

# ARTIC AI Changelog

## v0.3.16-alpha — Movement consolidation, persistent guide handover, regression gates

- Removed ARTIC's explicit `reload _unit` call from RELOAD_COVER after the v0.3.15 benchmark produced a `ReloadMagazine` weapon/muzzle error; ARTIC now releases reload permission only after verified cover.
- Platoon/battle-context fallback references no longer read the retired majority-cluster section anchor; first-tick fallback uses a robust majority cluster only when no persistent guide/reference has been published yet.

### Definitive movement fixes
- Section guide is preserved through approach -> contact -> tactical-play handover; the formation controller no longer clears it when a plan becomes active.
- Platoon tactical release is gated: long-range contact keeps the platoon on its assigned section routes until HOLD/release positions are near, unless the contact is within the emergency threshold.
- `groupStep` honours the platoon march owner even when one section has early contact; local danger reactions can still fire without launching the full manoeuvre prematurely.
- Active formation movement no longer updates the legacy majority-cluster section/fireteam anchors. Stable fireteam membership remains for role/team identity.
- Tactical FIX / manoeuvre functions claim guide ownership before publishing `currentPlan`, removing the handover race that rebuilt guides from dispersed centroids.
- `finishPlan` returns soldiers to FORMATION ownership at the persistent guide rather than HOLD-at-current-position.

### Formation geometry
- All section templates rewritten as bounded real-metre geometry.
- Removed global closest-pair scaling that could stretch COLUMN into a 60-90 m formation and place command/medical roles far behind.
- CMD / MEDIC / 2IC remain protected by slot choice but are judged against their own slots like everyone else.
- Formation changes are rate-limited (normal 25 s dwell) and opened at destination/path control points.
- Live desired FT-A / FT-B guide positions are derived from formation slots, never from the soldiers' live centroid.

### Battlefield / fires
- Expanded SBF search when the original fire position sees <15% of known enemy.
- If the best expanded SBF still sees <10%, `assaultAllowed` is withheld (`HOLD_FOR_FIRE_POSITION`) instead of ordering a knowingly blind fixing position.

### Individual safety
- Predictive `RELOAD_COVER`: exposed soldiers begin the cover transition at <=4 rounds rather than waiting for an empty weapon / committed reload animation.
- Legacy non-FORMATION tasks now have a guide/slot safety leash instead of using the retired majority-cluster cohesion model.

### Regression instrumentation
- RPT `METRICS` summaries include average/max slot error, tactical move success/failure, SBF success/attempts, and attack complete/attempt/abort counts.
- New `docs/BENCHMARKS.md` defines OPEN / WOODS / VILLAGE / NIGHT repeat tests and quantitative v0.3 exit criteria.
- New `docs/ROADMAP.md` moves basic morale and casualty drills into v0.4, adds static-weapon milestones, basic urban competence, recurring 150-AI server/HC performance gates, vehicle-agnostic tactical element design, and the DCO clean-room study.

## v0.3.15-alpha — Battlefield context: sight, derived distances, shapes, sectors, defence

### 1. Fire positions that actually see the enemy
- New `ARTIC_fnc_battleSight`: sight from prone and kneeling eye height to the KNOWN enemy
  positions, against terrain and objects with the VIEW/FIRE LODs (foliage blocks sight).
  0.3.13 used one GEOM ray to the battlefield centre, so positions "saw" through bushes and
  at empty ground (the recurring `SBF LOS=false` / "FIX never achieved suppression").
- `fn_findBattleControlPoint` scores FIRE positions on the fraction of known enemy visible
  (bonus when >= 50 %), HOLD/APPROACH/ASSAULT on being hidden from them. Returns
  [position, sightFraction]. Search radius scales up to 110 m with cheaper sampling.

### 2. Distances from terrain, visibility and weapons
- New `ARTIC_fnc_getBattleEnvelope`: terrain OPEN / MIXED / CLOSE / URBAN, sight from view
  distance, fog, night and terrain caps (OPEN 500, MIXED 300, CLOSE 140, URBAN 160,
  night 220 m). Fire position ~0.6 x sight (70-300 m, further for MG-heavy forces), hold
  line fire + 70-160 m, assault position 35-85 m, never inside the enemy's radius.
  Replaces the fixed 320-380 m hold / 185-220 m fire position; corridor stages follow.

### 3. Attack shapes
- Each battlefield gets a shape that generates the control points its tactic needs:
  FIX_LEFT_RIGHT, TWO_AXIS_RESERVE (reserve behind the better-covered flank),
  SINGLE_FLANK (flank on the better-covered side), DOUBLE_ENVELOPMENT (AGGRESSIVE / SF,
  3+ sections, ratio >= 1.2: wider corridors, assault positions on the enemy's flanks),
  BREAK_IN (fortified enemy: keypoint = static weapon or densest enemy position, oblique
  fire position on the better-seeing side, assault approaching at ~90 deg to its line of
  fire, second manoeuvre section following to exploit), HOLD.
- Sections receive corridors by shape through the existing `ARTIC_battleCorridor` /
  `ARTIC_battleHoldPos` / `ARTIC_battleFixPos` interface, so the plays are unchanged.
  New `ARTIC_battleShape`, `ARTIC_battleKeypoint`.

### 4. Platoons sharing a battlefield
- `ARTIC_BattlefieldAllocations`: formation nodes attacking the same battlefield get
  adjacent sectors (centre, right, left, ...) one frontage apart instead of overlapping
  corridors and boundaries.

### 5. Defence context (new)
- `ARTIC_fnc_buildDefenceContext` for DEFEND orders (single sections included): threat axis
  (known battlefield / contacts, else the approach direction), engagement area ~0.6 x
  sight out, trigger line, one primary battle position per section chosen because it sees
  the engagement area, alternate position, principal direction of fire, MG final
  protective line across the front, hidden forward OP.
- DEFEND orders occupy the section's BP; battle-position layouts face the PDF.

### Debug map
- SBF marker shows the shape and how much of the known enemy it sees; break-in keypoint;
  defence EA, trigger line, OP, each section's BP / ALT with sight %, PDF and FPL lines.

## v0.3.14-alpha — Formation spacing, crow's foot, cohesion fixes for 0.3.13

### Cohesion / movement fixes
- **Guide halted permanently in column.** Protected roles (CMD / MEDIC / 2IC) were
  measured against the guide point, but their slots sit 10-35 m from it by design (2IC
  ~35 m back in COLUMN, ~17 m out on the LINE flank). They are now measured against their
  own slot.
- **Tactical phases could not complete in column / echelon.** `moveSectionTactical`
  required every soldier within 32 m of the guide (a column is ~45 m long). Completion is
  now judged on distance from each soldier's own slot, scaled by formation spacing, with
  one straggler tolerated.
- **One soldier halted the section.** The guide's straggler test now ignores soldiers in an
  active reaction (cover / reload / pinned) and uses the second-worst soldier.
- **Soldiers broke formation under fire during plays.** FORMATION movement inside a play
  (tactical guide) now presses on like MOVE / ASSAULT, within the same suppression /
  exposure limits.

### Spacing (ATP 3-21.8: ~10 m between soldiers, reduced in close terrain)
- Minimum distance between any two soldiers by training: open POOR 5, REGULAR 7,
  VETERAN 9, ELITE 10 m; close country / night x0.5. Formation spacing is raised until the
  closest pair in the template meets it (grenade / burst dispersion).
- VEE respaced (AT and 2IC were ~1 m apart).

### Crow's foot (new, replaces VEE for forward threats)
- Two pairs forward and wide toward the likely contact (MG + rifleman each), commander +
  medic in the middle, 2IC + one other at the rear; 9th/10th soldiers reinforce the front
  pairs. Used for "contact expected ahead" and tactical threat-ahead moves.
  `ARTIC_useCrowsFoot = false` restores VEE.
- Slot fallbacks: a second MG slot takes a grenadier, then AT, then a rifleman.

### Heavy left / heavy right
- Formations are mirrored so the MG side faces the most likely contact (nearest known
  threat on the right -> mirror), with 20 deg hysteresis. Not applied to column / diamond /
  box.

## v0.3.13-alpha — Doctrine-Informed Attack Control + Section Routes

### ATP 3-21.8-informed control hierarchy
- Reviewed the public Infantry Rifle Platoon and Squad techniques for movement, actions on contact, squad/platoon assault, support by fire, fireteam leadership, control measures, assault positions/FCL and consolidation.
- Added persistent `ARTIC_contactAction`: REACT -> DEVELOP -> CHOOSE_ACTION -> EXECUTE.
- Added doctrinally recognizable PLD and final coordination line (FCL) to the battlefield context while retaining ARTIC HOLD/FIRE/ASSAULT controls.

### Movement to the battlefield
- Replaced pre-contact BOUNDING with TRAVELLING / TRAVELLING_OVERWATCH. A known UAS battlefield changes security/pace but no longer makes the platoon leapfrog hundreds of metres from contact.
- Every section receives a persistent terrain-scored approach route to its role-specific HOLD position. Routes penalize enemy observation, steep slopes and cross-lane drift.
- Map debug draws the exact section routes plus battlefield combat corridors.

### Section / fireteam control
- Designates a persistent base fireteam, preferring the team with the strongest automatic-fire capability.
- Standalone squad attacks use the base fireteam as the initial base of fire and preserve the other fireteam as the manoeuvre element when possible.
- Tactical section-guide completion tightened to 85% in slot with a 32 m maximum guide separation.
- Protected command/medical roles remain inside the formation and receive much tighter catch-up limits rather than forming a detached tail.

### Assault synchronization
- Support/fixing section must establish useful LOS and suppression before assault sections leave cover.
- Manoeuvre sections synchronize at persistent LEFT/RIGHT phase points and assault positions.
- Added final coordination line occupation and temporary LINE formation before the final assault.
- Existing fire-shift, partner gates, assault and consolidation remain.

## v0.3.12-alpha — Battlefield Context + Threat-Relative Cover

### Persistent battlefield planning
- Recon/UAS contact clusters can classify a battlefield before direct infantry contact.
- Added commander battlefield registry with centre, radius, source/confidence and rough enemy composition/size.
- Added friendly force assessment for committed groups: strength, MG/GL/AT/AA, medical/engineering, vehicles, UAS/FPV and linked fire support.
- Generates a force ratio and plan state (`FIX_LEFT_RIGHT`, `TWO_AXIS_WITH_RESERVE`, `HOLD_FOR_SUPPORT`, etc.).
- Persistent HOLD, FIRE/FIX, ASSAULT and Limit-of-Advance lines plus LEFT/RIGHT corridors, reserve/rally positions, boundaries and fire sectors.
- UAS/shared intelligence no longer automatically counts as direct contact; platoons can prepare against the detected battlefield first.
- Platoon movement uses section guide/anchor positions rather than physical section leaders.
- FIX and manoeuvre plays consume the persistent battlefield geometry rather than rediscovering independent positions on every attempt.

### Individual survival / cover
- Multi-threat exposure assessment counts hostile LOS threats, recent active shooters, recent hits and suppression.
- Soldiers exposed to several shooters can seek cover even when engine suppression is low.
- Threat-relative cover search scores how many hostile LOS lines a candidate actually breaks.
- Reload-under-fire uses the same LOS-breaking cover search.

### Formation/cohesion fixes
- Fixed `distance2D []` regroup exception caused by an empty regroup override position.
- Commander, medic and 2IC formation roles are hard-protected from training-noise swaps.
- Section formation guide now publishes an authoritative section reference for platoon planning.

## v0.3.11-alpha — Formation jitter fixes (test RPT 2026-09-30 23:40)

No script errors; formations only changed on test-menu input. The jitter was in how
soldiers were ordered to their slots:

### Soldiers (FORMATION owner)
- Steady lead ahead of the slot, proportional to the formation's actual speed (0.3.10
  jumped between +4 m and 0 as the guide started/stopped: overshoot, then walk back).
- Settled state with hysteresis: within 2.5 m of a halted slot -> `doStop` once (the
  engine can't pull him back into its own formation), not re-ordered until > 6 m out.
- A soldier ahead of his target while the formation moves waits instead of walking back.
- Distances measured to the actual (validated) target, not the raw slot.
- Re-targeting only when the aim moves > 4 m; stuck soldiers re-ordered at most every
  2.5 s; catch-up running with hysteresis (> 12 m on, < 6 m off).

### Guide
- Formation error smoothed; the guide pauses only when the section is clearly out of shape
  (2x limit) and resumes when re-formed (0.8x); in between it slows smoothly (was
  full / half / stop, toggling every second).
- Heading from a point ~25 m ahead on the route, max 8 deg/s, 4 deg deadband (was 35 deg/s
  toward the next point 8 m ahead, so outer men swung on every kink).
- Contact LINE facing locked at the start of the drill; re-aimed only if the enemy's
  bearing moves > 25 deg.

Note for the test overlay: the dot is the raw slot; while moving each soldier aims a few
metres ahead of it, so a short gap between soldier and dot is expected.

## v0.3.10-alpha — Formation test support
- `ARTIC_formationOverride` (group variable, e.g. "BOX") forces a formation; "" returns to
  the normal assessment. Used by the ARTIC_FormationTest harness.

## v0.3.9-alpha — Formation system (see docs/FORMATIONS.md)

### One owner per soldier
- Idle soldiers get a FORMATION task owned by the new section formation controller; the
  old cohesion governor and engine `doFollow` no longer act on them. Priority: reaction >
  play task > STATIC > FORMATION.
- Idle tasks are refreshed in place (they used to expire every 20 s, wiping reactions)
  and re-evaluated each tick so a change of order swaps FORMATION <-> STATIC.

### Guide-based formations with role slots (new `functions/formation`)
- Guide point follows a real route (`calculatePath`, thinned; straight line fallback) and
  self-paces: full pace while soldiers are close to their slots, half pace when they lag,
  waits when they are well behind. Slots are relative to the guide, not the soldiers'
  centre. Slots are pulled in if they fall in water or behind a building wall.
- Role slots: commander and medic central/protected, 2IC at the rear, point man forward,
  MG/grenadier/AT on arms and corners. Training `specialistAssignment` / `coordination`
  control placement quality.
- Formations: COLUMN, WEDGE, VEE, LINE, DIAMOND, BOX, BOX_DIAMOND, ECHELON_LEFT/RIGHT,
  chosen by assessment (contact, halted, threat direction/spread, distance to go, terrain,
  platoon hint, doctrine) with training-based hysteresis.
- Soldiers are re-ordered only when their slot moves > 5 m (or they stop short), lead the
  moving slot slightly, jog at formation pace and run to catch up when > 12 m out.
- All-round formations: each soldier watches outward when halted.

### Contact drill
- On first contact the section forms a LINE facing the enemy for decisionDelay + 2 s
  (max 14 s) to develop fire, then the plays (suppress / fix / flank) start.

### Integration
- All `_group move` calls in the planner now set a section destination
  (`ARTIC_fnc_setSectionDestination`); platoon movement feeds the same destination and a
  formation hint.
- `ARTIC_formationSystem = false` restores engine formations.

### What to look for in the RPT
- `Formation COLUMN (safe: speed)` / `WEDGE (contact possible)` / `LINE (contact: develop
  fire)` / `DIAMOND (halted: all-round)`.
- `Contact: forming LINE to develop fire for N s`, followed by the plays.

## v0.3.8-alpha — Movement speed and platoon movement

### Section movement (test RPT 2026-09-30 17:12)
- **Cohesion by speed, not stop-go.** A soldier ahead of his fireteam/element is slowed to a
  walk (`forceSpeed`), a straggler catches up at full speed, and only a soldier far ahead
  waits. Reactions and regroups reset the applied speed so nobody is left capped.
- **Leashes from terrain** (`ARTIC_fnc_getMovementProfile`, cached 10 s): OPEN soft/hard
  24/38 m, team separation 60 m; CLOSE (dense vegetation/buildings, or night) 14/24 m,
  team separation 34 m. Element leashes 26/40 m open, 16/26 m close.
- **Facing from actual travel direction** outside plays, so "ahead/behind" is judged along
  the real axis during approaches.
- **Technique by threat** in `moveElement`: TRAVELLING (no enemy within ~900 m), OVERWATCH
  (enemy within ~900 m, rear team trails), BOUNDING (enemy within ~450 m or under fire).
  Bounding used to be applied to every covered VETERAN+ move.
- **Leapfrog bounds** for VETERAN/ELITE (each team moves past the other); POOR/REGULAR use
  successive bounds. Bound length 30-50 m open / 15-25 m close, scaled by training.
- **Relaxed arrival:** a compact element (all within 22 m of its centre) whose centre is
  within 15 m of its slots has arrived. A move that doesn't fully arrive continues from the
  element's position if it's still compact; a full regroup only happens if it's dispersed.

### Platoon movement (new)
- `ARTIC_fnc_platoonMovementStep` (server, every commander tick): a formation node with 2+
  sections moves to its objective as one platoon.
  - Battle Book spacing: WEDGE ~70 m between sections in the open, FILE ~22 m in close
    country / at night.
  - Sections are placed by the scheme of manoeuvre: FIX leads in the centre,
    MANOEUVRE_LEFT/RIGHT on their flanks, reserves trail - so on contact each section is
    already on its attack axis.
  - Paced by the slowest section; sections that get ahead are set to LIMITED speed.
  - Technique from the commander's contact reports: TRAVELLING / OVERWATCH / BOUNDING
    (one section moves at a time, the rearmost passing the lead).
  - On contact or when a play starts, control is released to the scheme of manoeuvre
    (for 60 s after the last contact).
  - On arrival each section gets its own final slot (`ARTIC_platoonFinalSlot`), used for
    ATTACK/DEFEND at the objective instead of every section converging on one point.
- Sections publish `ARTIC_inContact` (on change only). Disable with
  `ARTIC_platoonMovement = false`.

### What to look for in the RPT
- `Move <n>m technique=... terrain=...` per element move.
- `cohesion SLOW` instead of `cohesion HOLD`.
- `Platoon <id>: moving as a platoon to <grid>`, periodic `Platoon <id>: TRAVELLING WEDGE,
  progress x/y m`, then `contact - handing over` or `arrived at <grid>`.

## v0.3.7-alpha — Element cohesion during plays (test RPT 2026-09-30 16:58)

The test ran the first v0.3.6 zip, which predates the mortar fix below (the RPT still
shows the line-56 compile error). Both fixes are in this build; the version is bumped so
the builds can't be confused again.

### Findings
- ~340 SECTION REGROUP lines across all three sections, mostly from soldiers only 6-15 m
  from their anchors: the trigger was the distance between the two fireteams, which the
  plays split on purpose (fix / support / manoeuvre elements).
- The fixing section never reached its support-by-fire position (regroups pulled it back)
  and each chosen SBF had no line of sight; both manoeuvre sections aborted after 80 s and
  the same plan relaunched 8 s later, three times.

### Changes
- While a plan is active, cohesion follows the soldier's ELEMENT (element centre from
  `ARTIC_elementMembers`): pulled back beyond 30 m, soft leash within it; the section /
  fireteam regroup and team-separation trigger are suspended. Element lists are cleared
  when a play finishes.
- Outside plays, a section-wide regroup needs the fireteams to stay too far apart for 6 s;
  a single straggler no longer triggers it, and a soldier > 80 m away no longer halts his
  fireteam.
- Fixing element without LOS at its SBF creeps forward once (up to 45 m) looking for a
  covered spot that sees the target before giving up.
- Failed / aborted plays back off 30 s (`ARTIC_fnc_finishPlan` takes an optional cooldown).

## v0.3.6-alpha — Individual layer review fixes

### Casualties
- New `ARTIC_fnc_isFit` (alive, not incapacitated, not ACE-unconscious, on foot).
- Downed soldiers are excluded from fireteam anchors, membership, bound readiness,
  team-presence checks and regroups, and get no individual orders (their task is
  dropped once). Previously an unconscious soldier kept triggering section regroups
  and every bound timed out while anyone was down.
- Bound readiness still targets ~90 % but always tolerates one straggler (with 4 men,
  90 % meant all 4).

### Network
- Anchors, fireteam membership, formation template/facing/destination, regroup and
  halt timers, bound state and unit tasks are now local variables (they were
  broadcast every update, ~5 broadcasts per soldier per second). Fireteam ID and slot
  stay public so assignments survive a transfer to the HC.
- Anchor update throttled to once per group per ~second (it ran per soldier).

### Cohesion
- Soft leash only halts soldiers AHEAD of their fireteam anchor; stragglers are sent to
  their slot to catch up.
- Cohesion and regroup orders are re-issued at most every 2.5 s (were every second).

### Reactions
- While advancing (ASSAULT / MOVE), soldiers press on through fire: they turn on the
  threat and fire instead of breaking for cover, until suppression passes a limit set by
  doctrine `riskTolerance` and training `suppressionDiscipline`, or they must reload
  while exposed.

- A soldier who must reload while a live enemy can see him always reacts, even with no
  recent fire near him and inside the reaction cooldown: cover within 18 m if there is
  any, otherwise a prone reload in place.

### ACE Mk6 mortar (fire support)
- `fn_localArtilleryFire` never compiled: `unitTurret _gunner` is a one-argument use of a
  two-argument command (RPT: "Error Missing ;" at line 56, at mission start), so the ACE
  mortar path did not exist at runtime. Turret path now comes from `assignedVehicleRole`.
- ACE redefines `mortar_82mm` to accept only `ACE_1Rnd_82mm_Mo_*`; the shim now loads and
  fires the ACE round class instead of the vanilla `8Rnd_82mm_Mo_*` magazine (which the
  weapon can no longer load).
- If ACE's own AI reload has already put a round in the tube, ARTIC fires that round and
  does not also remove one from inventory (one physical round per shot).

### Idle task
- Fit soldiers in ARTIC groups with no task get an idle task, so the danger layer and
  cohesion run between plays (untasked soldiers used to fall back to vanilla):
  - FOLLOW for most orders,
  - STATIC (hold in place, no formation cohesion) for DEFEND / SUPPORT groups, once the
    soldier has finished his current move.
- Disable with `ARTIC_individualIdleTask = false`.

## v0.3.5-alpha — Persistent Fireteam Anchors

### Formation core
- Replaced raw-centroid cohesion references with persistent section/fireteam anchors.
- Fireteam anchors follow majority clusters so isolated runners cannot shift the formation reference point.
- Added persistent `ARTIC_fireteamId` and `ARTIC_fireteamSlot` ownership.
- Added reusable formation-slot resolver with `WEDGE` active and initial templates for `LINE`, `COLUMN`, `FILE`, `ECHELON_LEFT`, and `ECHELON_RIGHT`.
- Added local terrain deformation around nominal slots instead of replacing the formation geometry with unrelated destinations.

### Cohesion / regroup
- Cohesion governor now remains active beneath MOVE, HOLD, SUPPRESS, ASSAULT and FOLLOW.
- Added soft leash, hard fireteam regroup, fireteam halt, and section-level emergency regroup layers.
- Added inter-fireteam separation monitoring.
- Failed destination occupation now triggers active formation REGROUP rather than HOLD-in-place.
- REGROUP is an override beneath immediate danger reactions and preserves the original parent tactical task.

### Bounding
- Replaced full-route two-bound movement with short alternating fireteam anchor bounds (~26 m).
- Fireteam A must consolidate before Fireteam B is released and vice versa.
- Readiness now requires approximately 90% of surviving members to be in slot and fireteam separation to remain acceptable.

### Assault
- Platoon and standalone assault phases now resolve destinations through persistent formation slots.
- Assault no longer disables the cohesion structure by switching to unrelated ad-hoc individual points.

### Preserved from v0.3.4a
- Fire mission `_confirmed` scope hotfix.
- ACE Mk6 physical-ammo compatibility path and Fired-event validation.
- Platoon FIX / LEFT / RIGHT phase gates.
- Shared tactical picture.
- Crocus safe launch.
- Immediate danger reactions and incapacitated-target filtering.

### FSM Editor compatibility correction
- Rebuilt all four `.fsm` files with Bohemia FSM Editor decompile metadata (`%FSM<HEAD>`, state/link tags, item numbers and visual layout data).
- The original v0.3.28 foundation files contained runtime scripted-FSM class definitions but no editor/decompiler metadata, so Bohemia FSM Editor could open them as an empty canvas.
- No intended state-machine logic was removed; this correction makes the FSM graphs inspectable/editable in the FSM Editor.
