params [
    ["_commanderId","",[""]],
    ["_contacts",[],[[]]],
    ["_sensor",objNull,[objNull]]
];
if (!isServer || {_commanderId isEqualTo ""} || {_contacts isEqualTo []}) exitWith {0};
private _commander = ARTIC_Commanders getOrDefault [_commanderId,createHashMap];
if ((count _commander) isEqualTo 0) exitWith {0};

private _side = _commander get "side";
private _known = _commander getOrDefault ["knownEnemies",[]];
private _reports = _commander getOrDefault ["uasContacts",[]];
private _valid = [];

{
    if (([_x] call ARTIC_fnc_isCombatEffectiveTarget) && {(_side getFriend side _x) < 0.6}) then {
        _known pushBackUnique _x;
        _valid pushBackUnique _x;
        // Keep a simple [object,time] history; duplicates are compacted below.
        _reports pushBack [_x,time];
    };
} forEach _contacts;

private _dedup = [];
{
    _x params ["_obj","_t"];
    private _old = _dedup findIf {(_x select 0) isEqualTo _obj};
    if (_old < 0) then {_dedup pushBack [_obj,_t]} else {
        if (_t > ((_dedup select _old) select 1)) then {_dedup set [_old,[_obj,_t]];};
    };
} forEach _reports;
_dedup = _dedup select {([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - (_x select 1)) < 300}};

_commander set ["knownEnemies",_known];
_commander set ["uasContacts",_dedup];
_commander set ["lastUASReport",time];

// v0.3.21: UAS intelligence is stored in ARTIC's commander picture only.
// fn_updateCommanderIntel disseminates it as ARTIC_sharedContacts.  We deliberately
// do not call `reveal` here: vanilla group knowledge was the source of mass automatic
// ATTACK assignments during REPOSITION_FOR_ATTACK.

// A recon sensor can establish a battlefield before the manoeuvre force makes
// direct contact. This gives the platoon time to build hold/fire/assault lines.
if ((count _valid) >= 2) then {
    [_commander,_valid,"UAS"] call ARTIC_fnc_classifyBattlefields;
};

[format ["UAS reported %1 contact(s)",count _valid],_commanderId] call ARTIC_fnc_debug;
count _valid
