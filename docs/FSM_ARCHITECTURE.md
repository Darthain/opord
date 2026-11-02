> **v0.3.29 runtime note:** the visual BI `.fsm` files in this package are architecture/reference diagrams. The first live migration layer is the server-side **CBA Platoon state machine** described in `FSM_ARCHITECTURE_AND_MIGRATION_v0.3.29.md`. Section and Fireteam runtime migration remains disabled for this test build.

# ARTIC FSM architecture foundation (v0.3.28-alpha)

This branch adds real scripted `.fsm` files without enabling them by default. The purpose is to freeze the hierarchy and interfaces before replacing the v0.3.27 polling/step ownership model.

## Runtime choice

- Commander / Platoon / Section / Fireteam use `execFSM` because they need arbitrary ARTIC context and explicit task data.
- A future *leaf navigation command FSM* may use `doFSM` / `commandFSM` with `moveTo`; it is intentionally separate from the tactical Fireteam FSM. Because Arma 3 documents `moveToFailed` as unimplemented/always false, ARTIC should detect local navigation failure with progress/time/distance checks rather than trusting `moveToFailed`.
- `ARTIC_useFSMHierarchy` and `ARTIC_useFireteamFSM` default to `false` in this foundation build.

## Hierarchy

```text
ARTIC_Commander.fsm
  ASSESS -> SELECT OBJECTIVE -> ISSUE INTENT -> MONITOR -> REASSESS
        |
        v
ARTIC_Platoon.fsm
  ASSESS -> SELECT SCHEME -> PLAN ROUTES -> REPOSITION -> DEPLOY
                                      -> READY CHECK -> EXECUTE -> REASSESS
        |
        v
ARTIC_Section.fsm
  ASSESS -> MOVE / FIX / MANOEUVRE / BLOCK / RESERVE / HOLD / WITHDRAW
        |
        v
ARTIC_Fireteam.fsm
  RECEIVE -> ASSESS -> MOVE / BOUND / DEPLOY / ASSAULT / BREAK CONTACT
                         -> READY / FAILED
```

## Fireteam task schema V1

Tasks are fixed arrays so they can be copied through `setVariable [..., true]` and survive locality changes without relying on HashMap network serialization.

| Index | Field | Type | Meaning |
|---:|---|---|---|
| 0 | schema | String | `ARTIC_FT_TASK_V1` |
| 1 | id | String | unique task ID |
| 2 | type | String | task type |
| 3 | issuedAt | Number | mission time |
| 4 | issuer | String | section/platoon source |
| 5 | priority | Number | 0-100 |
| 6 | destination | PositionATL | task anchor / end point |
| 7 | corridor | Array<PositionATL> | permitted local gates/corridor |
| 8 | threatPos | PositionATL | known/estimated threat centre |
| 9 | target | Object | optional live target |
| 10 | facing | Number | required facing, -1 = derive |
| 11 | sector | Array | fire/observation sector |
| 12 | frontage | Number | desired team frontage metres |
| 13 | spacing | Number | desired soldier spacing metres |
| 14 | tolerance | Number | completion tolerance metres |
| 15 | deadline | Number | mission time, -1 = none |
| 16 | syncKey | String | section-controlled GO/ready gate |
| 17 | rules | Array | key/value rule pairs |
| 18 | meta | Array | optional doctrine/debug metadata |

Supported task types: `MOVE`, `FOLLOW`, `BOUND`, `DEPLOY`, `OBSERVE`, `SUPPRESS`, `ENGAGE`, `ASSAULT`, `BLOCK`, `HOLD`, `WITHDRAW`, `REORGANISE`.

Create a task with `ARTIC_fnc_makeFireteamTask`, validate with `ARTIC_fnc_validateFireteamTask`, and publish it with `ARTIC_fnc_setFireteamTask`.

Example:

```sqf
private _task = [
    "BOUND",
    [4120,3870,0],
    [[4050,3910,0],[4090,3890,0],[4120,3870,0]],
    [4300,3750,0],
    objNull,
    135,
    [100,170],
    22,
    8,
    12,
    time + 90,
    "A1-1_BOUND_2",
    [["allowLocalReplan",true],["roe","RETURN_FIRE"]],
    "SECTION",
    70
] call ARTIC_fnc_makeFireteamTask;

[_group,"A",_task] call ARTIC_fnc_setFireteamTask;
```

## Fireteam transition contract

```text
IDLE
  -> RECEIVE_TASK                         task exists
RECEIVE_TASK
  -> ASSESS
ASSESS
  -> FAILED                               <2 fit members
  -> BREAK_CONTACT                        WITHDRAW
  -> REORGANISE                           REORGANISE
  -> ASSAULT_PREP                         ASSAULT
  -> BOUND_MOVE                           BOUND
  -> DEPLOY                               DEPLOY/OBSERVE/SUPPRESS/ENGAGE/BLOCK/HOLD
  -> PLAN_LOCAL_MOVE                      MOVE/FOLLOW
PLAN_LOCAL_MOVE -> MOVE
MOVE -> READY                             75% inside destination tolerance
BOUND_MOVE -> BOUND_SET                   bound occupied
BOUND_SET -> BOUND_MOVE                   section releases sync key
ASSAULT_PREP -> ASSAULT                   section releases sync key
ASSAULT -> CONSOLIDATE                    LOA/destination occupied
BREAK_CONTACT -> READY                    withdrawal position occupied
ANY ACTIVE STATE -> RECEIVE_TASK          task revision changes
ANY ACTIVE STATE -> REORGANISE            team becomes ineffective/degraded
ANY ACTIVE STATE -> FAILED                deadline expires
```

The tactical Fireteam FSM does **not** yet issue per-soldier locomotion. That is deliberate. Its state and task contract are now stable; the next navigation pass can connect `MOVE`, `BOUND_MOVE`, `DEPLOY`, and `ASSAULT` to ARTIC route gates plus Arma short-range locomotion without changing the upper hierarchy.

## Fireteam outputs to Section FSM

Each team publishes:

```text
ARTIC_fireteamState_A/B
ARTIC_fireteamStateAt_A/B
ARTIC_fireteamReady_A/B
ARTIC_fireteamFailure_A/B
ARTIC_fireteamTask_A/B
ARTIC_fireteamTaskRev_A/B
```

This lets the Section FSM reason about two teams rather than eight individual soldiers.

## Start functions

These are manual/opt-in in this foundation branch:

```sqf
["EAST_CMD"] call ARTIC_fnc_startCommanderFSM;
["EAST_CMD","B1_PL"] call ARTIC_fnc_startPlatoonFSM;
[_group] call ARTIC_fnc_startSectionFSM;
[_group,"A"] call ARTIC_fnc_startFireteamFSM;
[_group,"B"] call ARTIC_fnc_startFireteamFSM;
```

Do not enable the new hierarchy and the existing v0.3.27 step loops as simultaneous movement authorities yet. The next integration phase should transfer ownership one layer at a time.
