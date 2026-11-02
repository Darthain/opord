/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_testRun (server): checkpoint test harness. Spawns a test setup in front of the admin who
    asked (works on any map) and reports results to admins and the RPT.

    Tests (checkpoint IDs from the build path):
      D1  deliberate defence with connected trenches     D1h hasty defence     D1s support by fire
      D2  statics from worn backpacks (HMG + mortar)     D2t statics from a truck's cargo
      D2c ACE CSW statics + ammo crate (needs ACE "Advanced Assembly" on)
      D3  attackers sent at the most recent test position
      D8  load: 4 deliberate battle positions at once
      CLEAR / STATUS
    Arguments: 0: Test id, 1: Admin unit
*/
params ["_id", ["_caller", objNull]];
if (!isServer || {isNull _caller}) exitWith {};
if (isNil "OPORD_testRuns") then { OPORD_testRuns = []; };   // [group, id, startTime, centre, dir]

private _say = { params ["_m"]; [_m, "INFO"] call OPORD_fnc_log; ["OPORD_adminMessage", ["[OPORD TEST] " + _m]] call CBA_fnc_globalEvent; };
private _dir = getDir _caller;
private _centreAt = { params ["_lat"]; private _p = (_caller getPos [90, _dir]) getPos [_lat, _dir + 90]; _p set [2, 0]; _p };

private _spawnDefenders = {
    params ["_centre"];
    private _cfg = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";
    private _g = [_caller getPos [60, _dir], east, _cfg] call BIS_fnc_spawnGroup;
    _g setVariable ["OPORD_testGroup", true, true];
    _g
};
private _start = {
    params ["_g", "_centre", "_type", "_opt", "_label"];
    OPORD_testRuns pushBack [_g, _label, time, _centre, _dir + 180];
    // Let ownership settle (Soldier FSM moves groups to its headless client), then build.
    [{
        params ["_g"];
        private _hostOwner = call OPORD_fnc_soldierHost;
        (_hostOwner <= 2) || {groupOwner _g == _hostOwner}
    }, {
        params ["_g", "_centre", "_dir", "_type", "_opt"];
        [_g, _centre, _dir, _type, _opt] call OPORD_fnc_prepareBattlePosition;
    }, [_g, _centre, _dir + 180, _type, _opt], 60, {
        params ["_g", "_centre", "_dir", "_type", "_opt"];
        [_g, _centre, _dir, _type, _opt] call OPORD_fnc_prepareBattlePosition;
    }] call CBA_fnc_waitUntilAndExecute;
    [format ["%1 started at %2 (owner %3).", _label, mapGridPosition _centre, groupOwner _g]] call _say;
};
private _giveBags = {
    params ["_g", "_bags"];
    private _men = (units _g) select { _x != leader _g };
    {
        private _u = _men param [_forEachIndex, objNull];
        if (!isNull _u) then { removeBackpackGlobal _u; _u addBackpackGlobal _x; };
    } forEach _bags;
};

switch (toUpperANSI _id) do {
    case "D1": { private _c = [0] call _centreAt; [[_c] call _spawnDefenders, _c, "DEFENCE", createHashMapFromArray [["quality", "DELIBERATE"], ["trench", true]], "D1 deliberate defence"] call _start; };
    case "D1H": { private _c = [0] call _centreAt; [[_c] call _spawnDefenders, _c, "DEFENCE", createHashMapFromArray [["quality", "HASTY"], ["trench", false]], "D1h hasty defence"] call _start; };
    case "D1S": { private _c = [0] call _centreAt; [[_c] call _spawnDefenders, _c, "SBF", createHashMap, "D1s support by fire"] call _start; };
    case "D2": {
        private _c = [0] call _centreAt; private _g = [_c] call _spawnDefenders;
        [_g, ["O_HMG_01_high_weapon_F", "O_HMG_01_support_high_F", "O_Mortar_01_weapon_F", "O_Mortar_01_support_F"]] call _giveBags;
        [_g, _c, "DEFENCE", createHashMapFromArray [["quality", "HASTY"]], "D2 statics from backpacks"] call _start;
    };
    case "D2T": {
        private _c = [0] call _centreAt; private _g = [_c] call _spawnDefenders;
        private _truck = createVehicle ["O_Truck_03_transport_F", _c getPos [25, _dir], [], 0, "NONE"];
        _truck addBackpackCargoGlobal ["O_HMG_01_high_weapon_F", 1]; _truck addBackpackCargoGlobal ["O_HMG_01_support_high_F", 1];
        _truck setVariable ["OPORD_testObject", true, true];
        [_g, _c, "DEFENCE", createHashMapFromArray [["quality", "HASTY"]], "D2t statics from truck cargo"] call _start;
    };
    case "D2C": {
        private _c = [0] call _centreAt; private _g = [_c] call _spawnDefenders;
        private _men = (units _g) select { _x != leader _g };
        { private _u = _men param [_forEachIndex, objNull]; if (!isNull _u && {isClass (configFile >> "CfgWeapons" >> _x)}) then { _u removeWeaponGlobal (secondaryWeapon _u); _u addWeaponGlobal _x; }; } forEach ["ace_csw_staticHMGCarry", "ace_csw_kordCarryTripod"];
        private _box = createVehicle ["Box_East_Ammo_F", _c getPos [15, _dir + 180], [], 0, "NONE"];
        clearMagazineCargoGlobal _box; _box setVariable ["OPORD_testObject", true, true];
        { if (isClass (configFile >> "CfgMagazines" >> _x)) then { _box addMagazineCargoGlobal [_x, 4]; }; } forEach ["ace_csw_100Rnd_127x99_mag", "ace_csw_100Rnd_127x108_mag"];
        [_g, _c, "DEFENCE", createHashMapFromArray [["quality", "HASTY"]], "D2c ACE CSW statics + ammo crate"] call _start;
        ["D2c needs ACE Crew Served Weapons 'Advanced Assembly' ON and 'Load default ammo' OFF in OPORD settings."] call _say;
    };
    case "D3": {
        private _defs = OPORD_testRuns select { !isNull (_x select 0) && {side (_x select 0) == east} };
        private _last = _defs param [count _defs - 1, []];
        if (_last isEqualTo []) exitWith { ["D3: no test position to attack. Run D1 first."] call _say; };
        _last params ["", "_label", "", "_centre", "_face"];
        private _from = _centre getPos [400, _face];
        private _cfg = configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad";
        private _a = [_from, west, _cfg] call BIS_fnc_spawnGroup;
        _a setVariable ["OPORD_testGroup", true, true];
        private _wp = _a addWaypoint [_centre, 0]; _wp setWaypointType "SAD"; _wp setWaypointBehaviour "AWARE";
        OPORD_testRuns pushBack [_a, "D3 attackers on " + _label, time, _centre, _face];
        [format ["D3: attackers (%1) advancing on %2 from 400 m.", groupId _a, _label]] call _say;
    };
    case "D8": {
        { private _c = [_x] call _centreAt; [[_c] call _spawnDefenders, _c, "DEFENCE", createHashMapFromArray [["quality", "DELIBERATE"], ["trench", true]], format ["D8 load position %1", _forEachIndex + 1]] call _start; } forEach [-225, -75, 75, 225];
        ["D8: watch server and HC FPS with #monitor for 10 minutes."] call _say;
    };
    case "STATUS": {
        if (OPORD_testRuns isEqualTo []) exitWith { ["No tests running."] call _say; };
        { _x params ["_g", "_label", "_t0"]; [format ["%1: %2, %3 s, %4 alive.", _label, _g getVariable ["OPORD_bpState", "-"], round (time - _t0), { alive _x } count units _g]] call _say; } forEach OPORD_testRuns;
    };
    case "CLEAR": {
        private _n = 0;
        { _x params ["_g", "", "", "_centre"]; { private _v = vehicle _x; if (_v != _x) then { deleteVehicle _v; }; deleteVehicle _x; _n = _n + 1; } forEach units _g; deleteGroup _g;
          { deleteVehicle _x; } forEach ((nearestObjects [_centre, [], 300]) select { _x getVariable ["OPORD_engineeringObject", false] || {_x getVariable ["OPORD_testObject", false]} || {_x isKindOf "StaticWeapon"} });
        } forEach OPORD_testRuns;
        OPORD_testRuns = [];
        [format ["Cleared %1 units and test earthworks. DCO fighting positions and dug terrain remain until the mission restarts.", _n]] call _say;
    };
    default { [format ["Unknown test '%1'.", _id]] call _say; };
};
