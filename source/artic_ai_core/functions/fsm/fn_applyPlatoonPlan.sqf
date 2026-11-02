/*
    Reapply immutable section roles/task identity from the active platoon plan.
    Networked setVariable writes are only issued when a value actually changed; this
    function is called by the CBA clockwork and must not create per-tick network churn.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_groups",[],[[]]]
];
if ((count _node) isEqualTo 0) exitWith {false};
private _plan = _node getOrDefault ["platoonPlan",createHashMap];
private _status = toUpper (_plan getOrDefault ["status",""]);
if !(_status in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]) exitWith {false};

private _roles = _plan getOrDefault ["sectionRoles",createHashMap];
private _corridors = _plan getOrDefault ["sectionCorridors",createHashMap];
private _deployment = _plan getOrDefault ["sectionDeployment",createHashMap];
private _tasks = _plan getOrDefault ["sectionTasks",createHashMap];
private _planId = _plan getOrDefault ["planId",""];
private _revision = _plan getOrDefault ["revision",0];
private _scheme = _plan getOrDefault ["scheme","HOLD"];

{
    private _g = _x;
    if (!isNull _g) then {
        private _gid = groupId _g;
        private _frozenRole = _roles getOrDefault [_gid,"RESERVE"];
        if ((_g getVariable ["ARTIC_schemeRole",""]) isNotEqualTo _frozenRole) then {
            _g setVariable ["ARTIC_schemeRole",_frozenRole,true];
        };

        private _frozenCorridor = _corridors getOrDefault [_gid,[]];
        if ((_g getVariable ["ARTIC_battleCorridor",[]]) isNotEqualTo _frozenCorridor) then {
            _g setVariable ["ARTIC_battleCorridor",+_frozenCorridor,true];
        };

        private _frozenDeployment = _deployment getOrDefault [_gid,[]];
        if ((_g getVariable ["ARTIC_battleDeploymentPos",[]]) isNotEqualTo _frozenDeployment) then {
            _g setVariable ["ARTIC_battleDeploymentPos",+_frozenDeployment,true];
        };

        if ((_g getVariable ["ARTIC_tacticalScheme",""]) isNotEqualTo _scheme) then {
            _g setVariable ["ARTIC_tacticalScheme",_scheme,true];
        };
        if ((_g getVariable ["ARTIC_platoonPlanId",""]) isNotEqualTo _planId) then {
            _g setVariable ["ARTIC_platoonPlanId",_planId,true];
        };
        if ((_g getVariable ["ARTIC_platoonPlanRevision",-1]) isNotEqualTo _revision) then {
            _g setVariable ["ARTIC_platoonPlanRevision",_revision,true];
        };

        private _frozenTask = _tasks getOrDefault [_gid,""];
        if ((_g getVariable ["ARTIC_sectionTaskId",""]) isNotEqualTo _frozenTask) then {
            _g setVariable ["ARTIC_sectionTaskId",_frozenTask,true];
        };
    };
} forEach _groups;
true
