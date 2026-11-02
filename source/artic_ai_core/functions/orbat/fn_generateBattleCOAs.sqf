/*
    ARTIC AI v0.3.27-alpha - attack COA search.

    Scores two related but distinct questions for every axis:
      1) SUPPORT quality: can a safe, reachable FIX fire line cover the enemy?
      2) MANOEUVRE quality: can the platoon reach/deploy on that axis masked and without
         an absurd detour even when no useful SBF exists?

    This separation lets the platoon change TACTIC as well as axis.  A poor SBF no longer
    makes an otherwise good envelopment axis unusable.

    v0.3.30.2:
      - Reposition safety. A candidate that turns the axis by 35 deg or more makes the platoon
        march REPOSITION_FOR_ATTACK in a straight FILE line from where it stands to the new
        staging area. If that line passes closer to a known enemy position than
        ARTIC_repositionStandoff (150 m) - or closer than the platoon already is - the candidate
        is invalid for both support and manoeuvre. 0.3.30.1 Air Station: the replan picked the
        axis 180 deg opposite (it had the only credible SBF) and the march line ran through the
        objective; contact at 63-76 m, casualties, contact replan.
      - Optional 7th argument onlyAxis: evaluate just that axis (a TIMING retry keeps the failed
        plan's geometry instead of re-searching every axis).
*/
params [
    ["_focus",[],[[]]],
    ["_friendlyCentre",[],[[]]],
    ["_targets",[],[[]]],
    ["_preferredDepth",170,[0]],
    ["_battleRadius",100,[0]],
    ["_frontage",120,[0]],
    ["_onlyAxis",-1,[0]]
];
if (_focus isEqualTo [] || {_friendlyCentre isEqualTo []} || {_targets isEqualTo []}) exitWith {createHashMap};

private _baseAxis = _friendlyCentre getDir _focus;
private _offsets = [0,-30,30,-60,60,-90,90,180];
// candidates are generated around _candBase; turn / reposition are always measured from the
// platoon's real bearing (_baseAxis), so a locked retry axis is still safety-checked.
private _candBase = _baseAxis;
if (_onlyAxis >= 0) then {_candBase = _onlyAxis; _offsets = [0];};

// v0.3.30.2 reposition safety: closest approach of the straight march line to known enemy.
private _standoff = missionNamespace getVariable ["ARTIC_repositionStandoff",150];
private _segDist = {
    params ["_a","_b","_p"];
    private _abx = (_b select 0) - (_a select 0);
    private _aby = (_b select 1) - (_a select 1);
    private _len2 = (_abx * _abx) + (_aby * _aby);
    private _t = if (_len2 <= 0.01) then {0} else {
        ((((_p select 0) - (_a select 0)) * _abx + ((_p select 1) - (_a select 1)) * _aby) / _len2) max 0 min 1
    };
    [(_a select 0) + _t * _abx,(_a select 1) + _t * _aby,0] distance2D [_p select 0,_p select 1,0]
};
private _startMin = 1e9;
{_startMin = _startMin min (_friendlyCentre distance2D _x);} forEach _targets;
private _repoUnsafe = 0;
private _candidates = [];
private _best = createHashMap;
private _bestScore = -1e9;
private _bestTier = -1;
private _bestMan = createHashMap;
private _bestManScore = -1e9;

private _preferredCoverage = missionNamespace getVariable ["ARTIC_preferredSbfCoverage",0.40];
private _minCoverage = missionNamespace getVariable ["ARTIC_minSbfCoverage",0.25];
private _limitedCoverage = missionNamespace getVariable ["ARTIC_limitedSbfCoverage",0.125];
private _minUseful = missionNamespace getVariable ["ARTIC_minSbfUsefulPoints",2];
private _avoidRadius = (_battleRadius + 80) max 100;
private _routeFrontage = (_frontage max 75) min 220;

private _angDiff = {
    params ["_a","_b"];
    abs ((((_a - _b) + 540) % 360) - 180)
};
private _routeLength = {
    params ["_start","_route"];
    private _len = 0;
    private _prev = +_start;
    {_len = _len + (_prev distance2D _x); _prev = +_x;} forEach _route;
    _len
};

{
    private _axis = (_candBase + _x + 360) % 360;
    private _stagingDepth = (_preferredDepth + 95) max (_battleRadius + 130);
    private _staging = _focus getPos [_stagingDepth,_axis + 180];
    _staging set [2,0];

    private _arc = [_focus,_staging,_targets,_preferredDepth,_battleRadius] call ARTIC_fnc_findSupportArc;
    private _sbf = _arc select 0;
    private _anchorSight = _arc select 1;
    private _sbfScore = _arc select 2;

    private _evalFrontage = (_frontage max 75) min 220;
    private _lineEval = if (_sbf isNotEqualTo []) then {
        [_sbf,_focus,_targets,_axis,_evalFrontage,8] call ARTIC_fnc_evaluateSbfFireLine
    } else {createHashMap};
    private _lineCoverage = _lineEval getOrDefault ["coverage",0];
    private _usefulPoints = _lineEval getOrDefault ["usefulPoints",0];
    private _totalPoints = _lineEval getOrDefault ["totalPoints",0];
    private _maxPointSight = _lineEval getOrDefault ["maxPointSight",0];
    private _meanPointSight = _lineEval getOrDefault ["meanPointSight",0];

    // Platoon approach masking/cover - useful for every tactic, not just support-by-fire.
    private _masked = 0;
    private _samples = 4;
    for "_i" from 1 to _samples do {
        private _f = _i / (_samples + 1);
        private _p = _staging getPos [(_staging distance2D _focus) * _f,_staging getDir _focus];
        private _seen = ([_p,_targets,6] call ARTIC_fnc_battleSight) select 0;
        _masked = _masked + (1 - _seen);
    };
    _masked = _masked / _samples;

    private _terrain = nearestTerrainObjects [_staging,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],24,false,true];
    private _cover = ((count _terrain) min 10) / 10;
    private _n = surfaceNormal _staging;
    private _slope = acos (((_n select 2) max -1) min 1);
    private _reposition = _friendlyCentre distance2D _staging;
    private _turn = [_axis,_baseAxis] call _angDiff;
    // v0.3.30.2: a large turn means a straight reposition march; it must not cross the enemy
    private _pathMin = 1e9;
    {_pathMin = _pathMin min ([_friendlyCentre,_staging,_x] call _segDist);} forEach _targets;
    private _repoSafe = _turn < 35 || {_pathMin >= ((_standoff min _startMin) - 15)};
    if (!_repoSafe) then {_repoUnsafe = _repoUnsafe + 1;};

    // Actual safe FIX access route. This is the revised v0.3.23 logic that was lost in
    // the later branch: a brilliant SBF is not useful if FIX must walk through/around the
    // enemy for several hundred extra metres to reach it.
    private _fixRoute = [];
    private _fixDirect = if (_sbf isEqualTo []) then {1e6} else {(_staging distance2D _sbf) max 1};
    private _fixRouteLength = 1e6;
    private _fixRouteRatio = 99;
    private _fixRouteMask = 0;
    if (_sbf isNotEqualTo []) then {
        _fixRoute = [_staging,_sbf,_focus,"FIX",_axis,_routeFrontage,_avoidRadius] call ARTIC_fnc_planSectionRoute;
        if (_fixRoute isNotEqualTo []) then {
            _fixRouteLength = [_staging,_fixRoute] call _routeLength;
            _fixRouteRatio = _fixRouteLength / _fixDirect;
            private _maskSum = 0; private _maskN = 0;
            {
                if (_forEachIndex < ((count _fixRoute) - 1)) then {
                    private _seen = ([_x,_targets,6] call ARTIC_fnc_battleSight) select 0;
                    _maskSum = _maskSum + (1 - _seen); _maskN = _maskN + 1;
                };
            } forEach _fixRoute;
            _fixRouteMask = if (_maskN > 0) then {_maskSum / _maskN} else {_masked};
        };
    };
    private _routeValid = _fixRoute isNotEqualTo [] && {_fixRouteRatio <= 2.4} && {_fixRouteLength <= 650};

    private _standardValid = _sbf isNotEqualTo []
        && {_slope <= 32}
        && {_routeValid}
        && {_lineCoverage >= _minCoverage}
        && {_usefulPoints >= _minUseful};
    private _limitedValid = _sbf isNotEqualTo []
        && {_slope <= 32}
        && {_routeValid}
        && {_lineCoverage >= _limitedCoverage}
        && {_usefulPoints >= 1};
    private _preferred = _standardValid && {_lineCoverage >= _preferredCoverage};
    if (!_repoSafe) then {_standardValid = false; _limitedValid = false; _preferred = false;};
    private _tier = if (_standardValid) then {2} else {if (_limitedValid) then {1} else {0}};

    private _detourRatio = ((_fixRouteRatio - 1) max 0) min 4;
    private _extraRoute = ((_fixRouteLength - _fixDirect) max 0) min 800;
    private _score = 48 * _lineCoverage
        + 16 * _anchorSight
        + 7 * _maxPointSight
        + 6 * _meanPointSight
        + 3.5 * (_usefulPoints / ((_totalPoints max 1)))
        + 18 * _masked
        + 7 * _cover
        + 4 * ((_sbfScore max -2) min 2)
        + 8 * _fixRouteMask
        + ([0,6] select _preferred)
        - 0.018 * _reposition
        - 0.035 * _turn
        - 0.12 * _slope
        - 10 * _detourRatio
        - 0.010 * _extraRoute
        - 0.003 * (_fixRouteLength min 650);
    if (_tier isEqualTo 0) then {_score = _score - 60;};
    if (!_repoSafe) then {_score = _score - 200;};

    // Independent manoeuvre-axis score. No SBF/LOS requirement: this is used by
    // envelopment schemes when terrain offers masked approaches but no useful base of fire.
    private _manoeuvreScore = 38 * _masked + 12 * _cover - 0.014 * _reposition - 0.030 * _turn - 0.10 * _slope;
    private _manoeuvreValid = _slope <= 35 && {_reposition <= 900} && {_repoSafe};
    if (!_manoeuvreValid) then {_manoeuvreScore = _manoeuvreScore - 80;};

    private _coa = createHashMapFromArray [
        ["axis",_axis],["offset",_x],["staging",_staging],["sbf",_sbf],
        ["sight",_anchorSight],["anchorSight",_anchorSight],["fireLineCoverage",_lineCoverage],
        ["fireLineUsefulPoints",_usefulPoints],["fireLineTotalPoints",_totalPoints],
        ["fireLineMaxSight",_maxPointSight],["fireLineMeanSight",_meanPointSight],
        ["preferredSbf",_preferred],["limitedValid",_limitedValid],
        ["routeMask",_masked],["cover",_cover],["slope",_slope],["reposition",_reposition],
        ["fixRoute",_fixRoute],["fixDirect",_fixDirect],["fixRouteLength",_fixRouteLength],
        ["fixRouteRatio",_fixRouteRatio],["fixRouteMask",_fixRouteMask],["routeValid",_routeValid],
        ["manoeuvreScore",_manoeuvreScore],["manoeuvreValid",_manoeuvreValid],
        ["valid",_standardValid],["score",_score],["repoSafe",_repoSafe],["repoPathMin",_pathMin]
    ];
    _candidates pushBack _coa;

    if ((_tier > _bestTier) || {_tier isEqualTo _bestTier && {_score > _bestScore}}) then {
        _best = _coa; _bestScore = _score; _bestTier = _tier;
    };
    if (_manoeuvreValid && {_manoeuvreScore > _bestManScore}) then {
        _bestMan = _coa; _bestManScore = _manoeuvreScore;
    };
} forEach _offsets;

if ((count _best) > 0) then {
    _best set ["repositionUnsafeCount",_repoUnsafe];
    _best set ["baseAxis",_baseAxis];
    _best set ["axisDelta",[(_best get "axis"),_baseAxis] call _angDiff];
    _best set ["candidates",_candidates];
    if ((count _bestMan) > 0) then {
        _best set ["manoeuvreAxis",_bestMan get "axis"];
        _best set ["manoeuvreAxisDelta",[(_bestMan get "axis"),_baseAxis] call _angDiff];
        _best set ["manoeuvreScore",_bestMan get "manoeuvreScore"];
        _best set ["manoeuvreStaging",+(_bestMan get "staging")];
        _best set ["manoeuvreValid",true];
    };
};
_best
