/* Resolve a formation node by ID from a commander ORBAT. */
params [["_commanderId","",[""]],["_nodeId","",[""]]];
if (_commanderId isEqualTo "" || {_nodeId isEqualTo ""}) exitWith {createHashMap};
private _commander = ARTIC_Commanders getOrDefault [_commanderId,createHashMap];
if ((count _commander) isEqualTo 0) exitWith {createHashMap};
private _found = createHashMap;
private _walk = {
    params ["_nodes"];
    {
        if ((_x getOrDefault ["id",""]) isEqualTo _nodeId) exitWith {_found = _x;};
        [_x getOrDefault ["children",[]]] call _walk;
        if ((count _found) > 0) exitWith {};
    } forEach _nodes;
};
[_commander getOrDefault ["orbat",[]]] call _walk;
_found
