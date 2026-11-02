params [["_node", createHashMap, [createHashMap]]];
if ((count _node) isEqualTo 0) exitWith { [] };

private _groups = +(_node getOrDefault ["groups", []]);
{
    _groups append ([_x] call ARTIC_fnc_getFormationGroups);
} forEach (_node getOrDefault ["children", []]);

_groups arrayIntersect _groups
