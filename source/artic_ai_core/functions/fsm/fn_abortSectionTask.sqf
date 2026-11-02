/*
    ARTIC v0.3.30.1 - abort one exact section task without touching a replacement task.
    The running play is not force-terminated: ARTIC_planAbortId + terminal task state make
    ARTIC_fnc_isPlayStale true and allow the script to unwind through identity-safe cleanup.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_planId","",[""]],
    ["_taskId","",[""]],
    ["_reason","PLAN_SUPERSEDED",[""]]
];
if (isNull _group || {_planId isEqualTo ""} || {_taskId isEqualTo ""}) exitWith {false};
if ((_group getVariable ["ARTIC_platoonPlanId",""]) isNotEqualTo _planId
    || {(_group getVariable ["ARTIC_sectionTaskId",""]) isNotEqualTo _taskId}) exitWith {false};

private _state = toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
if !(_state in ["COMPLETE","FAILED","ABORTED"]) then {
    [_group,_planId,_taskId,"ABORTED",_reason] call ARTIC_fnc_setSectionTaskState;
};
_group setVariable ["ARTIC_planAbortId",_planId,true];
_group setVariable ["ARTIC_tacticalExecutionArmed",false,true];
_group setVariable ["ARTIC_platoonTacticalReleased",false,true];
if ((_group getVariable ["ARTIC_hHourPlanId",""]) isEqualTo _planId) then {
    _group setVariable ["ARTIC_hHourPlanId","",true];
};
if ((_group getVariable ["ARTIC_sectionReadyPlanId",""]) isEqualTo _planId) then {
    _group setVariable ["ARTIC_sectionReadyPlanId","",true];
};
[format ["FSM TASK ABORT plan=%1 task=%2 state=%3 reason=%4",_planId,_taskId,
    _group getVariable ["ARTIC_sectionTaskState","?"],_reason],groupId _group] call ARTIC_fnc_debug;
true
