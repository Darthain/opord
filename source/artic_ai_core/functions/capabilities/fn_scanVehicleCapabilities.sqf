params [["_vehicle",objNull,[objNull]]];
if (isNull _vehicle) exitWith {[]};

private _roles = [];
private _cfg = configFile >> "CfgVehicles" >> typeOf _vehicle;

if (getNumber (_cfg >> "artilleryScanner") > 0) then { _roles pushBackUnique "ARTILLERY"; };
if (getNumber (_cfg >> "transportAmmo") > 0) then { _roles pushBackUnique "AMMO"; };
if (getNumber (_cfg >> "transportFuel") > 0) then { _roles pushBackUnique "FUEL"; };
if (getNumber (_cfg >> "transportRepair") > 0) then { _roles pushBackUnique "REPAIR"; };
if (getNumber (_cfg >> "attendant") > 0) then { _roles pushBackUnique "MEDICAL"; };
if ((_vehicle emptyPositions "cargo") >= 4) then { _roles pushBackUnique "TRANSPORT"; };

if (getNumber (_cfg >> "isUav") > 0) then { _roles pushBackUnique "RECON_UAS"; _roles pushBackUnique "UAS_OPERATOR"; };

private _sim = toLower getText (_cfg >> "simulation");
if (_sim find "tank" >= 0) then { _roles pushBackUnique "ARMOURED_COMBAT"; };
if (_sim find "helicopter" >= 0 || {_sim find "airplane" >= 0}) then { _roles pushBackUnique "AIR"; };

{
    _roles pushBackUnique _x;
} forEach (_vehicle getVariable ["ARTIC_roleOverrides",[]]);

_roles
