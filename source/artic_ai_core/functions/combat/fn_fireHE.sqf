/*
    ARTIC v0.3.25 - fire a high-explosive grenade-launcher round at a position.

    Finds an under-barrel / grenade-launcher muzzle on the soldier's primary weapon that
    takes a 40 mm-style HE round he is carrying (ammo simulation "shotShell"), places CBA's
    invisible "CBA_buildingPos" helper at the aim point, reveals and targets it, then fires
    that muzzle and switches back to the rifle. Used for enemy in cover, in buildings or in
    groups, where rifle fire does little.

    Returns true if a shot was started.
*/
params [["_unit",objNull,[objNull]],["_pos",[],[[]]]];
if (isNull _unit || {!alive _unit} || {!local _unit} || {_pos isEqualTo []}) exitWith {false};
private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {false};
private _wc = configFile >> "CfgWeapons" >> _w;
private _carried = magazines _unit;
private _muzzle = "";
{
    if (_muzzle isEqualTo "") then {
        private _mc = _wc >> _x;
        private _mags = getArray (_mc >> "magazines");
        {
            {_mags append (getArray _x);} forEach (configProperties [configFile >> "CfgMagazineWells" >> _x]);
        } forEach (getArray (_mc >> "magazineWell"));
        private _he = _mags findIf {
            private _m = _x;
            (_m in _carried) && {(toLower getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _m >> "ammo") >> "simulation")) isEqualTo "shotshell"}
        };
        if (_he > -1) then {_muzzle = _x;};
    };
} forEach ((getArray (_wc >> "muzzles")) - ["this","SAFE","Safe","safe"]);
if (_muzzle isEqualTo "") exitWith {false};

private _aim = +_pos; _aim set [2,0.5];
private _helper = "CBA_buildingPos" createVehicle _aim;
_helper setPosATL _aim;
_unit reveal [_helper,4];
_unit doWatch _helper;
_unit doTarget _helper;
[_unit,_helper,_muzzle,_w] spawn {
    params ["_u","_h","_mz","_w"];
    sleep 2.5;
    if (alive _u && {[_u] call ARTIC_fnc_isFit}) then {
        _u selectWeapon _mz;
        sleep 0.6;
        _u forceWeaponFire [_mz,(weaponState _u) select 2];
        sleep 1.2;
        _u selectWeapon _w;
        _u doWatch objNull;
    };
    sleep 8;
    deleteVehicle _h;
};
true
