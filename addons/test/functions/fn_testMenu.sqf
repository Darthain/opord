/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_testMenu (clients): ACE self-interaction "OPORD tests" for admins (hosted host, logged-in
    admin) when the "Test menu" setting is on. Each entry asks the server to run a checkpoint test in
    front of the admin.
*/
if (!hasInterface) exitWith {};
private _cond = { (missionNamespace getVariable ["OPORD_testMenu", false]) && {isServer || {serverCommandAvailable "#kick"}} };
private _root = ["OPORD_tests", "OPORD tests", "", {}, _cond] call ace_interact_menu_fnc_createAction;
["CAManBase", 1, ["ACE_SelfActions"], _root, true] call ace_interact_menu_fnc_addActionToClass;
{
    _x params ["_id", "_name"];
    private _a = [format ["OPORD_test_%1", _id], _name, "", { params ["", "", "_id"]; ["OPORD_test", [_id, ACE_player]] call CBA_fnc_serverEvent; }, { true }, {}, _id] call ace_interact_menu_fnc_createAction;
    ["CAManBase", 1, ["ACE_SelfActions", "OPORD_tests"], _a, true] call ace_interact_menu_fnc_addActionToClass;
} forEach [
    ["D1", "D1: deliberate defence + trenches"], ["D1H", "D1h: hasty defence"], ["D1S", "D1s: support by fire"],
    ["D2", "D2: statics from backpacks"], ["D2T", "D2t: statics from a truck"], ["D2C", "D2c: ACE CSW statics + ammo"],
    ["D3", "D3: send attackers at last position"], ["D8", "D8: load test, 4 positions"],
    ["STATUS", "Status of running tests"], ["CLEAR", "Clear test units and earthworks"]
];
