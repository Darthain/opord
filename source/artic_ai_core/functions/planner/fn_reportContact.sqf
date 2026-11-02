/*
    ARTIC v0.3.24 - section contact call ("contact report").

    Sent when a section first makes contact, or when it picks up a new enemy group more
    than 60 m from its last call (at most every 20 s). Contains what the section sees,
    from where, in the form a section commander would send it:

        CONTACT! Alpha 1-2: 3x enemy infantry incl. 1 MG, 1 AT - bearing 045, 210 m, grid 043038

    Published as ARTIC_contactCall (public, the platoon controller on the server acts on it):
        [time (CBA_missionTime), enemy pos, bearing, distance, description, count,
         target object, reporting group id]
*/
params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]]];
if (isNull _group || {isNull _target} || {!local _group}) exitWith {false};
if !(missionNamespace getVariable ["ARTIC_contactCalls",true]) exitWith {false};

private _now = CBA_missionTime;
private _tPos = getPosATL _target;
private _last = _group getVariable ["ARTIC_contactCall",[]];
if (_last isNotEqualTo [] && {(_now - (_last select 0)) < 20}) exitWith {false};
if (_last isNotEqualTo [] && {((_last select 1) distance2D _tPos) < 60} && {(_now - (_last select 0)) < 120}) exitWith {false};

private _ref = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];
private _bearing = round (_ref getDir _tPos);
private _dist = round (_ref distance2D _tPos);

// what the section can see around the target
private _known = ((leader _group) targets [true,1200]) select {alive _x && {(_x distance2D _tPos) < 60}};
_known pushBackUnique _target;
private _veh = []; private _inf = 0; private _mg = 0; private _at = 0; private _static = 0;
{
    private _v = vehicle _x;
    if (_v isNotEqualTo _x) then {
        if (_v isKindOf "StaticWeapon") then {_static = _static + 1;} else {_veh pushBackUnique _v;};
    } else {
        _inf = _inf + 1;
        private _mag = currentMagazine _x;
        if (_mag isNotEqualTo "" && {getNumber (configFile >> "CfgMagazines" >> _mag >> "count") >= 75}) then {_mg = _mg + 1;};
        if ((secondaryWeapon _x) isNotEqualTo "") then {_at = _at + 1;};
    };
} forEach _known;
private _parts = [];
if (_inf > 0) then {
    private _extra = [];
    if (_mg > 0) then {_extra pushBack format ["%1 MG",_mg];};
    if (_at > 0) then {_extra pushBack format ["%1 AT",_at];};
    _parts pushBack (format ["%1x enemy infantry",_inf] + (if (_extra isEqualTo []) then {""} else {" incl. " + (_extra joinString ", ")}));
};
if (_static > 0) then {_parts pushBack format ["%1x static weapon",_static];};
{_parts pushBack format ["vehicle (%1)",getText (configOf _x >> "displayName")];} forEach _veh;
private _desc = if (_parts isEqualTo []) then {"enemy"} else {_parts joinString ", "};
private _count = _inf + _static + count _veh;

private _call = [_now,_tPos,_bearing,_dist,_desc,_count,_target,groupId _group];
_group setVariable ["ARTIC_contactCall",_call,true];
[format ["CONTACT! %1: %2 - bearing %3, %4 m, grid %5",groupId _group,_desc,[_bearing,3] call CBA_fnc_formatNumber,_dist,mapGridPosition _tPos],groupId _group] call ARTIC_fnc_debug;
true
