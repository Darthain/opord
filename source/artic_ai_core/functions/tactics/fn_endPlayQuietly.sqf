/*
    ARTIC v0.3.30.1 - identity-safe cleanup for a stale/superseded tactical play.

    This never reports failure and never modifies a replacement task. Cleanup is performed
    only while the group still owns the exact plan/task captured by the ending script.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_planId","",[""]],
    ["_taskId","",[""]],
    ["_why","plan changed",[""]]
];
if (isNull _group) exitWith {false};

private _sameTask = (_group getVariable ["ARTIC_platoonPlanId",""]) isEqualTo _planId
    && {(_group getVariable ["ARTIC_sectionTaskId",""]) isEqualTo _taskId};

if (_sameTask) then {
    {
        if (local _x && {alive _x}) then {
            _x setVariable ["ARTIC_moveLocked",false,true];
            _x forceSpeed -1;
            [_x,"FORMATION",[],objNull,20,6] call ARTIC_fnc_setUnitTask;
            _x setVariable ["ARTIC_idleTask",true,false];
        };
    } forEach units _group;

    _group setVariable ["ARTIC_currentPlan","",true];
    _group setVariable ["ARTIC_tacticalGuideActive",false,false];
    _group setVariable ["ARTIC_movementOwner","FORMATION",false];
    _group setVariable ["ARTIC_tacticalFormationOverride","",false];
    _group setVariable ["ARTIC_movementPhase","APPROACH",false];
    _group setVariable ["ARTIC_planOwner",-1,true];
    _group setVariable ["ARTIC_lastPlanEnd",time,true];
    _group enableAttack false;
    _group setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
};

[format ["PLAY QUIET END plan=%1 task=%2 sameTask=%3 reason=%4",_planId,_taskId,_sameTask,_why],groupId _group] call ARTIC_fnc_debug;
true
