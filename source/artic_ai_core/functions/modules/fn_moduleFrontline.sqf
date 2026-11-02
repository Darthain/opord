params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
private _id = _logic getVariable ["FrontId", format ["FRONT_%1", netId _logic]];
ARTIC_Frontlines set [_id, createHashMapFromArray [
    ["id",_id],["logic",_logic],["position",getPosATL _logic],
    ["direction",(_logic getVariable ["Direction",0]) mod 360],
    ["width",(_logic getVariable ["Width",2000]) max 100]
]];
_logic setVariable ["ARTIC_registered",true,true];
