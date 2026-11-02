/* Signal READY against one immutable plan/task. Safe from HC/client via CBA server event. */
params [
    ["_group",grpNull,[grpNull]],
    ["_phase","READY",[""]]
];
if (isNull _group) exitWith {false};
private _planId = _group getVariable ["ARTIC_platoonPlanId",""];
private _taskId = _group getVariable ["ARTIC_sectionTaskId",""];
if (_planId isEqualTo "" || {_taskId isEqualTo ""}) exitWith {false};

private _state = toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
if (_state in ["FAILED","ABORTED","COMPLETE"]) exitWith {
    [format ["FSM SECTION READY rejected terminal plan=%1 task=%2 state=%3",_planId,_taskId,_state],groupId _group] call ARTIC_fnc_debug;
    false
};
if (_state isEqualTo "READY" && {(_group getVariable ["ARTIC_sectionReadyPlanId",""]) isEqualTo _planId}) exitWith {true};

if !([_group,_planId,_taskId,"READY","SECTION_READY"] call ARTIC_fnc_setSectionTaskState) exitWith {false};
_group setVariable ["ARTIC_sectionReadyPlanId",_planId,true];
["ARTIC_sectionReady",[
    _group getVariable ["ARTIC_commanderId",""],
    _group getVariable ["ARTIC_formationId",""],
    groupId _group,
    _planId,
    _taskId,
    _group getVariable ["ARTIC_schemeRole",""],
    _phase,
    time
]] call CBA_fnc_serverEvent;
true
