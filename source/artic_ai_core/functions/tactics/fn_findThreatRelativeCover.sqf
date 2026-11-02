/*
    Find nearby cover that actually breaks hostile lines of sight, rather than a
    generically "cover-rich" point. Returns [position,score,blocked,total].
*/
params [
    ["_unit",objNull,[objNull]],
    ["_threats",[],[[]]],
    ["_radius",22,[0]],
    ["_reload",false,[true]]
];
if (isNull _unit) exitWith {[[], -1e9, 0, 0]};
_threats = _threats select {[_x] call ARTIC_fnc_isCombatEffectiveTarget};
_threats = _threats arrayIntersect _threats;
if (_threats isEqualTo []) exitWith {[[], -1e9, 0, 0]};

private _origin = getPosATL _unit;
private _total = count _threats;
private _scoreAt = {
    params ["_p"];
    if (_p isEqualTo [] || {surfaceIsWater _p}) exitWith {[-1e9,0]};
    private _n = surfaceNormal _p;
    private _slope = acos (((_n select 2) max -1) min 1);
    if (_slope > 30) exitWith {[-1e9,0]};
    private _blocked = 0;
    {if !([_p,_x] call ARTIC_fnc_hasLineOfSight) then {_blocked = _blocked + 1;};} forEach _threats;
    private _frac = _blocked / (_total max 1);
    private _cover = [_p] call ARTIC_fnc_coverScore;
    private _dist = _origin distance2D _p;
    private _mid = _origin vectorAdd ((_p vectorDiff _origin) vectorMultiply 0.5);
    private _midVisible = 0;
    {if ([_mid,_x] call ARTIC_fnc_hasLineOfSight) then {_midVisible = _midVisible + 1;};} forEach _threats;
    private _routePenalty = (_midVisible / (_total max 1)) * 18;
    private _score = (_frac * 82) + (_cover * 28) + ((1 - (_slope / 30)) * 8) - (_dist * 0.65) - _routePenalty;
    if (_reload && {_blocked isEqualTo _total}) then {_score = _score + 20;};
    [_score,_blocked]
};

private _current = [_origin] call _scoreAt;
private _bestPos = [];
private _bestScore = (_current select 0) + 5;
private _bestBlocked = _current select 1;
private _samples = 28;
for "_i" from 0 to (_samples - 1) do {
    private _ring = 4 + ((_i mod 4) * ((_radius - 4) / 3));
    private _angle = (_i * (360 / _samples)) + random 7;
    private _p = _origin getPos [_ring,_angle];
    private _r = [_p] call _scoreAt;
    _r params ["_score","_blocked"];
    if (_score > _bestScore || {(_reload && {_blocked > _bestBlocked} && {_score > (_bestScore - 8)})}) then {
        _bestScore = _score;
        _bestBlocked = _blocked;
        _bestPos = _p;
    };
};
[_bestPos,_bestScore,_bestBlocked,_total]
