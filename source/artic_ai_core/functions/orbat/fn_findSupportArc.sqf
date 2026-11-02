/*
    ARTIC v0.3.23 - support-by-fire zone search with friendly-side / access safety.

    Searches a bounded friendly-side arc around the enemy focus, rejects positions that
    require the fixing element to cross the enemy exclusion area, then ranks the remaining
    positions by sight, cover, terrain and movement cost.

    Returns [position, sightFraction, score].
*/
params [
    ["_focus",[],[[]]],
    ["_friendlyCentre",[],[[]]],
    ["_targets",[],[[]]],
    ["_preferredDepth",170,[0]],
    ["_battleRadius",100,[0]]
];
if (_focus isEqualTo [] || {_friendlyCentre isEqualTo []} || {_targets isEqualTo []}) exitWith {[[],0,-1e9]};

private _friendlyBearing = _focus getDir _friendlyCentre;

// v0.3.23 route-safety revision: the support-position selector and the section route
// planner now use the same enemy exclusion distance.  Earlier the SBF test used a
// candidate-relative 75% heuristic while routing used battleRadius + 80 m, so the two
// layers could disagree about whether the position was safely accessible.
private _avoidRadius = (_battleRadius + 80) max 100;
private _rMin = _avoidRadius max (_preferredDepth * 0.65) max 90;
// v0.3.22: stay within ~1.3x the envelope's fire distance.  Ensure there is still a
// useful radial search band when the exclusion radius itself is larger than that depth.
private _rMax = ((_preferredDepth * 1.3) max (_rMin + 30)) min 360;
private _rMid = (_rMin + _rMax) * 0.5;
private _rPreferred = (_preferredDepth max _rMin) min _rMax;
private _radii = [_rMin,_rMid,_rPreferred,_rMax] arrayIntersect [_rMin,_rMid,_rPreferred,_rMax];

// v0.3.23: keep the SBF on the friendly half of the battlefield.  +/-85 deg could place
// FIX almost on the enemy's far flank.  +/-55 still permits an oblique base of fire while
// keeping the support element on the same operational side as the platoon release area.
private _angles = [-55,-40,-25,-10,0,10,25,40,55];

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

private _best = [];
private _bestSight = -1;
private _bestScore = -1e9;

{
    private _r = _x;
    {
        private _ang = _x;
        private _ideal = _focus getPos [_r,_friendlyBearing + _ang];
        _ideal set [2,0];
        private _local = [_ideal,_focus,"FIRE",32,_friendlyBearing + 180,if (_ang < -5) then {-1} else {if (_ang > 5) then {1} else {0}},_targets] call ARTIC_fnc_findBattleControlPoint;
        private _cand = _local select 0;

        if (_cand isNotEqualTo []) then {
            // findBattleControlPoint may move the candidate tens of metres.  Recheck that
            // the final candidate is still on the friendly side and outside the exclusion
            // area rather than trusting the ideal sample angle.
            private _candBearing = _focus getDir _cand;
            private _relFriendly = (((_candBearing - _friendlyBearing) + 540) % 360) - 180;
            private _onFriendlySide = abs _relFriendly <= 70;
            private _outsideEnemy = (_cand distance2D _focus) >= (_avoidRadius * 0.97);
            private _approachClear = ([_friendlyCentre,_cand,_focus] call _segmentMinDistance) >= (_avoidRadius * 0.98);

            if (_onFriendlySide && {_outsideEnemy} && {_approachClear}) then {
                private _sight = ([_cand,_targets,8] call ARTIC_fnc_battleSight) select 0;
                private _terrain = nearestTerrainObjects [_cand,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],18,false,true];
                private _cover = ((count _terrain) min 8) / 8;
                private _move = _friendlyCentre distance2D _cand;
                private _n = surfaceNormal _cand;
                private _slope = acos (((_n select 2) max -1) min 1);
                private _score = 5.5 * _sight + 0.65 * _cover - 0.004 * _move - 0.025 * _slope;

                // Sight is the primary discriminator. A position seeing more enemy always
                // beats one with materially less visibility, then terrain/movement break ties.
                if (_sight > (_bestSight + 0.05) || {abs (_sight - _bestSight) <= 0.05 && {_score > _bestScore}}) then {
                    _best = +_cand;
                    _bestSight = _sight;
                    _bestScore = _score;
                };
            };
        };
    } forEach _angles;
} forEach _radii;

[_best,_bestSight max 0,_bestScore]
