/* Server: supersede the current plan after a settled tactical failure. */
params [
    ["_logic",objNull,[objNull]],
    ["_reason","TACTICAL_FAILURE",[""]]
];
if (!isServer || {isNull _logic}) exitWith {false};
private _cid = _logic getVariable ["ARTIC_runtimeCommanderId",""];
private _nid = _logic getVariable ["ARTIC_runtimeFormationId",_logic getVariable ["FormationId",""]];
private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
if ((count _node) isEqualTo 0) exitWith {false};
private _plan = _node getOrDefault ["platoonPlan",createHashMap];
if ((count _plan) isEqualTo 0) exitWith {false};
private _status = toUpper (_plan getOrDefault ["status",""]);
if (_status in ["SUPERSEDED","COMPLETE"]) exitWith {false};
private _planId = _plan getOrDefault ["planId",""];
private _tasks = _plan getOrDefault ["sectionTasks",createHashMap];
// v0.3.30: supersede on the ROOT cause (the failure that aborted the plan), not on whichever
// consequence was reported last while the other plays were ending.
private _rootReason = _plan getOrDefault ["abortReason",""];
if (_rootReason isNotEqualTo "") then {_reason = _rootReason;};
_plan set ["status","SUPERSEDED"];
_plan set ["phase","REASSESS"];
_plan set ["supersededAt",time];
_node set ["platoonPlan",_plan];
_node set ["lastFailedPlanId",_planId];
_node set ["lastFailedScheme",_plan getOrDefault ["scheme",""]];
// v0.3.30.2: a TIMING retry re-uses this axis instead of re-searching every axis
_node set ["lastFailedAxis",_plan getOrDefault ["axis",-1]];
_node set ["lastPlanFailureReason",_reason];
// v0.3.30: failure class drives reassessment. A first TIMING failure of a scheme retries the
// same scheme (the plan was sound, an element was late); CONTACT replans around the engaged
// section; TACTICAL changes the scheme as before.
private _class = [_reason] call ARTIC_fnc_classifyPlanFailure;
_node set ["lastPlanFailureClass",_class];
private _retries = _node getOrDefault ["timingRetries",createHashMap];
if (_class isEqualTo "TIMING") then {
    private _sch = _plan getOrDefault ["scheme",""];
    _retries set [_sch,(_retries getOrDefault [_sch,0]) + 1];
};
_node set ["timingRetries",_retries];
_node set ["executionStart",-1e6];
_node set ["march",createHashMap];
_logic setVariable ["ARTIC_platoonRuntimeState","REASSESS",true];
_logic setVariable ["ARTIC_reassessOldPlanId",_planId,false];
{
    private _g = _x;
    private _tid = _tasks getOrDefault [groupId _g,_g getVariable ["ARTIC_sectionTaskId",""]];
    if (_tid isNotEqualTo "") then {[_g,_planId,_tid,format ["PLAN_SUPERSEDED:%1",_reason]] call ARTIC_fnc_abortSectionTask;};
    _g setVariable ["ARTIC_executionOrderType","PLATOON",true];
    _g setVariable ["ARTIC_executionOrderPos",[],true];
    _g setVariable ["ARTIC_orderType","PLATOON",true];
    _g setVariable ["ARTIC_orderPos",[],true];
    _g setVariable ["ARTIC_platoonFinalSlot",nil,true];
    _g setVariable ["ARTIC_hHourPlanId","",true];
    _g setVariable ["ARTIC_sectionReadyPlanId","",true];
    _g setVariable ["ARTIC_planFailureReason","",true];
    _g setVariable ["ARTIC_planFailureAt",-1e6,true];
    if (_g getVariable ["ARTIC_committedInPlace",false]) then {_g setVariable ["ARTIC_committedInPlace",false,true];};
} forEach (_node getOrDefault ["groups",[]]);
[format ["FSM PLAN SUPERSEDED plan=%1 reason=%2 class=%3 scheme=%4; waiting for %5",_planId,_reason,_class,_plan getOrDefault ["scheme","?"],
    switch (_class) do {
        case "TIMING": {"a retry of the same scheme (timing failure)"};
        case "CONTACT": {"a contact-aware plan"};
        default {"an alternate scheme"};
    }],_nid] call ARTIC_fnc_debug;
[format ["FSM PLAN CHILDREN SETTLED plan=%1; replacement plan may now be created",_planId],_nid] call ARTIC_fnc_debug;
true
