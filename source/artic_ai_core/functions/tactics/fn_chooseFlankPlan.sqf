params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_flankDistance",110,[0]]
];
if (isNull _group || {isNull _target}) exitWith {createHashMap};

private _start = getPosATL leader _group;
private _targetPos = getPosATL _target;
private _dir = _start getDir _targetPos;
private _results = [];
private _forcedSide = _group getVariable ["ARTIC_attackAxis",0];
private _axisLocked = _group getVariable ["ARTIC_axisLocked",false];

// Score the route that will actually be travelled. v0.3.0 evaluated an imaginary
// straight line start->stage2 even though execution travelled start->stage1->stage2.
private _scoreLeg = {
    params ["_a","_b"];
    private _dist = _a distance2D _b;
    private _samples = (ceil (_dist / 20)) max 2;
    private _hiddenCount = 0;
    private _coverAccum = 0;
    private _slopeAccum = 0;
    private _exposedRun = 0;
    private _worstExposedRun = 0;
    private _v = _b vectorDiff _a;

    for "_i" from 1 to _samples do {
        private _t = _i / (_samples + 1);
        private _p = _a vectorAdd (_v vectorMultiply _t);
        private _los = [_p,_target] call ARTIC_fnc_hasLineOfSight;
        if (_los) then {
            _exposedRun = _exposedRun + 1;
            _worstExposedRun = _worstExposedRun max _exposedRun;
        } else {
            _hiddenCount = _hiddenCount + 1;
            _exposedRun = 0;
        };

        _coverAccum = _coverAccum + ([_p] call ARTIC_fnc_coverScore);
        private _n = surfaceNormal _p;
        private _slope = acos (((_n select 2) max -1) min 1);
        _slopeAccum = _slopeAccum + ((_slope min 30) / 30);
    };

    [
        _hiddenCount / _samples,
        _coverAccum / _samples,
        1 - (_slopeAccum / _samples),
        _worstExposedRun / _samples,
        _dist
    ]
};

{
    private _side = _x;
    private _raw1 = _start getPos [(_flankDistance * 0.60),_dir + (88 * _side)];
    private _raw2 = _targetPos getPos [(_flankDistance * 0.78),(_targetPos getDir _start) + (72 * _side)];
    private _stage1 = [_raw1,_target,22,true] call ARTIC_fnc_findCoverPosition;
    private _stage2 = [_raw2,_target,18,false] call ARTIC_fnc_findCoverPosition;

    private _leg1 = [_start,_stage1] call _scoreLeg;
    private _leg2 = [_stage1,_stage2] call _scoreLeg;
    _leg1 params ["_hidden1","_cover1","_slope1","_exposure1","_dist1"];
    _leg2 params ["_hidden2","_cover2","_slope2","_exposure2","_dist2"];

    private _routeLen = _dist1 + _dist2;
    private _weight1 = if (_routeLen > 0) then {_dist1 / _routeLen} else {0.5};
    private _weight2 = 1 - _weight1;
    private _hidden = (_hidden1 * _weight1) + (_hidden2 * _weight2);
    private _cover = (_cover1 * _weight1) + (_cover2 * _weight2);
    private _slopeQuality = (_slope1 * _weight1) + (_slope2 * _weight2);
    private _routeExposure = _exposure1 max _exposure2;

    private _finalLOS = [_stage2,_target] call ARTIC_fnc_hasLineOfSight;
    private _distanceQuality = 1 - (((_routeLen - (_flankDistance * 1.1)) max 0) / (_flankDistance * 1.6));
    _distanceQuality = (_distanceQuality max 0) min 1;

    private _score =
        (_hidden * 0.30) +
        (_cover * 0.18) +
        (_slopeQuality * 0.14) +
        ((if (_finalLOS) then {1} else {0}) * 0.18) +
        (_distanceQuality * 0.08) +
        ((1 - _routeExposure) * 0.12);

    _results pushBack [_score,_side,_stage1,_stage2,_hidden,_cover,_finalLOS,_routeExposure,_exposure1,_exposure2];
} forEach [-1,1];

private _left = (_results select {(_x select 1) isEqualTo -1}) select 0;
private _right = (_results select {(_x select 1) isEqualTo 1}) select 0;
_results sort false;
private _best = _results select 0;
if (_axisLocked && {_forcedSide in [-1,1]}) then {
    _best = if (_forcedSide < 0) then {_left} else {_right};
};
_best params ["_score","_side","_stage1","_stage2","_hidden","_cover","_finalLOS","_routeExposure","_exposure1","_exposure2"];

createHashMapFromArray [
    ["side",_side],
    ["stage1",_stage1],
    ["stage2",_stage2],
    ["score",_score],
    ["hidden",_hidden],
    ["cover",_cover],
    ["finalLOS",_finalLOS],
    ["routeExposure",_routeExposure],
    ["leg1Exposure",_exposure1],
    ["leg2Exposure",_exposure2],
    ["leftScore",_left select 0],
    ["rightScore",_right select 0]
]
