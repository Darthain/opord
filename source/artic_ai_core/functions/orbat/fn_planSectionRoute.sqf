/*
    ARTIC v0.3.23 - terrain-aware section route planner with enemy exclusion routing.

    Produces a stable sequence of guide points from _start to _end. LEFT / RIGHT routes
    are biased into their own lane, penalise enemy observation, steep slopes and large
    deviations, and prefer terrain objects that provide masking/concealment.

    If the direct route intersects the enemy stand-off area, a coarse safe arc is built
    around the exclusion zone BEFORE terrain refinement.  Manoeuvre-left / manoeuvre-right
    retain their doctrinal side while FIX prefers the friendly-side arc.

    Returns route control points (start intentionally omitted; destination included).
*/
params [
    ["_start",[],[[]]],
    ["_end",[],[[]]],
    ["_focus",[],[[]]],
    ["_role","FIX",[""]],
    ["_battleAxis",0,[0]],
    ["_frontage",100,[0]],
    ["_standoff",0,[0]]          // battle radius + tactical stand-off (normally +80 m)
];
if (_start isEqualTo [] || {_end isEqualTo []}) exitWith {[]};
if (_focus isEqualTo []) then {_focus = +_end;};
_role = toUpper _role;
private _side = switch (_role) do {
    case "MANOEUVRE_LEFT": {-1};
    case "MANOEUVRE_RIGHT": {1};
    default {0};
};
private _route = [];

private _segmentMinDistance = {
    params ["_a","_b","_p"];
    private _abx = (_b select 0) - (_a select 0);
    private _aby = (_b select 1) - (_a select 1);
    private _len2 = (_abx * _abx + _aby * _aby) max 0.001;
    private _t = (((_p select 0) - (_a select 0)) * _abx + ((_p select 1) - (_a select 1)) * _aby) / _len2;
    _t = (_t max 0) min 1;
    private _cx = (_a select 0) + _t * _abx;
    private _cy = (_a select 1) + _t * _aby;
    sqrt (((_p select 0) - _cx) ^ 2 + ((_p select 1) - _cy) ^ 2)
};

private _pointSide = {
    params ["_bearing"];
    private _rel = (((_bearing - (_battleAxis + 180)) + 540) % 360) - 180;
    // Match the actual lane geometry used below: MANOEUVRE_LEFT is battleAxis - 90,
    // which lies on the positive side of the friendly-bearing reference; RIGHT is the
    // negative side.  This deliberately differs from the old penalty convention that
    // could penalise a point already biased into its own lane.
    if (_rel > 0) then {-1} else {1}
};

// ---------------------------------------------------------------------------
// v0.3.23 route-safety revision: enemy exclusion detour.
// ---------------------------------------------------------------------------
if (_standoff > 0 && {_focus isNotEqualTo _end}) then {
    private _dS = _start distance2D _focus;
    private _dE = _end distance2D _focus;

    // Do not require a destination intentionally inside the battle area to orbit forever;
    // shrink only when an endpoint is genuinely closer than the requested stand-off.
    private _R = ((_standoff min _dS) min _dE) max 40;
    private _dMin = [_start,_end,_focus] call _segmentMinDistance;

    if (_dMin < (_R * 0.98)) then {
        private _aS = _focus getDir _start;
        private _aE = _focus getDir _end;
        private _shortDelta = ((_aE - _aS + 540) % 360) - 180;
        private _longDelta = if (_shortDelta >= 0) then {_shortDelta - 360} else {_shortDelta + 360};

        // Choose the arc by doctrine, not merely by shortest distance.  LEFT and RIGHT
        // must stay on their own side of the attack axis; FIX prefers the friendly half.
        private _scoreArc = {
            params ["_delta"];
            private _score = -0.008 * abs _delta;
            {
                private _bearing = (_aS + _delta * _x + 3600) % 360;
                private _relFriendly = (((_bearing - (_battleAxis + 180)) + 540) % 360) - 180;
                if (_side isEqualTo 0) then {
                    _score = _score + (if (abs _relFriendly <= 90) then {2.0} else {-4.0});
                } else {
                    private _sampleSide = [_bearing] call _pointSide;
                    _score = _score + (if (_sampleSide isEqualTo _side) then {3.0} else {-5.0});
                };
            } forEach [0.20,0.35,0.50,0.65,0.80];
            _score
        };

        private _scoreShort = [_shortDelta] call _scoreArc;
        private _scoreLong = [_longDelta] call _scoreArc;
        private _delta = [_shortDelta,_longDelta] select (_scoreLong > _scoreShort);

        // Keep chord segments outside the exclusion area by using <=25-degree arc steps
        // and explicit radial entry/exit points.  Terrain refinement only moves points
        // OUTWARD from the exclusion circle.
        private _nArc = (ceil ((abs _delta) / 25)) max 2;
        private _detour = [];

        for "_i" from 0 to _nArc do {
            private _fArc = _i / _nArc;
            private _ang = (_aS + _delta * _fArc + 3600) % 360;
            private _bestP = [];
            private _bestSc = -1e9;

            {
                private _radialExtra = _x;
                private _p = _focus getPos [_R + 20 + _radialExtra,_ang];
                _p set [2,0];

                if !(surfaceIsWater _p) then {
                    private _normal = surfaceNormal _p;
                    private _slope = acos (((_normal select 2) max -1) min 1);
                    if (_slope <= 34) then {
                        private _hits = lineIntersectsSurfaces [
                            AGLToASL (_p vectorAdd [0,0,1.2]),
                            AGLToASL (_focus vectorAdd [0,0,1.2]),
                            objNull,objNull,true,1,"VIEW","FIRE"
                        ];
                        private _masked = _hits isNotEqualTo [] || {
                            terrainIntersectASL [
                                AGLToASL (_p vectorAdd [0,0,1.2]),
                                AGLToASL (_focus vectorAdd [0,0,1.2])
                            ]
                        };
                        private _cov = ((count (nearestTerrainObjects [_p,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],14,false,true])) min 7) / 7;
                        private _bearing = _focus getDir _p;
                        private _sidePenalty = 0;
                        if (_side isNotEqualTo 0 && {_fArc > 0.08} && {_fArc < 0.92}) then {
                            if (([_bearing] call _pointSide) isNotEqualTo _side) then {_sidePenalty = 10;};
                        };
                        if (_side isEqualTo 0) then {
                            private _relFriendly = (((_bearing - (_battleAxis + 180)) + 540) % 360) - 180;
                            if (abs _relFriendly > 100) then {_sidePenalty = 8;};
                        };
                        private _sc = (if (_masked) then {1.2} else {-0.4})
                            + 0.7 * _cov
                            - 0.65 * (_slope / 34)
                            - 0.008 * _radialExtra
                            - _sidePenalty;
                        if (_sc > _bestSc) then {_bestSc = _sc; _bestP = +_p;};
                    };
                };
            } forEach [0,15,30,45,60];

            // If all normal samples are too steep/wet, make one wider emergency search.
            // Never deliberately select a >42-degree slope just to preserve the arc.
            if (_bestP isEqualTo []) then {
                {
                    private _p = _focus getPos [_R + 65 + _x,_ang];
                    _p set [2,0];
                    if !(surfaceIsWater _p) then {
                        private _normal = surfaceNormal _p;
                        private _slope = acos (((_normal select 2) max -1) min 1);
                        if (_slope <= 42 && {_bestP isEqualTo []}) then {_bestP = +_p;};
                    };
                } forEach [0,20,40];
            };

            if (_bestP isNotEqualTo []) then {_detour pushBack _bestP;};
        };

        // A valid detour needs an entry and exit point plus destination.  Validate that
        // every coarse segment remains outside the intended stand-off (small tolerance for
        // floating point / terrain nudges).  If not, the caller can reject this COA/route.
        if ((count _detour) >= 2) then {
            _detour pushBack (+_end);
            private _safe = true;
            private _prevSafe = +_start;
            {
                private _segMin = [_prevSafe,_x,_focus] call _segmentMinDistance;
                // The final segment may legitimately enter the stand-off only when the
                // destination itself lies inside it (e.g. a later assault-stage use).
                private _isLast = _forEachIndex isEqualTo ((count _detour) - 1);
                private _endInside = (_end distance2D _focus) < _R;
                if (_segMin < (_R * 0.96) && {!(_isLast && {_endInside})}) then {_safe = false;};
                _prevSafe = +_x;
            } forEach _detour;
            if (_safe) then {_route = _detour;};
        };
    };
};
if (_route isNotEqualTo []) exitWith {_route};

// ---------------------------------------------------------------------------
// Normal lane route: terrain-refined straight corridor.
// ---------------------------------------------------------------------------
private _prev = +_start;
private _fractions = [0.25,0.5,0.75,1.0];
private _total = _start distance2D _end;
private _dir = _start getDir _end;

{
    private _f = _x;
    private _ideal = if (_f >= 0.999) then {+_end} else {_start getPos [_total * _f,_dir]};
    // v0.3.17: establish section lanes EARLY, not only near the HOLD line.
    if (_side isNotEqualTo 0 && {_f < 0.999}) then {
        private _lane = ((_frontage * 0.46) max 28) min 62;
        private _bias = _lane * (0.72 + 0.28 * _f);
        _ideal = _ideal getPos [_bias,_battleAxis + (if (_side < 0) then {-90} else {90})];
    };
    _ideal set [2,0];

    private _best = +_ideal;
    private _bestScore = -1e9;
    private _offsets = [0,-30,30,-18,18,-42,42];
    {
        private _cand = if (_x isEqualTo 0) then {+_ideal} else {_ideal getPos [abs _x,_dir + (if (_x < 0) then {-90} else {90})]};
        _cand set [2,0];
        if !(surfaceIsWater _cand) then {
            private _n = surfaceNormal _cand;
            private _slope = acos (((_n select 2) max -1) min 1);
            if (_slope <= 34) then {
                private _hits = lineIntersectsSurfaces [AGLToASL (_cand vectorAdd [0,0,1.2]),AGLToASL (_focus vectorAdd [0,0,1.2]),objNull,objNull,true,1,"GEOM","NONE"];
                private _masked = _hits isNotEqualTo [];
                private _terrain = nearestTerrainObjects [_cand,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],14,false,true];
                private _cover = ((count _terrain) min 7) / 7;
                private _step = _prev distance2D _cand;
                private _idealD = _cand distance2D _ideal;
                private _score = (if (_masked) then {1.15} else {-0.35}) + 0.75 * _cover - 0.55 * (_slope / 34) - 0.012 * _idealD - 0.0025 * _step;
                if (_side isNotEqualTo 0) then {
                    private _candSide = [_focus getDir _cand] call _pointSide;
                    if (_candSide isNotEqualTo _side) then {_score = _score - 12;};
                };
                if (_score > _bestScore) then {_bestScore = _score; _best = +_cand;};
            };
        };
    } forEach _offsets;
    _route pushBack _best;
    _prev = +_best;
} forEach _fractions;

_route
