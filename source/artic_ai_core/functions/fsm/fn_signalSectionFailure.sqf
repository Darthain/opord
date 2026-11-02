/* Report one terminal section failure against the current immutable plan/task. */
params [
    ["_group",grpNull,[grpNull]],
    ["_reason","UNKNOWN",[""]]
];
if (isNull _group) exitWith {false};
private _planId = _group getVariable ["ARTIC_platoonPlanId",""];
private _taskId = _group getVariable ["ARTIC_sectionTaskId",""];
if (_planId isEqualTo "" || {_taskId isEqualTo ""}) exitWith {false};

private _state = toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
if (_state in ["COMPLETE","ABORTED"]) exitWith {
    [format ["FSM SECTION FAILED ignored terminal plan=%1 task=%2 state=%3 reason=%4",_planId,_taskId,_state,_reason],groupId _group] call ARTIC_fnc_debug;
    false
};
if (_state isEqualTo "FAILED") exitWith {false};

if !([_group,_planId,_taskId,"FAILED",_reason] call ARTIC_fnc_setSectionTaskState) exitWith {false};
_group setVariable ["ARTIC_planFailureReason",_reason,true];
_group setVariable ["ARTIC_planFailureAt",time,true];

["ARTIC_sectionFailed",[
    _group getVariable ["ARTIC_commanderId",""],
    _group getVariable ["ARTIC_formationId",""],
    groupId _group,
    _planId,
    _taskId,
    _group getVariable ["ARTIC_schemeRole",""],
    _reason,
    time
]] call CBA_fnc_serverEvent;
true
