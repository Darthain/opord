/* Resolve the current platoon plan from either a formation logic or a formation node. */
params [["_source",objNull,[objNull,createHashMap]]];
private _node = createHashMap;
if (_source isEqualType objNull) then {
    if (isNull _source) exitWith {createHashMap};
    private _cid = _source getVariable ["ARTIC_runtimeCommanderId",""];
    private _nid = _source getVariable ["ARTIC_runtimeFormationId",_source getVariable ["FormationId",""]];
    _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
} else {
    _node = _source;
};
if ((count _node) isEqualTo 0) exitWith {createHashMap};
_node getOrDefault ["platoonPlan",createHashMap]
