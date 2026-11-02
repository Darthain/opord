params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_units",[],[[]]]
];
if (isNull _group || {isNull _target}) exitWith {createHashMap};

private _origin = getPosATL leader _group;
private _targetPos = getPosATL _target;
private _baseDir = _origin getDir _targetPos;
private _bestPos = _origin;
private _bestScore = -1e9;
private _bestLOS = false;
private _bestCover = 0;

private _candidates = [_origin];
{
    private _r = _x;
    {
        _candidates pushBack (_origin getPos [_r,_baseDir + _x]);
    } forEach [-105,-80,-55,-30,0,30,55,80,105,145,-145,180];
} forEach [18,32,48,65,85,105,125];

{
    private _p = _x;
    if !(surfaceIsWater _p) then {
        private _normal = surfaceNormal _p;
        private _slope = acos (((_normal select 2) max -1) min 1);
        if (_slope <= 24) then {
            private _los = [_p,_target] call ARTIC_fnc_hasLineOfSight;
            private _cover = [_p] call ARTIC_fnc_coverScore;
            private _range = _p distance2D _targetPos;
            private _move = _p distance2D _origin;
            private _elevDelta = (getTerrainHeightASL _p) - (getTerrainHeightASL _origin);
            private _rangeScore = 1 - ((abs (_range - 240)) / 300);
            _rangeScore = (_rangeScore max 0) min 1;
            private _score =
                (if (_los) then {75} else {-80}) +
                (_cover * 35) +
                (_rangeScore * 20) +
                ((1 - (_slope / 24)) * 12) +
                (((_elevDelta max -8) min 18) * 0.7) -
                (_move * 0.18);
            if (_score > _bestScore) then {
                _bestScore = _score;
                _bestPos = _p;
                _bestLOS = _los;
                _bestCover = _cover;
            };
        };
    };
} forEach _candidates;

createHashMapFromArray [
    ["position",_bestPos],
    ["score",_bestScore],
    ["los",_bestLOS],
    ["cover",_bestCover],
    ["moveDistance",_origin distance2D _bestPos]
]
