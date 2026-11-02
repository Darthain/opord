/* State-entry hook for the live CBA platoon machine. */
params [
    ["_logic",objNull,[objNull]],
    ["_state","",[""]]
];
if (isNull _logic) exitWith {};
private _old = _logic getVariable ["ARTIC_platoonRuntimeState",""];
_logic setVariable ["ARTIC_platoonRuntimeState",_state,true];
_logic setVariable ["ARTIC_platoonRuntimeStateAt",time,false];
private _cid = _logic getVariable ["ARTIC_runtimeCommanderId",""];
private _nid = _logic getVariable ["ARTIC_runtimeFormationId",_logic getVariable ["FormationId","PLATOON"]];
private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
if ((count _node) > 0) then {
    private _plan = _node getOrDefault ["platoonPlan",createHashMap];
    if ((count _plan) > 0 && {!((toUpper (_plan getOrDefault ["status",""])) in ["SUPERSEDED","COMPLETE"])}) then {
        _plan set ["phase",_state];
        if (_state in ["DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]) then {_plan set ["status",_state];};
        _node set ["platoonPlan",_plan];
    };
};
if (_old isNotEqualTo _state) then {
    private _pid = if ((count _node) > 0) then {(_node getOrDefault ["platoonPlan",createHashMap]) getOrDefault ["planId","NONE"]} else {"NONE"};
    [format ["PLATOON CBA FSM %1 -> %2 plan=%3",_old,_state,_pid],_nid] call ARTIC_fnc_debug;
};
