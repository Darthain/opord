/*
    ARTIC - terrain-aware battlefield control point search (v0.3.15).

    Finds a useful point around an ideal battle-geometry point.
    _mode:
      FIRE                      : must SEE the known enemy (fraction of contacts visible,
                                  VIEW/FIRE LODs) + nearby cover
      HOLD / RELEASE / APPROACH : prefer being hidden from the known enemy + cover
      ASSAULT                   : last hidden/covered position near the enemy

    v0.3.15:
      - sight is tested against the known enemy POSITIONS (_targets) with the VIEW and
        FIRE LODs (fn_battleSight), not one GEOM ray to the battlefield centre;
      - the search radius comes from the battle envelope (up to 110 m for fire positions)
        with sampling that scales so large searches stay cheap.

    Arguments: ideal, focus, mode, search radius, axis, side (-1/0/1), targets (optional)
    Returns: [position, sightFraction]
*/
params [
    ["_ideal",[],[[]]],
    ["_focus",[],[[]]],
    ["_mode","HOLD",[""]],
    ["_search",45,[0]],
    ["_axis",0,[0]],
    ["_side",0,[0]],
    ["_targets",[],[[]]]
];
if (_ideal isEqualTo [] || {_focus isEqualTo []}) exitWith {[+_ideal,0]};
_mode = toUpper _mode;
if (_targets isEqualTo []) then {_targets = [_focus];};

private _step = (_search / 5) max 12;
private _rings = [0];
private _r = _step;
while {_r <= _search + 0.1} do {_rings pushBack _r; _r = _r + _step;};
private _angles = [0,45,90,135,180,225,270,315];

private _best = +_ideal; _best set [2,0];
private _bestScore = -1e9;
private _bestFrac = 0;
{
    private _rr = _x;
    private _dirs = if (_rr isEqualTo 0) then {[0]} else {_angles};
    {
        private _p = if (_rr isEqualTo 0) then {+_ideal} else {_ideal getPos [_rr,_x]};
        _p set [2,0];
        if !(surfaceIsWater _p) then {
            private _n = surfaceNormal _p;
            private _slope = acos (((_n select 2) max -1) min 1);
            if (_slope <= 32) then {
                (([_p,_targets] call ARTIC_fnc_battleSight)) params ["_frac"];
                private _terrain = nearestTerrainObjects [_p,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],16,false,true];
                private _cover = ((count _terrain) min 8) / 8;
                private _distPenalty = (_p distance2D _ideal) / ((_search max 1) * 1.4);
                private _slopePenalty = _slope / 32;
                private _score = switch (_mode) do {
                    case "FIRE": {
                        // must see most of the enemy; cover is a bonus
                        (3 * _frac) + ([0,1] select (_frac >= 0.5)) + 0.8 * _cover - 0.7 * _slopePenalty - 0.45 * _distPenalty
                    };
                    case "ASSAULT": {
                        (1.6 * (1 - _frac)) + 1.0 * _cover - 0.55 * _slopePenalty - 0.35 * _distPenalty
                    };
                    default {
                        (1.5 * (1 - _frac)) + 0.9 * _cover - 0.6 * _slopePenalty - 0.4 * _distPenalty
                    };
                };
                // keep the intended side of the battlefield (penalty, not hard reject)
                if (_side isNotEqualTo 0) then {
                    private _rel = (((_focus getDir _p) - (_axis + 180) + 540) % 360) - 180;
                    if (([1,-1] select (_rel < 0)) isNotEqualTo _side) then {_score = _score - 2.0;};
                };
                if (_score > _bestScore) then {_bestScore = _score; _best = +_p; _bestFrac = _frac;};
            };
        };
    } forEach _dirs;
} forEach _rings;
[_best,_bestFrac]
