/*
    ARTIC AI v0.3.26-alpha
    Coarse support-by-fire FIRE-LINE evaluator used by the platoon planner.

    The v0.3.24/0.3.25 planner validated one SBF anchor point. In urban terrain that
    made 40% visibility effectively a 4-of-8 hard gate even though the actual FIX
    section occupies a lateral fire line and individual shooters can see different
    parts of the enemy position.

    This function samples a representative five-point FIX line perpendicular to the
    attack axis and measures UNION visibility: a hostile position counts as covered if
    any usable point on the line can see it. This is planning geometry only; it does not
    issue target/fire commands.

    Returns HashMap:
      coverage       - fraction of tested targets visible from >=1 fire-line point
      visibleTargets - number of tested targets covered by the line
      targetsTested  - number of targets tested (max _maxTargets)
      usefulPoints   - fire-line points that can see >=1 tested target
      totalPoints    - terrain-usable fire-line points
      maxPointSight  - best single-point sight fraction
      meanPointSight - mean sight fraction across usable points
      points          - usable sampled positions
*/
params [
    ["_anchor",[],[[]]],
    ["_focus",[],[[]]],
    ["_targets",[],[[]]],
    ["_battleAxis",0,[0]],
    ["_frontage",100,[0]],
    ["_maxTargets",8,[0]]
];

private _out = createHashMapFromArray [
    ["coverage",0],["visibleTargets",0],["targetsTested",0],
    ["usefulPoints",0],["totalPoints",0],["maxPointSight",0],
    ["meanPointSight",0],["points",[]]
];
if (_anchor isEqualTo [] || {_focus isEqualTo []} || {_targets isEqualTo []}) exitWith {_out};

private _test = if ((count _targets) > _maxTargets) then {
    ([_targets,[],{_x distance2D _anchor},"ASCEND"] call BIS_fnc_sortBy) select [0,_maxTargets]
} else {+_targets};
if (_test isEqualTo []) exitWith {_out};

private _targetSeen = [];
{_targetSeen pushBack false;} forEach _test;

// Representative eight-man FIX frontage. The executor may refine individual firing
// positions later; this planner check only asks whether the section-sized line has a
// credible field of fire at all.
private _halfWidth = ((_frontage * 0.24) max 18) min 48;
private _offsets = [-1,-0.5,0,0.5,1];
private _useful = 0;
private _usable = 0;
private _maxSight = 0;
private _sumSight = 0;
private _points = [];

{
    private _k = _x;
    private _p = if (abs _k < 0.01) then {+_anchor} else {
        _anchor getPos [abs (_k * _halfWidth),_battleAxis + (if (_k < 0) then {-90} else {90})]
    };
    _p set [2,0];

    if !(surfaceIsWater _p) then {
        private _n = surfaceNormal _p;
        private _slope = acos (((_n select 2) max -1) min 1);
        if (_slope <= 34) then {
            _usable = _usable + 1;
            _points pushBack (+_p);
            private _pointSeen = 0;

            for "_ti" from 0 to ((count _test) - 1) do {
                private _tp = _test select _ti;
                private _t = AGLToASL ([_tp select 0,_tp select 1,0] vectorAdd [0,0,1.0]);
                private _vis = false;
                {
                    if (!_vis) then {
                        private _eye = AGLToASL ([_p select 0,_p select 1,0] vectorAdd [0,0,_x]);
                        private _dirV = vectorNormalized (_t vectorDiff _eye);
                        private _end = _t vectorDiff (_dirV vectorMultiply 1.5);
                        if !(terrainIntersectASL [_eye,_end]) then {
                            private _hits = lineIntersectsSurfaces [_eye,_end,objNull,objNull,true,1,"VIEW","FIRE"];
                            if (_hits isEqualTo []) then {_vis = true;};
                        };
                    };
                } forEach [0.6,1.2];

                if (_vis) then {
                    _pointSeen = _pointSeen + 1;
                    _targetSeen set [_ti,true];
                };
            };

            private _frac = _pointSeen / ((count _test) max 1);
            _maxSight = _maxSight max _frac;
            _sumSight = _sumSight + _frac;
            if (_pointSeen > 0) then {_useful = _useful + 1;};
        };
    };
} forEach _offsets;

private _visible = { _x } count _targetSeen;
_out set ["coverage",_visible / ((count _test) max 1)];
_out set ["visibleTargets",_visible];
_out set ["targetsTested",count _test];
_out set ["usefulPoints",_useful];
_out set ["totalPoints",_usable];
_out set ["maxPointSight",_maxSight];
_out set ["meanPointSight",if (_usable > 0) then {_sumSight / _usable} else {0}];
_out set ["points",_points];
_out
