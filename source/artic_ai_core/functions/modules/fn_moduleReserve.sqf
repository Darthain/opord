params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
{
    if !(_x isKindOf "Module_F") then {
        (group _x) setVariable ["ARTIC_forcedReserve", true, true];
    };
} forEach synchronizedObjects _logic;
_logic setVariable ["ARTIC_registered",true,true];
