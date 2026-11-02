params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_destination",[],[[]]]
];
if (isNull _group || {isNull _target} || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

[_group] call ARTIC_fnc_initFireteams;
private _teamA = (_group getVariable ["ARTIC_fireteamMembersA",[]]) select {[_x] call ARTIC_fnc_isFit};
private _teamB = (_group getVariable ["ARTIC_fireteamMembersB",[]]) select {[_x] call ARTIC_fnc_isFit};
if (_teamA isEqualTo [] || {_teamB isEqualTo []}) exitWith {false};

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
private _start = getPosATL leader _group;
private _targetPos = getPosATL _target;
if (_destination isEqualTo []) then {
    private _away = _targetPos getDir _start;
    _destination = _start getPos [180,_away];
};

_group setVariable ["ARTIC_currentPlan","FIGHTING_WITHDRAWAL",true];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group setVariable ["ARTIC_tacticalGuideActive",false,false];
_group setVariable ["ARTIC_movementOwner","FIRETEAM_GUIDES",false];
_group enableAttack false;
_group setBehaviourStrong "COMBAT";
_group setCombatMode "RED";

{
    if (alive _x && {local _x}) then {[_x,"HOLD",getPosATL _x,_target,90,5] call ARTIC_fnc_setUnitTask;};
} forEach units _group;

[format ["FIGHTING_WITHDRAWAL to %1",mapGridPosition _destination],groupId _group] call ARTIC_fnc_debug;

if (_tName in ["VETERAN","ELITE"]) then {
    [_group,_target,"SMOKE"] call ARTIC_fnc_requestSupport;
};

private _bound = _training getOrDefault ["boundDistance",45];
private _anchor = _start;
private _cycle = 0;

while {_anchor distance2D _destination > 25 && {local _group} && {alive _target}} do {
    private _step = _bound min (_anchor distance2D _destination);
    private _next = _anchor getPos [_step,_anchor getDir _destination];
    private _hold = if ((_cycle mod 2) isEqualTo 0) then {_teamA} else {_teamB};
    private _move = if ((_cycle mod 2) isEqualTo 0) then {_teamB} else {_teamA};

    [format ["Withdrawal bound %1: hold=%2 move=%3",_cycle + 1,count _hold,count _move],groupId _group] call ARTIC_fnc_debug;
    {if (alive _x && {local _x}) then {[_x,"SUPPRESS",getPosATL _x,_target,18,5] call ARTIC_fnc_setUnitTask;};} forEach _hold;
    private _sup = [_group,_target,15,_hold] spawn ARTIC_fnc_suppressElement;
    private _ok = [_group,_move,_next,_target,45,10,format ["WITHDRAWAL BOUND %1",_cycle + 1],false] call ARTIC_fnc_moveFireteamTactical;
    terminate _sup;
    if (!_ok || {!local _group}) exitWith {};

    _anchor = _next;
    _cycle = _cycle + 1;
    sleep 1.5;
};

if (local _group) then {
    _group setVariable ["ARTIC_tacticalGuideActive",true,false];
    [_group,_destination,_target,60,14,"WITHDRAWAL CONSOLIDATE"] call ARTIC_fnc_moveSectionTactical;
};
[_group] call ARTIC_fnc_finishPlan;
true
