params [
    ["_group",grpNull,[grpNull]],
    ["_caps",createHashMap,[createHashMap]]
];
if (isNull _group || {(count _caps) isEqualTo 0}) exitWith {createHashMap};

([_group] call ARTIC_fnc_getProfile) params ["_doctrineName","_trainingName","_doctrine","_training"];
private _alive = +(_caps getOrDefault ["alive",[]]);
private _leader = leader _group;
private _reserve = [];

if (_doctrine getOrDefault ["preserveMedic",true]) then {
    { _reserve pushBackUnique _x; } forEach (_caps getOrDefault ["medic",[]]);
};
if (_doctrine getOrDefault ["preserveAT",true] && {count _alive >= 7}) then {
    { _reserve pushBackUnique _x; } forEach (_caps getOrDefault ["at",[]]);
};
_reserve = _reserve - [_leader];

private _available = _alive - _reserve;
if (count _available < 4) then {_available = +_alive; _reserve = [];};

private _supportCount = round ((count _available) * (_doctrine getOrDefault ["supportFraction",0.35]));
_supportCount = (_supportCount max 2) min ((count _available - 2) max 1);

private _specialistQuality = _training getOrDefault ["specialistAssignment",0.5];
private _scored = [];
{
    private _u = _x;
    private _score = 20 + random (50 * (1 - _specialistQuality));
    if (_u in (_caps getOrDefault ["mg",[]])) then {_score = _score + 120;};
    if (_u in (_caps getOrDefault ["grenadier",[]])) then {_score = _score + 55;};
    if (_u in (_caps getOrDefault ["radio",[]])) then {_score = _score + 10;};
    if (_u in (_caps getOrDefault ["at",[]])) then {_score = _score - 20;};
    if (_u isEqualTo _leader) then {_score = _score - 150;};
    _scored pushBack [_score,_u];
} forEach _available;
_scored sort false;

private _support = [];
for "_i" from 0 to ((_supportCount - 1) min ((count _scored) - 1)) do {
    _support pushBack ((_scored select _i) select 1);
};
private _manoeuvre = _available - _support;

if !(_leader in _manoeuvre) then {
    _support = _support - [_leader];
    _manoeuvre pushBackUnique _leader;
};

{_x setVariable ["ARTIC_elementRole","SUPPORT",true];} forEach _support;
{_x setVariable ["ARTIC_elementRole","MANOEUVRE",true];} forEach _manoeuvre;
{_x setVariable ["ARTIC_elementRole","RESERVE",true];} forEach _reserve;

createHashMapFromArray [
    ["support",_support],["manoeuvre",_manoeuvre],["reserve",_reserve]
]
