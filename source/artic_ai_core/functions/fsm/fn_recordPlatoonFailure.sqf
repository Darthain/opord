/*
    ARTIC v0.3.30.1 - server: record one failure against the ACTIVE platoon plan and
    terminally abort every other child task of that plan.

    Failure settlement is delayed until all matching play handles are actually finished.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_gid","",[""]],
    ["_taskId","",[""]],
    ["_role","",[""]],
    ["_reason","UNKNOWN",[""]]
];
if (!isServer || {(count _node) isEqualTo 0}) exitWith {false};
private _plan = _node getOrDefault ["platoonPlan",createHashMap];
private _planId = _plan getOrDefault ["planId",""];
if (_planId isEqualTo "") exitWith {false};
private _status = toUpper (_plan getOrDefault ["status",""]);
if (_status in ["SUPERSEDED","COMPLETE"]) exitWith {false};

private _tasks = _plan getOrDefault ["sectionTasks",createHashMap];
private _expectedTask = _tasks getOrDefault [_gid,""];
if (_gid isNotEqualTo "" && {_expectedTask isNotEqualTo ""} && {_taskId isNotEqualTo _expectedTask}) exitWith {
    [format ["FSM SECTION FAILED ignored stale task plan=%1 section=%2 reported=%3 expected=%4 reason=%5",
        _planId,_gid,_taskId,_expectedTask,_reason],_node getOrDefault ["id","PLATOON"]] call ARTIC_fnc_debug;
    false
};

private _nid = _node getOrDefault ["id","PLATOON"];
private _class = [_reason] call ARTIC_fnc_classifyPlanFailure;
private _f = +(_plan getOrDefault ["failureHistory",[]]);
if ((_f findIf {
    (count _x) >= 4
    && {(_x param [0,""]) isEqualTo _gid}
    && {(_x param [1,""]) isEqualTo _taskId}
    && {(_x param [3,""]) isEqualTo _reason}
}) > -1) exitWith {true};
_f pushBack [_gid,_taskId,_role,_reason,time,_class];
_plan set ["failureHistory",_f];
_node set ["lastPlanFailureReason",_reason];
_node set ["lastPlanFailureClass",_class];

private _groups = (_node getOrDefault ["groups",[]]) select {!isNull _x};
private _failedGroup = grpNull;
{
    if ((groupId _x) isEqualTo _gid) exitWith {_failedGroup = _x;};
} forEach _groups;

if (!isNull _failedGroup && {_taskId isNotEqualTo ""}) then {
    private _st = toUpper (_failedGroup getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
    if !(_st in ["FAILED","COMPLETE","ABORTED"]) then {
        [_failedGroup,_planId,_taskId,"FAILED",_reason] call ARTIC_fnc_setSectionTaskState;
    };
};

[format ["FSM SECTION FAILED plan=%1 section=%2 role=%3 task=%4 reason=%5 class=%6",_planId,_gid,_role,_taskId,_reason,_class],_nid] call ARTIC_fnc_debug;

if !(_plan getOrDefault ["abortIssued",false]) then {
    _plan set ["abortIssued",true];
    _plan set ["abortReason",_reason];
    _plan set ["abortClass",_class];
    _plan set ["abortAt",time];

    {
        private _g = _x;
        private _tid = _tasks getOrDefault [groupId _g,_g getVariable ["ARTIC_sectionTaskId",""]];
        if (_tid isNotEqualTo "") then {
            if ((groupId _g) isEqualTo _gid) then {
                _g setVariable ["ARTIC_planAbortId",_planId,true];
                _g setVariable ["ARTIC_tacticalExecutionArmed",false,true];
            } else {
                [_g,_planId,_tid,format ["PLAN_ABORT:%1",_reason]] call ARTIC_fnc_abortSectionTask;
            };
        } else {
            _g setVariable ["ARTIC_planAbortId",_planId,true];
            _g setVariable ["ARTIC_tacticalExecutionArmed",false,true];
        };
    } forEach _groups;

    [format ["FSM PLAN ABORT plan=%1 reason=%2 class=%3; child tasks terminal, waiting for play handles to settle",
        _planId,_reason,_class],_nid] call ARTIC_fnc_debug;
};
_node set ["platoonPlan",_plan];
true
