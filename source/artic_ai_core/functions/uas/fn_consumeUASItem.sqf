params [
    ["_operator",objNull,[objNull]],
    ["_source","",[""]],
    ["_isBackpack",false,[true]]
];
if (isNull _operator || {_source isEqualTo ""}) exitWith {false};

if (!local _operator) exitWith {
    [_operator,_source,_isBackpack] remoteExecCall ["ARTIC_fnc_consumeUASItem",_operator];
    true
};

if (_isBackpack) then {
    if ((backpack _operator) isEqualTo _source) then {removeBackpackGlobal _operator;};
} else {
    if (_source in magazines _operator) then {_operator removeMagazine _source;};
};
true
