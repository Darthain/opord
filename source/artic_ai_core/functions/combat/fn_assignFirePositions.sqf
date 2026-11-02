/*
    ARTIC v0.3.25 - firing positions from cover for a section in a contact LINE.

    For each fit soldier, around his LINE slot (within ~10 m), candidate positions are:
      - his slot,
      - directly behind nearby cover objects (trees, rocks, walls, buildings), on the side
        away from the threat,
      - at the EDGES of that cover (left / right), so he fires past it with most of his
        body covered. (AI leaning can't be scripted; edge positions plus stance are the
        equivalent.)
    Each candidate is tried prone / kneeling / standing (eye 0.6 / 1.2 / 1.6 m):
      sight  = fraction of threat positions visible from that eye height (VIEW/FIRE LODs)
      cover  = whether a shot from the threat at his body height (0.3 / 0.8 / 1.2 m) is
               blocked by an object or terrain
      score  = 2 x sight + 1.2 x cover + lower-profile bonus - distance from the slot
    Positions with no sight are not used. Chosen positions are kept at least ~60 % of the
    formation minimum separation apart (grenade dispersion). MG / grenadier choose first.

    Stores ARTIC_firePos = [position, stance "DOWN"/"MIDDLE"/"UP", sight, time] per soldier.
*/
params [["_group",grpNull,[grpNull]],["_threats",[],[[]]]];
if (isNull _group || {!local _group} || {_threats isEqualTo []}) exitWith {0};

private _tgts = ([_threats,[],{_x distance2D (leader _group)},"ASCEND"] call BIS_fnc_sortBy) select [0,3];
private _threatC = _tgts select 0;
private _sightFrom = {
    params ["_p","_h"];
    private _eye = AGLToASL ([_p select 0,_p select 1,0] vectorAdd [0,0,_h]);
    private _n = 0;
    {
        private _t = AGLToASL ([_x select 0,_x select 1,0] vectorAdd [0,0,1.0]);
        private _end = _t vectorDiff ((vectorNormalized (_t vectorDiff _eye)) vectorMultiply 1.5);
        if (!(terrainIntersectASL [_eye,_end]) && {(lineIntersectsSurfaces [_eye,_end,objNull,objNull,true,1,"VIEW","FIRE"]) isEqualTo []}) then {_n = _n + 1;};
    } forEach _tgts;
    _n / ((count _tgts) max 1)
};
private _coverAt = {
    params ["_p","_h"];
    private _from = AGLToASL ([_threatC select 0,_threatC select 1,0] vectorAdd [0,0,1.4]);
    private _to = AGLToASL ([_p select 0,_p select 1,0] vectorAdd [0,0,_h]);
    (terrainIntersectASL [_from,_to]) || {(lineIntersectsSurfaces [_from,_to,objNull,objNull,true,1,"FIRE","GEOM"]) isNotEqualTo []}
};

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _fit = (units _group) select {[_x] call ARTIC_fnc_isFit && {local _x} && {!isPlayer _x}};
private _first = ((_caps getOrDefault ["mg",[]]) + (_caps getOrDefault ["grenadier",[]])) select {_x in _fit};
private _order = _first + (_fit - _first);
private _minSep = ((_group getVariable ["ARTIC_formMinSep",6]) * 0.6) max 3;
private _stances = [["DOWN",0.6,0.3,0.25],["MIDDLE",1.2,0.8,0.1],["UP",1.6,1.2,-0.2]];
private _chosen = [];
private _done = 0;
{
    private _u = _x;
    private _slot = [_u,_group,false] call ARTIC_fnc_formationSlotWorld;
    if (_slot isEqualTo []) then {_slot = getPosATL _u;};
    _slot set [2,0];
    private _cands = [+_slot];
    private _objs = nearestTerrainObjects [_slot,["TREE","SMALL TREE","ROCK","ROCKS","WALL","HOUSE","BUILDING","FENCE"],10,true,true];
    _objs append ((nearestObjects [_slot,["House","Wall"],10]) - _objs);
    {
        private _o = _x;
        private _r = (((boundingBoxReal _o) select 2) min 3) max 0.3;
        private _away = _threatC getDir _o;
        private _behind = _o getPos [_r + 0.8,_away]; _behind set [2,0];
        _cands pushBack _behind;
        _cands pushBack (_behind getPos [_r * 0.9 + 0.5,_away + 90]);
        _cands pushBack (_behind getPos [_r * 0.9 + 0.5,_away - 90]);
    } forEach (_objs select [0,4]);

    private _best = []; private _bestSc = -1e9;
    {
        private _p = _x; _p set [2,0];
        if (!(surfaceIsWater _p) && {(_chosen findIf {(_x distance2D _p) < _minSep}) < 0}) then {
            {
                _x params ["_st","_eyeH","_bodyH","_bonus"];
                private _sg = [_p,_eyeH] call _sightFrom;
                if (_sg > 0) then {
                    private _cv = [_p,_bodyH] call _coverAt;
                    private _sc = (2 * _sg) + ([0,1.2] select _cv) + _bonus - 0.05 * (_p distance2D _slot);
                    if (_sc > _bestSc) then {_bestSc = _sc; _best = [+_p,_st,_sg];};
                };
            } forEach _stances;
        };
    } forEach _cands;
    if (_best isNotEqualTo []) then {
        _chosen pushBack (_best select 0);
        _u setVariable ["ARTIC_firePos",[_best select 0,_best select 1,_best select 2,time],false];
        _done = _done + 1;
    } else {
        _u setVariable ["ARTIC_firePos",[],false];
    };
} forEach _order;
_done
