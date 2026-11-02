params [["_position",[],[[]]]];
if (_position isEqualTo [] || {surfaceIsWater _position}) exitWith {0};

private _terrain = nearestTerrainObjects [
    _position,
    ["TREE","SMALL TREE","BUSH","ROCK","ROCKS","HOUSE","BUILDING","CHURCH","CHAPEL","WALL","FENCE"],
    12,
    false,
    true
];
private _hard = nearestObjects [_position,["House","Building"],14];
private _score = ((count _terrain) * 0.09) + ((count _hard) * 0.12);
(_score min 1) max 0
