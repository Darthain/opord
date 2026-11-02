/*
    ARTIC v0.3.30.1 - authoritative section-task lifecycle transition.

    The task identity is planId + taskId. COMPLETE / FAILED / ABORTED are terminal for
    that identity. A replacement plan receives a new taskId and may start again from ASSIGNED.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_planId","",[""]],
    ["_taskId","",[""]],
    ["_newState","",[""]],
    ["_reason","",[""]]
];
if (isNull _group || {_planId isEqualTo ""} || {_taskId isEqualTo ""} || {_newState isEqualTo ""}) exitWith {false};

private _curPlan = _group getVariable ["ARTIC_platoonPlanId",""];
private _curTask = _group getVariable ["ARTIC_sectionTaskId",""];
if (_curPlan isNotEqualTo _planId || {_curTask isNotEqualTo _taskId}) exitWith {
    [format ["TASK STATE REJECTED stale identity requested=%1/%2 current=%3/%4 -> %5",
        _planId,_taskId,_curPlan,_curTask,toUpper _newState],groupId _group] call ARTIC_fnc_debug;
    false
};

private _statePlan = _group getVariable ["ARTIC_sectionTaskStatePlanId",""];
private _stateTask = _group getVariable ["ARTIC_sectionTaskStateTaskId",""];
private _old = if (_statePlan isEqualTo _planId && {_stateTask isEqualTo _taskId}) then {
    toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"])
} else {
    "ASSIGNED"
};
private _next = toUpper _newState;
if (_old isEqualTo _next) exitWith {true};

private _terminal = ["COMPLETE","FAILED","ABORTED"];
if (_old in _terminal) exitWith {
    [format ["TASK STATE REJECTED plan=%1 task=%2 %3 -> %4%5",
        _planId,_taskId,_old,_next,if (_reason isEqualTo "") then {""} else {format [" reason=%1",_reason]}],groupId _group] call ARTIC_fnc_debug;
    false
};

private _allowed = switch (_old) do {
    case "ASSIGNED": {["DEPLOYING","READY","EXECUTING","COMPLETE","FAILED","ABORTED"]};
    case "DEPLOYING": {["READY","EXECUTING","COMPLETE","FAILED","ABORTED"]};
    case "READY": {["EXECUTING","COMPLETE","FAILED","ABORTED"]};
    case "EXECUTING": {["COMPLETE","FAILED","ABORTED"]};
    default {["ASSIGNED","DEPLOYING","READY","EXECUTING","COMPLETE","FAILED","ABORTED"]};
};
if !(_next in _allowed) exitWith {
    [format ["TASK STATE REJECTED plan=%1 task=%2 illegal %3 -> %4",_planId,_taskId,_old,_next],groupId _group] call ARTIC_fnc_debug;
    false
};

_group setVariable ["ARTIC_sectionTaskState",_next,true];
_group setVariable ["ARTIC_sectionTaskStatePlanId",_planId,true];
_group setVariable ["ARTIC_sectionTaskStateTaskId",_taskId,true];
_group setVariable ["ARTIC_sectionTaskStateAt",time,true];
if (_reason isNotEqualTo "") then {_group setVariable ["ARTIC_sectionTaskStateReason",_reason,true];};
if (_next in ["FAILED","ABORTED"]) then {
    if ((_group getVariable ["ARTIC_sectionReadyPlanId",""]) isEqualTo _planId) then {_group setVariable ["ARTIC_sectionReadyPlanId","",true];};
    if ((_group getVariable ["ARTIC_hHourPlanId",""]) isEqualTo _planId) then {_group setVariable ["ARTIC_hHourPlanId","",true];};
};

[format ["TASK STATE plan=%1 task=%2 %3 -> %4%5",
    _planId,_taskId,_old,_next,if (_reason isEqualTo "") then {""} else {format [" reason=%1",_reason]}],groupId _group] call ARTIC_fnc_debug;
true
