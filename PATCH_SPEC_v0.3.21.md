# ARTIC AI v0.3.21-alpha patch specification

## Problem proven by v0.3.20

The movement watchdog showed that the platoon planner, section guides, and section commanders remained correct after a COA rotation, while seven of eight section members repeatedly received engine `ATTACK` commands toward known enemy/objective locations.

This established a second control owner: Arma group automatic target assignment.

A separate architectural risk also remained: `fn_assignObjective` / `fn_assignFormationIntent` installed dormant `ATTACK -> objective` execution orders underneath `PLATOON_GUIDE`.

## Authority model

### EAST commander
Owns strategic purpose only:

- SEIZE
- DEFEND
- DELAY
- RECON
- RAID
- SCREEN

### Platoon commander
Owns the method:

- COA axis
- RELEASE
- HOLD
- PLD
- SBF/FIX geometry
- section routes
- tactical release

### Section / individual execution
ARTIC owns:

- stop/go decisions
- formation/guide destination
- tactical engagement assignment
- target assignment for explicit ARTIC combat tasks

Arma owns:

- MOVE
- PATH
- obstacle avoidance
- locomotion/animation

Vanilla group automatic attack assignment is disabled while ARTIC owns movement.

## Implementation changes

1. `fn_assignObjective.sqf`
   - CAPTURE -> SEIZE.
   - Unknown types are rejected rather than defaulting to ATTACK.

2. `fn_assignFormationIntent.sqf`
   - Offensive multi-section formations receive strategic metadata and persistent scheme roles.
   - No dormant section FIX/ATTACK order is installed before tactical release.
   - Safe executable state is `PLATOON` with no objective position.
   - Single-section SEIZE still maps to direct ATTACK because no platoon COA layer exists.

3. `fn_platoonMovementStep.sqf`
   - Understands SEIZE as an offensive formation intent.
   - New tactical-release gate arms FIX / ATTACK / RESERVE execution orders only when release is authorised.

4. `fn_updateCommanderIntel.sqf` and `fn_reportUASContacts.sqf`
   - Shared/UAS contacts stay in ARTIC data.
   - No strategic-intelligence `reveal` calls.

5. `fn_setUnitTask.sqf`
   - `reveal` is now just-in-time for explicit SUPPRESS / ASSAULT tasks only.

6. `fn_assertMovementControl.sqf`
   - Enforces `enableAttack false` while ARTIC owns guide movement.
   - Treats engine `ATTACK` as a conflict regardless of destination delta.
   - Clears private target/watch state and reissues ARTIC movement.
   - MOVEAUTH now reports `attackCmd=` and `autoAttack=false`.

7. `fn_finishPlan.sqf`
   - Does not restore vanilla automatic attack assignment after a tactical play.

## Regression criteria

During `REPOSITION_FOR_ATTACK`:

- `wp=0`
- `autoAttack=false`
- `attackCmd=0`
- ordinary infantry remain with section guides
- no direct mass run toward the Eden objective
- tactical execution is armed only after release
