# ARTIC AI v0.3.27-alpha patch specification

## Goal

Combine corridor-based section movement with dynamic platoon scheme selection and tactical
reassessment. The benchmark failure to eliminate is: FIX cannot establish LOS/suppression, both
manoeuvre sections wait/abort, and the platoon retries the same support-by-fire plan indefinitely.

## 1. Route execution

### Corridor gates
`fn_platoonMovementStep.sqf` treats `ARTIC_battleApproachRoute` points as gates through a safe
corridor. Gate completion is proximity-or-passage based rather than exact-point chasing.

Defaults:

```sqf
ARTIC_routeCorridorWidth = 38;
ARTIC_routeReplanSeconds = 35;
```

### Physical-progress watchdog
`ARTIC_routeWatchPos` / `ARTIC_routeLastMovementAt` track actual section displacement. A route is
replanned only when the section has physically failed to move enough for the timeout and is still
outside the current corridor gate.

### Pacing

```sqf
ARTIC_repositionPace = 2.7;
ARTIC_deployPace = 2.1;
```

The guide still respects body cohesion, but long COA repositioning is no longer forced to crawl at
final-deployment pace.

### Debug separation
- coloured route: ARTIC tactical PLAN;
- white route: current `calculatePath` LIVE NAV;
- NAV TARGET: current local section destination.

## 2. Scheme selection

New function: `ARTIC_fnc_selectAttackScheme`.

Inputs include force/capability assessment, FIX validity/coverage, previous failed scheme, failure
reason, and left/right route feasibility.

Possible outputs:

- `SUPPORT_MANOEUVRE`
- `DOUBLE_ENVELOPMENT`
- `SINGLE_ENVELOPMENT`
- `HOLD`

A useful SBF prefers support/manoeuvre. No credible SBF plus two safe flank routes can select double
envelopment; one safe route can select single envelopment when the force assessment permits it.

## 3. Dynamic roles

`fn_buildBattleContext.sqf` assigns section roles from the selected scheme instead of preserving one
FIX/LEFT/RIGHT template forever. Highest firepower section becomes FIX for support/manoeuvre or BLOCK
for envelopment; mobile sections are assigned to safe left/right corridors by proximity. Unused
sections become RESERVE.

## 4. Synchronized execution

`fn_executePlatoonManoeuvre.sqf` has scheme-specific gates:

### SUPPORT_MANOEUVRE
- requires FIX;
- waits for FIX ready/effective suppression;
- manoeuvre then continues through synchronized stages.

### DOUBLE_ENVELOPMENT
- requires BLOCK ready;
- LEFT and RIGHT must both report READY before H-HOUR;
- each stage is synchronized so one flank does not assault alone.

### SINGLE_ENVELOPMENT
- requires BLOCK ready;
- one manoeuvre element can proceed without a partner;
- does not wait on a fictional FIX suppression value.

## 5. Tactical failure / reassessment

Tactical scripts publish:

```text
ARTIC_planFailureReason
ARTIC_planFailureAt
```

Examples: `FIX_NO_LOS`, `FIX_SUPPRESSION_TIMEOUT`, `MANOEUVRE_ROUTE_EXPOSED`,
`MANOEUVRE_ROUTE_FAILED`, `MANOEUVRE_SYNC_FAILED`, `BLOCK_MISSING`, `BLOCK_NOT_READY`.

When no local play remains active, `fn_buildBattleContext.sqf` treats a fresh failure as an explicit
plan-unlock event. It resets tactical execution ownership to PLATOON, remembers the failed scheme and
reason, and calls the scheme selector during the next context build. A FIX failure while using
`SUPPORT_MANOEUVRE` preferentially drives the next viable plan toward envelopment rather than another
SBF retry.

## 6. Route safety retained

The revised v0.3.23 routing behaviour remains part of the branch:
- SBF friendly-side restriction;
- enemy exclusion routing;
- lane ownership for LEFT/RIGHT detours;
- slope checks;
- safe-route quality considered during COA/scheme evaluation.

## 7. Out of scope for this test

Do not use this build to judge final weapon employment. Explicit `doFire`, MG burst/suppression
cadence, grenade/AT fire control and individual target distribution remain the next pass.

## Expected benchmark markers

```text
TACTICAL ROLES scheme=SUPPORT_MANOEUVRE: ...
... LIVE NAV ...   (Zeus white route)
Fixing element failed to establish useful sight; requesting platoon tactic change
TACTICAL REASSESSMENT: failure=FIX_NO_LOS failedScheme=SUPPORT_MANOEUVRE
TACTICAL ROLES scheme=DOUBLE_ENVELOPMENT: ...
MANOEUVRE_LEFT READY scheme=DOUBLE_ENVELOPMENT ...
MANOEUVRE_RIGHT READY scheme=DOUBLE_ENVELOPMENT ...
... H-HOUR: READY gate passed ...
```
