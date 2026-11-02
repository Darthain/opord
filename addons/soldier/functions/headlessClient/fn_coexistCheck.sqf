// Copyright (C) 2026 OPORD contributors
// BSD 3-Clause License. See LICENSE in this addon.

/*
*  SFSM_fnc_coexistCheck
*  Warns (RPT and admins) if the Workshop release of this soldier addon (Workshop ID 2825929474)
*  is loaded alongside this bundled copy: both define the same classes and functions.
*  Arguments: none. Return: BOOL, true if a conflict was found. Server only; runs once.
*/
if (!isServer) exitWith {false};
if (!isNil "SFSM_coexistChecked") exitWith {SFSM_coexistChecked};
SFSM_coexistChecked = false;

private _found = (getLoadedModsInfo) findIf {
    private _text = (flatten [_x]) apply {str _x};
    _text findIf {"2825929474" in _x} > -1
} > -1;

if (_found) then {
    SFSM_coexistChecked = true;
    private _msg = "Soldier FSM: the Workshop mod 2825929474 is also loaded. Unload it, it conflicts with the soldier addons bundled in this mod.";
    diag_log ("***" + _msg + "***");

    // getUserInfo: index 1 is the owner ID, index 8 the admin state (0 = not an admin).
    private _admins = {
        ((allUsers apply {getUserInfo _x}) select {(_x select 8) > 0}) apply {_x select 1}
    };
    private _until = diag_tickTime + 60;
    waitUntil {sleep 2; count (call _admins) > 0 || {diag_tickTime > _until}};
    if (count (call _admins) > 0) then {[_msg] remoteExecCall ["systemChat", call _admins]};
};

SFSM_coexistChecked
