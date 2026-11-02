/*
    ARTIC v0.3.30 - likely enemy withdrawal lanes from an objective, for the BLOCK element.

    Candidate exits are placed on the enemy side of the objective relative to the attack axis
    (friendly -> objective): REAR, REAR_LEFT/REAR_RIGHT (+-45 deg) and LEFT/RIGHT (+-90 deg).
    Each lane is a mid point just outside the objective and an exit point beyond it.
      score = base (REAR 1.0, REAR_* 0.9, LEFT/RIGHT 0.6)
            + 1.5 x sight from the observer (BLOCK position) to the lane
            + 0.6 when a road runs through the lane
    Lanes that cannot be seen at all, or that pass within 70 m of a friendly manoeuvre
    corridor / final coordination point (fratricide risk while the flanks assault), are dropped.

    Arguments: 0 objective focus, 1 attack axis, 2 objective radius, 3 observer position,
               4 friendly keep-out positions, 5 max lanes (2)
    Returns (best first): [[name, exitPos, midPos, score, sight, onRoad, clash], ...]
*/
params [
    ["_focus",[],[[]]],
    ["_axis",0,[0]],
    ["_radius",100,[0]],
    ["_from",[],[[]]],
    ["_friendly",[],[[]]],
    ["_max",2,[0]]
];
if (_focus isEqualTo [] || {_from isEqualTo []}) exitWith {[]};
private _r = (_radius max 60) min 250;
private _out = [];
{
    _x params ["_name","_rel","_base"];
    private _dir = _axis + _rel;
    private _exit = _focus getPos [_r + 60,_dir]; _exit set [2,0];
    private _mid = _focus getPos [_r * 0.75,_dir]; _mid set [2,0];
    if (!(surfaceIsWater _exit) && {!(surfaceIsWater _mid)}) then {
        private _road = ((_exit nearRoads 30) isNotEqualTo []) || {(_mid nearRoads 30) isNotEqualTo []};
        private _sight = ([_from,[_mid,_exit],2] call ARTIC_fnc_battleSight) select 0;
        private _clash = (_friendly findIf {_x isEqualType [] && {(count _x) >= 2} && {(_x distance2D _mid) < 70 || {(_x distance2D _exit) < 70}}}) > -1;
        private _score = _base + (1.5 * _sight) + ([0,0.6] select _road);
        _out pushBack [_name,_exit,_mid,_score,_sight,_road,_clash];
    };
} forEach [["REAR",0,1.0],["REAR_LEFT",-45,0.9],["REAR_RIGHT",45,0.9],["LEFT",-90,0.6],["RIGHT",90,0.6]];
_out = _out select {(_x select 4) > 0 && {!(_x select 6)}};
_out = [_out,[],{_x select 3},"DESCEND"] call BIS_fnc_sortBy;
_out select [0,_max]
