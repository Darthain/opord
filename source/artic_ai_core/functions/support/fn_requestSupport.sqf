params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_type","HE",[""]],
    ["_position",[],[[]]]
];
if (isNull _group) exitWith {false};
// v0.3.22: no linked fire support for this section recently -> don't keep requesting
// (0.3.21 re-requested HE every 20 s all mission with no mortar module linked).
if (time < (_group getVariable ["ARTIC_supportUnavailableUntil",0])) exitWith {false};
private _pos = +_position;
if (_pos isEqualTo []) then {
    _pos = if (isNull _target) then {_group getVariable ["ARTIC_orderPos",[]]} else {getPosATL _target};
};
if (_pos isEqualTo []) exitWith {false};

_group setVariable ["ARTIC_supportRequest",[toUpper _type,_pos,time],true];
[format ["Support request %1 at %2",toUpper _type,mapGridPosition _pos],groupId _group] call ARTIC_fnc_debug;
true
