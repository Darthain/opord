params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
private _id = _logic getVariable ["ObjectiveId", format ["OBJ_%1", netId _logic]];
private _entry = createHashMapFromArray [
    ["id",_id],["name",_logic getVariable ["ObjectiveName","Objective"]],
    ["logic",_logic],["type",toUpper (_logic getVariable ["ObjectiveType","CAPTURE"])],
    ["priority",(_logic getVariable ["Priority",50]) max 1 min 100],
    ["radius",(_logic getVariable ["Radius",200]) max 25],
    ["active",_logic getVariable ["Active",true]],
    ["position",getPosATL _logic],["control",sideUnknown]
];
ARTIC_Objectives set [_id,_entry];
_logic setVariable ["ARTIC_registered",true,true];
