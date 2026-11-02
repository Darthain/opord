params [
    ["_position",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_eyeHeight",1.35,[0]]
];
if (_position isEqualTo [] || {isNull _target}) exitWith {false};

private _fromAGL = +_position;
if ((count _fromAGL) < 3) then {_fromAGL pushBack 0;};
_fromAGL set [2,(_fromAGL select 2) + _eyeHeight];
private _from = AGLToASL _fromAGL;
private _to = getPosASL _target;
_to set [2,(_to select 2) + (if (_target isKindOf "Man") then {1.15} else {1.5})];

if (terrainIntersectASL [_from,_to]) exitWith {false};
private _hits = lineIntersectsSurfaces [_from,_to,objNull,_target,true,1,"VIEW","FIRE",true];
_hits isEqualTo []
