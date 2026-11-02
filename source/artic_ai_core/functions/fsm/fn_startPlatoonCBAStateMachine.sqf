/*
    Start the live v0.3.30.x CBA platoon state machine on the server.
    CBA owns state scheduling; v0.3.27 movement remains in place for this migration phase.
*/
if (!isServer) exitWith {locationNull};
if (!isNil "ARTIC_PlatoonCBAStateMachine" && {!isNull ARTIC_PlatoonCBAStateMachine}) exitWith {ARTIC_PlatoonCBAStateMachine};

private _sm = [{call ARTIC_fnc_getPlatoonLogicList},true] call CBA_statemachine_fnc_create;

[_sm, {}, {[_this,"WAIT_INTENT"] call ARTIC_fnc_platoonRuntimeEnterState;}, {}, "WAIT_INTENT"] call CBA_statemachine_fnc_addState;
[_sm, {
    private _cid = _this getVariable ["ARTIC_runtimeCommanderId",""];
    private _nid = _this getVariable ["ARTIC_runtimeFormationId",_this getVariable ["FormationId",""]];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    if ((count _node) > 0) then {[_node,_node getOrDefault ["groups",[]]] call ARTIC_fnc_applyPlatoonPlan;};
}, {[_this,"DEPLOY"] call ARTIC_fnc_platoonRuntimeEnterState;}, {}, "DEPLOY"] call CBA_statemachine_fnc_addState;
[_sm, {
    private _cid = _this getVariable ["ARTIC_runtimeCommanderId",""];
    private _nid = _this getVariable ["ARTIC_runtimeFormationId",_this getVariable ["FormationId",""]];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    if ((count _node) > 0) then {[_node,_node getOrDefault ["groups",[]]] call ARTIC_fnc_applyPlatoonPlan;};
    [_this] call ARTIC_fnc_tryIssuePlatoonHHour;
}, {[_this,"READY_CHECK"] call ARTIC_fnc_platoonRuntimeEnterState;}, {}, "READY_CHECK"] call CBA_statemachine_fnc_addState;
[_sm, {
    private _cid = _this getVariable ["ARTIC_runtimeCommanderId",""];
    private _nid = _this getVariable ["ARTIC_runtimeFormationId",_this getVariable ["FormationId",""]];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    if ((count _node) > 0) then {[_node,_node getOrDefault ["groups",[]]] call ARTIC_fnc_applyPlatoonPlan;};
}, {[_this,"EXECUTE"] call ARTIC_fnc_platoonRuntimeEnterState;}, {}, "EXECUTE"] call CBA_statemachine_fnc_addState;
[_sm, {}, {[_this,"CONSOLIDATE"] call ARTIC_fnc_platoonRuntimeEnterState;}, {}, "CONSOLIDATE"] call CBA_statemachine_fnc_addState;
[_sm, {}, {
    [_this,"REASSESS"] call ARTIC_fnc_platoonRuntimeEnterState;
    private _cid = _this getVariable ["ARTIC_runtimeCommanderId",""];
    private _nid = _this getVariable ["ARTIC_runtimeFormationId",_this getVariable ["FormationId",""]];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    private _reason = if ((count _node) > 0) then {_node getOrDefault ["lastPlanFailureReason","TACTICAL_FAILURE"]} else {"TACTICAL_FAILURE"};
    [_this,_reason] call ARTIC_fnc_supersedePlatoonPlan;
}, {}, "REASSESS"] call CBA_statemachine_fnc_addState;

[_sm,"WAIT_INTENT","DEPLOY",{[_this,"HAS_ACTIVE_PLAN"] call ARTIC_fnc_platoonRuntimeCondition},{},"PlanCreated"] call CBA_statemachine_fnc_addTransition;
[_sm,"DEPLOY","READY_CHECK",{[_this,"EXECUTION_ARMED"] call ARTIC_fnc_platoonRuntimeCondition},{},"ExecutionArmed"] call CBA_statemachine_fnc_addTransition;
[_sm,"DEPLOY","REASSESS",{[_this,"FAILURE_SETTLED"] call ARTIC_fnc_platoonRuntimeCondition},{},"DeployFailure"] call CBA_statemachine_fnc_addTransition;
[_sm,"READY_CHECK","EXECUTE",{[_this,"HHOUR_ISSUED"] call ARTIC_fnc_platoonRuntimeCondition},{},"HHour"] call CBA_statemachine_fnc_addTransition;
[_sm,"READY_CHECK","REASSESS",{[_this,"FAILURE_SETTLED"] call ARTIC_fnc_platoonRuntimeCondition},{},"ReadyFailure"] call CBA_statemachine_fnc_addTransition;
[_sm,"EXECUTE","REASSESS",{[_this,"FAILURE_SETTLED"] call ARTIC_fnc_platoonRuntimeCondition},{},"ExecutionFailure"] call CBA_statemachine_fnc_addTransition;
[_sm,"EXECUTE","CONSOLIDATE",{[_this,"PLAN_COMPLETE"] call ARTIC_fnc_platoonRuntimeCondition},{},"PlanComplete"] call CBA_statemachine_fnc_addTransition;
[_sm,"CONSOLIDATE","REASSESS",{[_this,"FAILURE_SETTLED"] call ARTIC_fnc_platoonRuntimeCondition},{},"ConsolidationFailure"] call CBA_statemachine_fnc_addTransition;
[_sm,"REASSESS","DEPLOY",{[_this,"NEW_ACTIVE_PLAN"] call ARTIC_fnc_platoonRuntimeCondition},{},"ReplacementPlan"] call CBA_statemachine_fnc_addTransition;

ARTIC_PlatoonCBAStateMachine = _sm;
["v0.3.30.2 live CBA platoon state machine started","FSM"] call ARTIC_fnc_debug;
_sm
