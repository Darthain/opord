params ["_logic"];
if (isNull _logic) exitWith {};

ARTIC_debug = _logic getVariable ["Debug", true];
ARTIC_debugChat = _logic getVariable ["DebugChat", true];
ARTIC_debugMarkers = _logic getVariable ["DebugMarkers", true];

[format ["Core settings applied. Version %1", ARTIC_VERSION], "CORE"] call ARTIC_fnc_debug;
