params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
private _raw = _logic getVariable ["Roles",""];
private _roles = (_raw splitString ",") apply { toUpper _x };
_roles = _roles select { _x isNotEqualTo "" };
{
    if !(_x isKindOf "Module_F") then {
        _x setVariable ["ARTIC_roleOverrides", _roles, true];
        if (_x isKindOf "Man") then {
            (group _x) setVariable ["ARTIC_roleOverrides", _roles, true];
        };
    };
} forEach synchronizedObjects _logic;
_logic setVariable ["ARTIC_registered",true,true];
