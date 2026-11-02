params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
_logic setVariable ["ARTIC_registered", true, true];
