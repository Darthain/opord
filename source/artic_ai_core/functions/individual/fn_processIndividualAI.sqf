/*
    Local individual-AI manager (v0.3.6).

    - Anchors are updated once per local ARTIC group (throttled inside the function).
    - Downed (incapacitated / ACE-unconscious) and mounted soldiers get no individual
      orders; any task they had is dropped once.
    - Idle task: every fit soldier in an ARTIC group without a task gets a FOLLOW task,
      so the danger reactions and cohesion governor run between plays too. In v0.3.5
      untasked soldiers exited individualStep and fell back to vanilla AI.
      Switch off with ARTIC_individualIdleTask = false.
*/
private _idle = missionNamespace getVariable ["ARTIC_individualIdleTask", true];
private _groups = [];
{
    if (local _x && {!isPlayer _x} && {(group _x) getVariable ["ARTIC_enabled",false]}) then {
        _groups pushBackUnique (group _x);
    };
} forEach allUnits;

{
    if (local _x) then {
        // v0.3.17: persistent fireteam membership only. Spatial references come only from
        // the section/fireteam guide hierarchy.
        [_x] call ARTIC_fnc_initFireteams;
        [_x] call ARTIC_fnc_sectionFormationStep;

        // Benchmark telemetry every 60 s while debug is enabled. These values are intended
        // for fixed regression missions (open / woods / village / night), not gameplay UI.
        if (missionNamespace getVariable ["ARTIC_debug",false]) then {
            private _nextM = _x getVariable ["ARTIC_nextMetricLog",time + 60];
            if (time >= _nextM) then {
                private _m = _x getVariable ["ARTIC_metrics",createHashMap];
                private _samples = _m getOrDefault ["slotSamples",0];
                private _slotAvg = if (_samples > 0) then {(_m getOrDefault ["slotErrorSum",0]) / _samples} else {0};
                [format ["METRICS slotAvg=%1m slotMax=%2m moves=%3/%4 moveFail=%5 sbf=%6/%7 attacks=%8/%9 abort=%10",
                    (round (_slotAvg * 10))/10,
                    round (_m getOrDefault ["slotErrorMax",0]),
                    _m getOrDefault ["movesCompleted",0],
                    _m getOrDefault ["movesAttempted",0],
                    _m getOrDefault ["movesFailed",0],
                    _m getOrDefault ["sbfSuccess",0],
                    _m getOrDefault ["sbfAttempts",0],
                    _m getOrDefault ["attacksCompleted",0],
                    _m getOrDefault ["attacksAttempted",0],
                    _m getOrDefault ["attacksAborted",0]
                ],groupId _x] call ARTIC_fnc_debug;
                _x setVariable ["ARTIC_nextMetricLog",time + 60,false];
            };
        };
    };
} forEach _groups;

// Running performance/locality check (development telemetry). This is deliberately
// lightweight and makes server/HC regressions visible long before v1.0.
if (missionNamespace getVariable ["ARTIC_debug",false]) then {
    private _nextPerf = missionNamespace getVariable ["ARTIC_nextPerfLog",time + 60];
    if (time >= _nextPerf) then {
        private _localAI = {local _x && {!isPlayer _x} && {(group _x) getVariable ["ARTIC_enabled",false]}} count allUnits;
        diag_log format ["[ARTIC][PERF] owner=%1 fps=%2 fpsMin=%3 localAI=%4 localGroups=%5",clientOwner,round (diag_fps * 10) / 10,round (diag_fpsMin * 10) / 10,_localAI,count _groups];
        missionNamespace setVariable ["ARTIC_nextPerfLog",time + 60];
    };
};

{
    private _u = _x;
    if (local _u && {!isPlayer _u} && {(group _u) getVariable ["ARTIC_enabled",false]}) then {
        if !([_u] call ARTIC_fnc_isFit) then {
            if (alive _u && {(_u getVariable ["ARTIC_unitTask",[]]) isNotEqualTo []}) then {
                [_u,true] call ARTIC_fnc_clearUnitTask;
            };
        } else {
            // v0.3.9: idle task, re-evaluated every tick for soldiers without a plan task
            // (idle tasks are refreshed in place, so a change of order must swap them).
            //   DEFEND / SUPPORT : STATIC hold where he stands once his current move is
            //                      done (DEFEND places men with plain doMove), no cohesion
            //   everything else  : FORMATION (section formation controller), or FOLLOW
            //                      (engine formation) when ARTIC_formationSystem = false
            private _task = _u getVariable ["ARTIC_unitTask",[]];
            if (_idle && {_task isEqualTo [] || {_u getVariable ["ARTIC_idleTask",false]}} && {!isPlayer leader group _u}) then {
                private _order = (group _u) getVariable ["ARTIC_executionOrderType",(group _u) getVariable ["ARTIC_orderType",""]];
                private _want = if (_order in ["DEFEND","SUPPORT"]) then {"STATIC"} else {
                    ["FOLLOW","FORMATION"] select (missionNamespace getVariable ["ARTIC_formationSystem",true])
                };
                private _have = _task param [0,""];
                if (_have isNotEqualTo _want) then {
                    if (_want isEqualTo "STATIC") then {
                        if (unitReady _u) then {
                            [_u,"STATIC",getPosATL _u,objNull,20,6] call ARTIC_fnc_setUnitTask;
                            _u setVariable ["ARTIC_idleTask",true,false];
                        };
                    } else {
                        [_u,_want,[],objNull,20,8] call ARTIC_fnc_setUnitTask;
                        _u setVariable ["ARTIC_idleTask",true,false];
                    };
                };
            };
            [_u] call ARTIC_fnc_individualStep;
        };
    };
} forEach allUnits;

// v0.3.19: inspect ownership after this tick's individual commands have been issued.
{if (local _x) then {[_x] call ARTIC_fnc_assertMovementControl;};} forEach _groups;
