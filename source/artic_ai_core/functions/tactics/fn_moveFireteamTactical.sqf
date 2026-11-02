/*
    ARTIC v0.3.17 - self-paced fireteam tactical guide.

    Moves one persistent fireteam without using the retired moveElement / live-centroid
    anchor system. Every soldier follows a deterministic slot around one moving guide.
    Immediate danger reactions in individualStep remain higher priority.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_members",[],[[]]],
    ["_destination",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_timeout",50,[0]],
    ["_tolerance",10,[0]],
    ["_label","FIRETEAM",[""]],
    ["_line",false,[true]]
];
if (isNull _group || {!local _group} || {_destination isEqualTo []}) exitWith {false};
private _valid = _members select {local _x && {[_x] call ARTIC_fnc_isFit}};
if (_valid isEqualTo []) exitWith {false};

[_group] call ARTIC_fnc_initFireteams;
private _sx = 0; private _sy = 0;
{private _p = getPosATL _x; _sx = _sx + (_p select 0); _sy = _sy + (_p select 1);} forEach _valid;
private _anchor = [_sx / count _valid,_sy / count _valid,0];
private _dir = _anchor getDir _destination;
private _end = time + (_timeout max 8);
private _pace = 2.1;
([_group] call ARTIC_fnc_getProfile) params ["","","","_training"];
private _coord = _training getOrDefault ["coordination",0.55];
_pace = 1.7 + 0.8 * _coord;

{
    _x setVariable ["ARTIC_fireteamMoveAnchor",+_anchor,false];
    _x setVariable ["ARTIC_fireteamMoveDir",_dir,false];
    _x setVariable ["ARTIC_fireteamMoveLine",_line,false];
    [_x,"FIRETEAM",[],_target,_timeout + 5,8] call ARTIC_fnc_setUnitTask;
} forEach _valid;

[format ["%1 guide movement -> %2 (%3 men)",_label,mapGridPosition _destination,count _valid],groupId _group] call ARTIC_fnc_debug;
private _ok = false;
waitUntil {
    sleep 0.35;
    if (!local _group) exitWith {true};
    _valid = _valid select {[_x] call ARTIC_fnc_isFit};
    if (_valid isEqualTo []) exitWith {true};

    private _maxErr = 0; private _near = 0;
    {
        private _slot = [_x,_anchor,_dir,1,_line] call ARTIC_fnc_fireteamSlotWorld;
        private _d = _x distance2D _slot;
        _maxErr = _maxErr max _d;
        if (_d <= 12) then {_near = _near + 1;};
    } forEach _valid;

    private _dist = _anchor distance2D _destination;
    if (_dist <= _tolerance && {_near >= ceil ((count _valid) * 0.75)} && {_maxErr <= 22}) exitWith {_ok = true; true};

    // Guide only advances while the team is sufficiently coherent. It never derives its
    // next position from a runaway soldier.
    private _coherent = _near >= ceil ((count _valid) * 0.65) && {_maxErr <= 30};
    if (_coherent && {_dist > _tolerance}) then {
        private _step = (_pace * 0.35) min _dist;
        _dir = _anchor getDir _destination;
        _anchor = _anchor getPos [_step,_dir];
        _anchor set [2,0];
        {
            _x setVariable ["ARTIC_fireteamMoveAnchor",+_anchor,false];
            _x setVariable ["ARTIC_fireteamMoveDir",_dir,false];
        } forEach _valid;
    };
    time > _end
};

if (!_ok) then {
    [format ["%1 guide movement incomplete; team held for reassessment",_label],groupId _group] call ARTIC_fnc_debug;
};
_ok
