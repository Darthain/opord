params [
    ["_target",objNull,[objNull]],
    ["_roles",[],[[]]]
];
if (isNull _target) exitWith {};
_target setVariable ["ARTIC_roleOverrides",_roles,true];
