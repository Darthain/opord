params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
private _id = _logic getVariable ["AOId", format ["AO_%1", netId _logic]];
ARTIC_AOs set [_id, createHashMapFromArray [
    ["id",_id],["name",_logic getVariable ["AOName","Area of Operations"]],
    ["logic",_logic],["position",getPosATL _logic],
    ["radius",(_logic getVariable ["Radius",3000]) max 100]
]];
_logic setVariable ["ARTIC_registered",true,true];
