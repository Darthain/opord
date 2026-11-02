params [
    ["_unit",objNull,[objNull]],
    ["_type","",[""]],
    ["_position",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_duration",30,[0]],
    ["_tolerance",8,[0]]
];
if (isNull _unit) exitWith {false};

// Install local danger sensors once. They only record the event; the actual
// response remains subordinate to the ARTIC parent task in individualStep.
if !(_unit getVariable ["ARTIC_dangerEHInstalled",false]) then {
    private _firedEH = _unit addEventHandler ["FiredNear", {
        params ["_unit","_firer","_distance"];
        if (!local _unit) exitWith {};
        private _hostile = !isNull _firer && {side group _unit getFriend side group _firer < 0.6};
        if (_hostile) then {
            private _pulse = (5.5 - ((_distance min 50) * 0.05)) max 2.5;
            _unit setVariable ["ARTIC_dangerPulseUntil",time + _pulse,false];
            _unit setVariable ["ARTIC_lastDangerSource",_firer,false];
            private _recent = _unit getVariable ["ARTIC_recentThreats",[]];
            _recent = _recent select {(time - (_x param [1,-1e6])) < 12 && {[_x param [0,objNull]] call ARTIC_fnc_isCombatEffectiveTarget}};
            private _idx = _recent findIf {(_x select 0) isEqualTo _firer};
            if (_idx < 0) then {_recent pushBack [_firer,time]} else {_recent set [_idx,[_firer,time]]};
            _unit setVariable ["ARTIC_recentThreats",_recent,false];
        };
    }];

    private _hitEH = _unit addEventHandler ["Hit", {
        params ["_unit","_source","_damage","_instigator"];
        if (!local _unit) exitWith {};
        private _src = if (!isNull _instigator) then {_instigator} else {_source};
        _unit setVariable ["ARTIC_dangerPulseUntil",time + 8,false];
        _unit setVariable ["ARTIC_lastHitAt",time,false];
        if (!isNull _src) then {
            _unit setVariable ["ARTIC_lastDangerSource",_src,false];
            private _recent = _unit getVariable ["ARTIC_recentThreats",[]];
            _recent = _recent select {(time - (_x param [1,-1e6])) < 12 && {[_x param [0,objNull]] call ARTIC_fnc_isCombatEffectiveTarget}};
            private _idx = _recent findIf {(_x select 0) isEqualTo _src};
            if (_idx < 0) then {_recent pushBack [_src,time]} else {_recent set [_idx,[_src,time]]};
            _unit setVariable ["ARTIC_recentThreats",_recent,false];
        };
    }];

    _unit setVariable ["ARTIC_dangerEHInstalled",true,false];
    _unit setVariable ["ARTIC_dangerFiredEH",_firedEH,false];
    _unit setVariable ["ARTIC_dangerHitEH",_hitEH,false];
};

private _taskType = toUpper _type;

// v0.3.21: engine knowledge is granted just-in-time for an explicit ARTIC combat
// task, never merely because UAS/sibling intelligence exists.  Automatic group attack
// assignment remains disabled; reveal here only lets doTarget/doSuppressiveFire work.
if (_taskType in ["SUPPRESS","ASSAULT"] && {[_target] call ARTIC_fnc_isCombatEffectiveTarget}) then {
    private _g = group _unit;
    if (!isNull _g) then {
        _g enableAttack false;
        _g reveal [_target,2.5];
        _g setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
    };
};

private _task = [_taskType,_position,_target,time + (_duration max 1),_tolerance max 1];
_unit setVariable ["ARTIC_unitTask",_task,false];
_unit setVariable ["ARTIC_unitTaskLastIssue",-1000,false];
_unit setVariable ["ARTIC_idleTask",false,false];
_unit setVariable ["ARTIC_formLastTarget",[],false];
_unit setVariable ["ARTIC_formLastAim",[],false];
_unit setVariable ["ARTIC_formSettled",false,false];
_unit setVariable ["ARTIC_formStopped",false,false];
_unit setVariable ["ARTIC_formCatchUp",false,false];
_unit setVariable ["ARTIC_speedApplied",-99,false];
true
