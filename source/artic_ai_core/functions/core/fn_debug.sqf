params [
    ["_message", "", [""]],
    ["_scope", "", [""]]
];

if !(missionNamespace getVariable ["ARTIC_debug", false]) exitWith {};

private _prefix = "[ARTIC]";
if (_scope isNotEqualTo "") then {
    _prefix = format ["[ARTIC][%1]", _scope];
};

private _line = format ["%1 %2", _prefix, _message];
diag_log _line;

if (missionNamespace getVariable ["ARTIC_debugChat", false]) then {
    [_line] remoteExec ["systemChat", 0];
};
