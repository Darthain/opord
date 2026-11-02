/*
    Create the immutable tactical plan record for one platoon.
    v0.3.29 scope: role/corridor ownership + H-hour/task identity. Movement remains v0.3.27.
    v0.3.30: resets per-plan phase latches and records sections committed in place by
    contact-aware replanning.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_ctx",createHashMap,[createHashMap]],
    ["_groups",[],[[]]]
];
if (!isServer || {(count _node) isEqualTo 0} || {(count _ctx) isEqualTo 0}) exitWith {createHashMap};
private _old = _node getOrDefault ["platoonPlan",createHashMap];
private _oldStatus = toUpper (_old getOrDefault ["status",""]);
if (_oldStatus in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]) exitWith {_old};

private _revision = (_node getOrDefault ["platoonPlanRevision",0]) + 1;
_node set ["platoonPlanRevision",_revision];
private _nodeId = _node getOrDefault ["id","PLATOON"];
private _planId = format ["%1_P%2",_nodeId,_revision];
private _scheme = _ctx getOrDefault ["schemeMode","HOLD"];
private _roles = createHashMap;
private _corridors = createHashMap;
private _deployment = createHashMap;
private _tasks = createHashMap;
private _required = [];
private _requiredComplete = [];
private _committed = [];

{
    private _g = _x;
    if (!isNull _g) then {
        private _gid = groupId _g;
        private _role = _g getVariable ["ARTIC_schemeRole","RESERVE"];
        private _taskId = format ["%1_SEC_%2",_planId,_forEachIndex + 1];
        _roles set [_gid,_role];
        _corridors set [_gid,+(_g getVariable ["ARTIC_battleCorridor",[]])];
        _deployment set [_gid,+(_g getVariable ["ARTIC_battleDeploymentPos",[]])];
        _tasks set [_gid,_taskId];
        if (_role in ["FIX","BLOCK","MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"]) then {_required pushBackUnique _gid;};
        if (_role in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"]) then {_requiredComplete pushBackUnique _gid;};

        _g setVariable ["ARTIC_platoonPlanId",_planId,true];
        _g setVariable ["ARTIC_platoonPlanRevision",_revision,true];
        _g setVariable ["ARTIC_sectionTaskId",_taskId,true];
        _g setVariable ["ARTIC_sectionTaskRole",_role,true];
        _g setVariable ["ARTIC_sectionReadyPlanId","",true];
        _g setVariable ["ARTIC_sectionCompletePlanId","",true];
        _g setVariable ["ARTIC_sectionTaskState","ASSIGNED",true];
        _g setVariable ["ARTIC_sectionTaskStatePlanId",_planId,true];
        _g setVariable ["ARTIC_sectionTaskStateTaskId",_taskId,true];
        _g setVariable ["ARTIC_sectionTaskStateAt",time,true];
        _g setVariable ["ARTIC_sectionTaskStateReason","",true];
        _g setVariable ["ARTIC_hHourPlanId","",true];
        _g setVariable ["ARTIC_hHourConsumedPlanId","",true];
        _g setVariable ["ARTIC_hHourConsumedTaskId","",true];
        _g setVariable ["ARTIC_planFailureReason","",true];
        _g setVariable ["ARTIC_planFailureAt",-1e6,true];
        // v0.3.30: phase latches from the previous plan must not leak into this one. A stale
        // partner phase of ABORT failed the next plan's synchronisation in 0.3.29.
        _g setVariable ["ARTIC_planAbortId","",true];
        _g setVariable ["ARTIC_manoeuvrePhase","",true];
        _g setVariable ["ARTIC_fixState","",true];
        _g setVariable ["ARTIC_fixReady",false,true];
        _g setVariable ["ARTIC_blockState","",true];
        _g setVariable ["ARTIC_blockReady",false,true];
        _g setVariable ["ARTIC_blockDoneTaskId","",true];
        if (_g getVariable ["ARTIC_committedInPlace",false]) then {_committed pushBack _gid;};
    };
} forEach _groups;

private _plan = createHashMapFromArray [
    ["planId",_planId],
    ["revision",_revision],
    ["status","ACTIVE"],
    ["phase","DEPLOY"],
    ["createdAt",time],
    ["battlefieldId",_ctx getOrDefault ["battlefieldId",""]],
    ["battleContextId",_ctx getOrDefault ["id",""]],
    ["scheme",_scheme],
    ["axis",_ctx getOrDefault ["axis",0]],
    ["sectionRoles",_roles],
    ["sectionCorridors",_corridors],
    ["sectionDeployment",_deployment],
    ["sectionTasks",_tasks],
    ["requiredReady",_required],
    ["requiredComplete",_requiredComplete],
    ["readySet",[]],
    ["completeSet",[]],
    ["failureHistory",[]],
    ["hHourIssued",false],
    ["contactMode",_committed isNotEqualTo []],
    ["committed",_committed],
    ["sbfMode",_ctx getOrDefault ["sbfMode",""]],
    ["hHourAt",-1],
    ["supersededBy",""]
];
_node set ["platoonPlan",_plan];
private _logic = _node getOrDefault ["logic",objNull];
if (!isNull _logic) then {
    _logic setVariable ["ARTIC_platoonPlanId",_planId,true];
    _logic setVariable ["ARTIC_platoonPlanRevision",_revision,true];
    _logic setVariable ["ARTIC_platoonRuntimeState","DEPLOY",true];
};

[format ["FSM PLAN CREATED plan=%1 rev=%2 scheme=%3 axis=%4 roles=[%5]%6",_planId,_revision,_scheme,round (_ctx getOrDefault ["axis",0]),
    (_groups apply {format ["%1=%2",groupId _x,_x getVariable ["ARTIC_schemeRole","RESERVE"]]}) joinString ",",
    if (_committed isEqualTo []) then {""} else {format [" CONTACT-AWARE committed in place=[%1]",_committed joinString ","]}],_nodeId] call ARTIC_fnc_debug;
_plan
