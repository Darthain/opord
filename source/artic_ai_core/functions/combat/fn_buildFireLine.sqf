/*
    ARTIC v0.3.30 - section fire line (extracted from the v0.3.24 FIX occupation so that FIX
    and BLOCK use the same code).

    One firing point per shooter along a line through the anchor, across the line of fire.
    Candidates every half minimum-separation along the line, each also tried 4 m forward and
    back; each scored on its own sight of the score positions (ARTIC_fnc_battleSight, VIEW/FIRE
    LODs) and nearby cover. Points are at least the formation minimum separation apart; the
    shooters are served in the order given (callers put MGs first, so MGs get the best points).
    Each shooter is given a HOLD task on his point (stance MIDDLE).

    Arguments:
      0 group, 1 anchor position, 2 aim position (defines the line of fire),
      3 score positions (enemy positions, withdrawal lanes ...), 4 shooters (ordered),
      5 target object (for the HOLD task), 6 max score positions tested per candidate (4)
    Returns HashMap: points [[unit,pos],...], half (m), minSep (m), bestSight (0..1)
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_anchor",[],[[]]],
    ["_aimPos",[],[[]]],
    ["_scorePos",[],[[]]],
    ["_shooters",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_maxTest",4,[0]]
];
private _out = createHashMapFromArray [["points",[]],["half",0],["minSep",5],["bestSight",0]];
if (isNull _group || {_anchor isEqualTo []} || {_aimPos isEqualTo []} || {_shooters isEqualTo []}) exitWith {_out};
if (_scorePos isEqualTo []) then {_scorePos = [+_aimPos];};

private _minSep = ((_group getVariable ["ARTIC_formMinSep",6]) max 5);
private _toEnemy = _anchor getDir _aimPos;
private _half = (((count _shooters) - 1) * _minSep * 0.5) + _minSep;
private _cands = [];
for "_k" from -_half to _half step (_minSep * 0.5) do {
    {
        private _p = if ((abs _k) > 0.1) then {_anchor getPos [abs _k,_toEnemy + ([90,-90] select (_k < 0))]} else {+_anchor};
        if ((abs _x) > 0.1) then {_p = _p getPos [abs _x,_toEnemy + ([0,180] select (_x < 0))];};
        _p set [2,0];
        if !(surfaceIsWater _p) then {
            private _sg = ([_p,_scorePos,_maxTest] call ARTIC_fnc_battleSight) select 0;
            private _cv = ((count (nearestTerrainObjects [_p,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],5,false,true])) min 3) / 3;
            _cands pushBack [(2 * _sg) + (0.7 * _cv) - (0.01 * abs _k),_p,_sg];
        };
    } forEach [0,-4,4];
};
_cands sort false;

private _chosen = [];
private _firePoints = [];
{
    private _u = _x;
    private _pick = _cands findIf {private _c = _x select 1; (_chosen findIf {(_x distance2D _c) < _minSep}) < 0};
    private _pt = if (_pick > -1) then {(_cands select _pick) select 1} else {_anchor getPos [_minSep * (_forEachIndex + 1),_toEnemy + 90]};
    _chosen pushBack _pt;
    _firePoints pushBack [_u,_pt];
    [_u,"HOLD",_pt,_target,400,3] call ARTIC_fnc_setUnitTask;
    _u setUnitPosWeak "MIDDLE";
} forEach _shooters;

_out set ["points",_firePoints];
_out set ["half",_half];
_out set ["minSep",_minSep];
_out set ["bestSight",(_cands param [0,[0,[],0]]) select 2];
_out
