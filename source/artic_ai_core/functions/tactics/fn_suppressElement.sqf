params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_duration",15,[0]],
    ["_units",[],[[]]],
    ["_ownedPlay",false,[true]]
];
if (isNull _group || {!local _group} || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)}) exitWith {};

private _planId = _group getVariable ["ARTIC_platoonPlanId",""];
private _taskId = _group getVariable ["ARTIC_sectionTaskId",""];
private _stale = {[_group,_planId,_taskId,false] call ARTIC_fnc_isPlayStale};

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
if (_units isEqualTo []) then {
    _units = (_caps getOrDefault ["mg",[]]) + (_caps getOrDefault ["grenadier",[]]);
    if (_units isEqualTo []) then {_units = (_caps getOrDefault ["alive",[]]) select [0,((count (_caps get "alive")) min 3)];};
};

private _mg = _caps getOrDefault ["mg",[]];
private _gren = _caps getOrDefault ["grenadier",[]];
private _end = time + _duration;
private _warned = false;
_group setVariable ["ARTIC_suppressionEstimate",0,true];

while {time < _end && {local _group} && {[_target] call ARTIC_fnc_isCombatEffectiveTarget} && {!_ownedPlay || {!(call _stale)}}} do {
    private _effective = [];
    {
        if (alive _x && {local _x}) then {
            // v0.3.22: the planner's sight test (VIEW/FIRE LODs) OR the legacy check, so a
            // shooter the planner validated is never discounted by a stricter second test
            private _los = ((([getPosATL _x,[getPosATL _target],1] call ARTIC_fnc_battleSight) select 0) > 0)
                || {[getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight};
            if (_los) then {
                _effective pushBack _x;
                [_x,"SUPPRESS",getPosATL _x,_target,6,4] call ARTIC_fnc_setUnitTask;
                [_x] call ARTIC_fnc_individualStep;
            } else {
                [_x,"HOLD",getPosATL _x,_target,6,4] call ARTIC_fnc_setUnitTask;
            };
        };
    } forEach _units;

    if (_effective isEqualTo [] && {!_warned}) then {
        ["Support element has no line of sight; suppression ineffective",groupId _group] call ARTIC_fnc_debug;
        _warned = true;
    };

    private _gain = 0;
    {
        _gain = _gain + 0.045;
        if (_x in _mg) then {_gain = _gain + 0.09;};
        if (_x in _gren) then {_gain = _gain + 0.035;};
    } forEach _effective;
    private _estimate = ((_group getVariable ["ARTIC_suppressionEstimate",0]) + _gain) min 1;
    _group setVariable ["ARTIC_suppressionEstimate",_estimate,true];
    sleep 2.5;
};

if (_ownedPlay && {call _stale}) then {[format ["ASSIST suppression ended: stale plan=%1 task=%2",_planId,_taskId],groupId _group] call ARTIC_fnc_debug;};
true
