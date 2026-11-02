params [
    ["_node", createHashMap, [createHashMap]],
    ["_commanderId", "", [""]]
];
if ((count _node) isEqualTo 0) exitWith {};

private _doctrine = _node getOrDefault ["doctrine","CONVENTIONAL"];
private _training = _node getOrDefault ["training","REGULAR"];
private _id = _node getOrDefault ["id",""];

{
    _x setVariable ["ARTIC_enabled", true, true];
    _x setVariable ["ARTIC_commanderId", _commanderId, true];
    _x setVariable ["ARTIC_formationId", _id, true];
    _x setVariable ["ARTIC_doctrine", _doctrine, true];
    _x setVariable ["ARTIC_training", _training, true];
} forEach (_node getOrDefault ["groups",[]]);

{ [_x,_commanderId] call ARTIC_fnc_applyFormationProfile; } forEach (_node getOrDefault ["children",[]]);
