params [
    ["_object",objNull,[objNull]],
    ["_type","UNKNOWN",[""]],
    ["_purpose","",[""]],
    ["_side",sideUnknown,[sideUnknown]],
    ["_ownerGroup",grpNull,[grpNull]]
];
if (isNull _object) exitWith {};

private _record = [_object,toUpper _type,toUpper _purpose,_side,_ownerGroup,getPosATL _object];
ARTIC_ObstacleRegistry pushBack _record;
publicVariable "ARTIC_ObstacleRegistry";
