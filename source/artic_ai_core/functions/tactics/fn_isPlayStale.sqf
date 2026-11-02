/*
    ARTIC v0.3.30.1 - is a running tactical play still the current task of its section?

    A play is stale when locality changed, plan/task identity changed, the plan was aborted,
    the exact task became terminal, or platoon execution authority was withdrawn.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_planId","",[""]],
    ["_taskId","",[""]],
    ["_requireArmed",true,[true]]
];
if (isNull _group || {!local _group}) exitWith {true};
if (_planId isNotEqualTo "" && {(_group getVariable ["ARTIC_platoonPlanId",""]) isNotEqualTo _planId}) exitWith {true};
if ((_group getVariable ["ARTIC_sectionTaskId",""]) isNotEqualTo _taskId) exitWith {true};
if (_planId isNotEqualTo "" && {(_group getVariable ["ARTIC_planAbortId",""]) isEqualTo _planId}) exitWith {true};
private _state = toUpper (_group getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
if (_state in ["FAILED","ABORTED","COMPLETE"]) exitWith {true};
_requireArmed && {!(_group getVariable ["ARTIC_tacticalExecutionArmed",false])}
