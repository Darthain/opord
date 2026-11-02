/*
    ARTIC v0.3.15 - how much of the known enemy a position can see.

    For each target position, checks sight from the candidate at prone (0.6 m) and
    kneeling (1.2 m) eye height to the target at 1.0 m, against terrain AND objects using
    the VIEW and FIRE LODs (the 0.3.13 check used GEOM, which ignores foliage, so
    positions "saw" through bushes and treelines they cannot see through in game).

    Arguments: 0 position ATL/AGL, 1 array of target positions, 2 max targets to test (6)
    Returns:   [fraction visible 0..1, number visible, number tested]
*/
params [["_pos",[],[[]]],["_targets",[],[[]]],["_max",6,[0]]];
if (_pos isEqualTo [] || {_targets isEqualTo []}) exitWith {[0,0,0]};

private _test = if ((count _targets) > _max) then {
    ([_targets,[],{_x distance2D _pos},"ASCEND"] call BIS_fnc_sortBy) select [0,_max]
} else {_targets};

private _seen = 0;
{
    private _t = AGLToASL ([_x select 0,_x select 1,0] vectorAdd [0,0,1.0]);
    private _vis = false;
    {
        if (!_vis) then {
            private _eye = AGLToASL ([_pos select 0,_pos select 1,0] vectorAdd [0,0,_x]);
            // stop 1.5 m short so the enemy's own body doesn't count as an obstruction
            private _dirV = vectorNormalized (_t vectorDiff _eye);
            private _end = _t vectorDiff (_dirV vectorMultiply 1.5);
            if !(terrainIntersectASL [_eye,_end]) then {
                private _v = lineIntersectsSurfaces [_eye,_end,objNull,objNull,true,1,"VIEW","FIRE"];
                if (_v isEqualTo []) then {_vis = true;};
            };
        };
    } forEach [0.6,1.2];
    if (_vis) then {_seen = _seen + 1;};
} forEach _test;

[_seen / ((count _test) max 1), _seen, count _test]
