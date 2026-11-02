/*
    Assess immediate, threat-relative exposure for one soldier.
    Returns [score, LOS threats, activeShooters, primaryThreat].
*/
params [
    ["_unit",objNull,[objNull]],
    ["_primary",objNull,[objNull]],
    ["_maxRange",450,[0]]
];
if (isNull _unit) exitWith {[0,[],0,objNull]};
private _group = group _unit;
private _threats = [];
private _recent = _unit getVariable ["ARTIC_recentThreats",[]];
_recent = _recent select {
    private _o = _x param [0,objNull];
    private _t = _x param [1,-1e6];
    [_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 12}
};
_unit setVariable ["ARTIC_recentThreats",_recent,false];
{_threats pushBackUnique (_x select 0);} forEach _recent;
if ([_primary] call ARTIC_fnc_isCombatEffectiveTarget) then {_threats pushBackUnique _primary;};

{
    private _o = _x param [0,objNull];
    private _p = _x param [1,[]];
    private _t = _x param [2,-1e6];
    if ([_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 45} && {_p isNotEqualTo []} && {_unit distance2D _p <= _maxRange}) then {
        _threats pushBackUnique _o;
    };
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);

private _uPos = getPosATL _unit;
private _los = _threats select {
    (_unit distance2D _x) <= _maxRange && {[_uPos,_x] call ARTIC_fnc_hasLineOfSight}
};
private _active = 0;
{
    private _o = _x select 0;
    private _t = _x select 1;
    if (_o in _los && {(time - _t) < 7}) then {_active = _active + 1;};
} forEach _recent;
private _supp = (getSuppression _unit) max 0;
private _pulse = time < (_unit getVariable ["ARTIC_dangerPulseUntil",0]);
private _hitRecent = (time - (_unit getVariable ["ARTIC_lastHitAt",-1e6])) < 10;
private _score = (((count _los) min 4) * 0.18) + ((_active min 3) * 0.16) + (_supp * 0.30) + ([0,0.16] select _pulse) + ([0,0.18] select _hitRecent);
_score = (_score max 0) min 1;

private _best = objNull;
if (_recent isNotEqualTo []) then {
    private _sorted = [_recent,[],{_unit distance2D (_x select 0)},"ASCEND"] call BIS_fnc_sortBy;
    private _cand = (_sorted select 0) select 0;
    if (_cand in _los) then {_best = _cand;};
};
if (isNull _best && {_los isNotEqualTo []}) then {
    private _s = [_los,[],{_unit distance2D _x},"ASCEND"] call BIS_fnc_sortBy;
    _best = _s select 0;
};
[_score,_los,_active,_best]
