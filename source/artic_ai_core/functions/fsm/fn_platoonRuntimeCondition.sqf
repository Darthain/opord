/* Conditions for the live CBA platoon state machine. */
params [
    ["_logic",objNull,[objNull]],
    ["_condition","",[""]]
];
if (isNull _logic) exitWith {false};
private _cid = _logic getVariable ["ARTIC_runtimeCommanderId",""];
private _nid = _logic getVariable ["ARTIC_runtimeFormationId",_logic getVariable ["FormationId",""]];
private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
if ((count _node) isEqualTo 0) exitWith {false};
private _allGroups = (_node getOrDefault ["groups",[]]) select {!isNull _x};
private _groups = _allGroups select {({alive _x} count units _x) > 0};
private _plan = _node getOrDefault ["platoonPlan",createHashMap];
private _planId = _plan getOrDefault ["planId",""];
private _status = toUpper (_plan getOrDefault ["status",""]);
private _activePlan = _planId isNotEqualTo "" && {_status in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]};
private _failure = "";
private _failureAt = -1e6;
// Prefer the plan-owned event history so a section that becomes combat ineffective or
// loses all living members cannot make its already-reported failure disappear.
{
    if ((count _x) >= 5) then {
        private _fr = _x param [3,""];
        private _fa = _x param [4,-1e6];
        if (_fr isNotEqualTo "" && {_fa > _failureAt}) then {_failure = _fr; _failureAt = _fa;};
    };
} forEach (_plan getOrDefault ["failureHistory",[]]);
// Compatibility fallback for a failure set locally before its CBA event reaches server.
{
    private _fr = _x getVariable ["ARTIC_planFailureReason",""];
    private _fa = _x getVariable ["ARTIC_planFailureAt",-1e6];
    if (_fr isNotEqualTo "" && {_fa > _failureAt}) then {_failure = _fr; _failureAt = _fa;};
} forEach _allGroups;
private _tasks = _plan getOrDefault ["sectionTasks",createHashMap];
private _sectionPlayActive = (_allGroups findIf {
    private _tid = _tasks getOrDefault [groupId _x,""];
    [_x,_planId,_tid] call ARTIC_fnc_isSectionPlayActive
}) > -1;
private _settledFailure = _failure isNotEqualTo "" && {!_sectionPlayActive} && {(time - _failureAt) < 180};
private _required = _plan getOrDefault ["requiredReady",[]];
private _requiredComplete = _plan getOrDefault ["requiredComplete",[]];
private _complete = _groups select {
    private _gid = groupId _x;
    _gid in _requiredComplete && {(_x getVariable ["ARTIC_sectionCompletePlanId",""]) isEqualTo _planId}
};
private _planComplete = _activePlan && {_requiredComplete isNotEqualTo []} && {(count _complete) isEqualTo (count _requiredComplete)};

switch (toUpper _condition) do {
    case "HAS_ACTIVE_PLAN": {_activePlan};
    case "EXECUTION_ARMED": {_activePlan && {_groups isNotEqualTo []} && {({_x getVariable ["ARTIC_tacticalExecutionArmed",false]} count _groups) > 0}};
    case "HHOUR_ISSUED": {_activePlan && {_plan getOrDefault ["hHourIssued",false]}};
    case "FAILURE_SETTLED": {_activePlan && {_settledFailure}};
    case "PLAN_COMPLETE": {_planComplete};
    case "NEW_ACTIVE_PLAN": {
        _activePlan && {_planId isNotEqualTo (_logic getVariable ["ARTIC_reassessOldPlanId",""])}
    };
    default {false};
}
