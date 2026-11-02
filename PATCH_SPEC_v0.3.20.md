# ARTIC AI v0.3.20-alpha patch specification

## Problem isolated by v0.3.19

The latest Stratis radar benchmark showed that the platoon COA, section guides and section commanders were still healthy (`owner=PLATOON_GUIDE`, `wp=0`, `expectedDelta=0`) while the visible body of each section diverged. The remaining unguarded layer was subordinate infantry movement.

## Authority model

During ARTIC guide-owned movement:

1. EAST commander owns strategic purpose only (`SEIZE/ATTACK OBJ_1`).
2. Platoon planner owns COA, axis, RELEASE, HOLD and section route assignment.
3. Section/fireteam guides own local formation references.
4. ARTIC individual executor owns every soldier's current movement destination and survival reaction.
5. Arma owns only `MOVE`/`PATH`, navmesh/pathfinding, obstacle avoidance and animation.

No vanilla group waypoint, `doFollow` fallback or subordinate FSM movement is allowed to exist in parallel with ARTIC guide movement.

## Implemented controls

### Commander layer
- Removed periodic 120-second re-issue of an unchanged objective.
- Re-issue occurs only on objective change or ARTIC ORBAT group-set change.
- Added separate `ARTIC_strategic*` and `ARTIC_execution*` metadata.

### Infantry FSM boundary
- `ARTIC_takeInfantryFSMControl = true` by default.
- While ARTIC owns guide movement: `disableAI "FSM"`, `disableAI "AUTOCOMBAT"`, `enableAI "MOVE"`, `enableAI "PATH"` for every local fit infantryman.
- FSM is restored if ARTIC fully releases the group/order.

### Per-soldier destination authority
- Movement watchdog now checks all fit local soldiers.
- `expectedDestination` is compared to ARTIC's slot/guide target.
- Large mismatch emits `UNITCTRL CONFLICT` and ARTIC immediately reissues its `doMove`.
- Physical no-progress emits `UNITCTRL STALL` and triggers recovery.
- Moving FORMATION slots are refreshed on a short cadence without `unitReady` gating.

### Removal of vanilla fallbacks
- Missing FORMATION slots no longer call `doFollow leader`.
- ARTIC rebuilds the slot table; if still unavailable, an emergency guide-relative slot is used.
- Unexpected group waypoints are deleted and logged.

### Reposition pacing
- `REPOSITION_FOR_ATTACK` remains FILE/COLUMN.
- During this phase guide speed depends on median longitudinal body lag only.
- Lateral/shape error is diagnostic and does not slow a column with `bodyLag=0`.
- A soldier slightly ahead of a moving slot is speed-limited rather than given sticky `doStop`.

## Regression signals

Healthy:

```text
MOVEAUTH owner=PLATOON_GUIDE ... conflicts=0 stalls=0 wp=0 ... FSM=true reposition=true
```

Competing movement source:

```text
UNITCTRL CONFLICT unit=... role=... task=FORMATION cmd=MOVE engine=... ARTIC=... delta=... owner=PLATOON_GUIDE
```

Engine movement stall:

```text
UNITCTRL STALL unit=... role=... noProgress=... target=... cmd=... expectedDelta=...
```

Unexpected waypoint:

```text
CONTROL CONFLICT: removed N unexpected group waypoint(s) ...
```

## Next benchmark success criteria

- No repeated EAST_CMD re-assignment of unchanged OBJ_1 after 120 seconds.
- Sections complete the rotated COA reposition without members peeling toward the Eden objective.
- `wp=0` throughout ARTIC guide ownership.
- No sustained `UNITCTRL CONFLICT` after ARTIC reassertion.
- No persistent `UNITCTRL STALL` on multiple members of the same section.
- Reposition guide should remain NORMAL when `bodyLag=0`, regardless of temporary lateral shape error.
