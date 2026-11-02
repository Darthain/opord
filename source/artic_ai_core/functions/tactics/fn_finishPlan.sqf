/*
    ARTIC v0.3.30.1 - finish a CURRENT tactical play without destroying a replacement task.

    Optional planId/taskId make cleanup identity-safe. Stale/superseded scripts must use
    ARTIC_fnc_endPlayQuietly instead.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_cooldown",8,[0]],
    ["_planId","",[""]],
    ["_taskId","",[""]]
];
if (isNull _group) exitWith {false};

private _identityProvided = _planId isNotEqualTo "" && {_taskId isNotEqualTo ""};
if (_identityProvided && {
    (_group getVariable ["ARTIC_platoonPlanId",""]) isNotEqualTo _planId
    || {(_group getVariable ["ARTIC_sectionTaskId",""]) isNotEqualTo _taskId}
}) exitWith {
    [format ["finishPlan ignored stale identity requested=%1/%2 current=%3/%4",
        _planId,_taskId,_group getVariable ["ARTIC_platoonPlanId",""],_group getVariable ["ARTIC_sectionTaskId",""]],groupId _group] call ARTIC_fnc_debug;
    false
};

private _endingPlan = _group getVariable ["ARTIC_currentPlan",""];
private _endingPhase = _group getVariable ["ARTIC_manoeuvrePhase",""];
private _platoonPlanId = if (_planId isNotEqualTo "") then {_planId} else {_group getVariable ["ARTIC_platoonPlanId",""]};
private _sectionTaskId = if (_taskId isNotEqualTo "") then {_taskId} else {_group getVariable ["ARTIC_sectionTaskId",""]};

if (_endingPlan isEqualTo "PLATOON_MANOEUVRE") then {
    private _m = _group getVariable ["ARTIC_metrics",createHashMap];
    if (_endingPhase isEqualTo "COMPLETE") then {
        _m set ["attacksCompleted",(_m getOrDefault ["attacksCompleted",0]) + 1];
        if (_platoonPlanId isNotEqualTo "" && {_sectionTaskId isNotEqualTo ""}) then {
            _group setVariable ["ARTIC_sectionCompletePlanId",_platoonPlanId,true];
            [_group,_platoonPlanId,_sectionTaskId,"COMPLETE","MANOEUVRE_COMPLETE"] call ARTIC_fnc_setSectionTaskState;
            [format ["FSM SECTION COMPLETE plan=%1 task=%2 role=%3",_platoonPlanId,_sectionTaskId,_group getVariable ["ARTIC_schemeRole",""]],groupId _group] call ARTIC_fnc_debug;
        };
    } else {
        _m set ["attacksAborted",(_m getOrDefault ["attacksAborted",0]) + 1];
    };
    _group setVariable ["ARTIC_metrics",_m,false];
} else {
    if (_identityProvided) then {
        private _st = toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
        if !(_st in ["FAILED","ABORTED","COMPLETE"]) then {
            [_group,_platoonPlanId,_sectionTaskId,"COMPLETE",format ["%1_COMPLETE",_endingPlan]] call ARTIC_fnc_setSectionTaskState;
        };
    };
};

private _guide = _group getVariable ["ARTIC_guide",[]];
private _holdPos = if (_guide isNotEqualTo []) then {+(_guide select 0)} else {getPosATL leader _group};
[_group,_holdPos] call ARTIC_fnc_setSectionDestination;

{
    if (local _x && {alive _x}) then {
        _x setVariable ["ARTIC_moveLocked",false,true];
        _x forceSpeed -1;
        [_x,"FORMATION",[],objNull,20,8] call ARTIC_fnc_setUnitTask;
        _x setVariable ["ARTIC_idleTask",true,false];
    };
} forEach units _group;

_group setVariable ["ARTIC_currentPlan","",true];
_group setVariable ["ARTIC_tacticalGuideActive",false,false];
_group setVariable ["ARTIC_movementOwner","FORMATION",false];
_group setVariable ["ARTIC_tacticalFormationOverride","",false];
_group setVariable ["ARTIC_movementPhase","APPROACH",false];
if ((_group getVariable ["ARTIC_inContact",false])) then {_group setVariable ["ARTIC_contactAction","CHOOSE_ACTION",true];};
_group setVariable ["ARTIC_planOwner",-1,true];
_group setVariable ["ARTIC_lastPlanEnd",time,true];
_group setVariable ["ARTIC_planCooldownUntil",time + _cooldown,true];
_group enableAttack false;
_group setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
true
