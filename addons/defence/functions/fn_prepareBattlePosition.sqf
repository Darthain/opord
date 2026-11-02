/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_prepareBattlePosition: a group prepares and occupies a battle position.

    Sequence (control contract: OPORD only orders soldiers DCO reports as free):
      1. Plan: fighting-position pairs along the principal direction of fire (DEFENCE arc or
         SBF line), static-weapon slots (direct fire on the line, mortars to the rear).
      2. Static weapons: crews fetch kits (worn backpacks, or bags from nearby vehicles/crates),
         carry them to their slots, assemble and man them. Empty statics nearby get a crew.
      3. Dig: GRAD trenches rise while the pair digs (pauses whenever DCO has a digger busy).
      4. Conceal: POOK nets; GRAD terrain camouflage for DELIBERATE positions.
      5. Occupy: one DCO fighting position per soldier, facing the threat -> DCO takes over.

    Arguments:
      0: Group, 1: Centre ATL, 2: Facing deg (principal direction of fire),
      3: "DEFENCE" | "SBF",
      4: Options HashMap (all optional): "dig" BOOL, "quality" "HASTY"|"DELIBERATE",
         "camo" BOOL, "statics" BOOL, "radius" m, "frontage" m, "sectorDistance" m
    Runs where the group is local (forwards itself there otherwise).
    Raises "OPORD_battlePositionReady" [group, type, state] (global) when finished.
*/
params ["_group", "_centre", "_dir", ["_type", "DEFENCE"], ["_opt", createHashMap]];
if (isNull _group || {(units _group) isEqualTo []}) exitWith {};
if (!local _group) exitWith { ["OPORD_prepareBP", _this, leader _group] call CBA_fnc_targetEvent; };
if ((_group getVariable ["OPORD_bpState", ""]) == "BUILDING") exitWith {};
_group setVariable ["OPORD_bpState", "BUILDING", true];

_this spawn {
    params ["_group", "_centre", "_dir", "_type", "_opt"];
    private _sbf = (toUpperANSI _type) == "SBF";
    private _dig = _opt getOrDefault ["dig", !_sbf];
    private _quality = toUpperANSI (_opt getOrDefault ["quality", ["DELIBERATE", "HASTY"] select _sbf]);
    private _camo = _opt getOrDefault ["camo", true];
    private _useStatics = _opt getOrDefault ["statics", true];
    private _radius = _opt getOrDefault ["radius", missionNamespace getVariable ["OPORD_staticRadius", 75]];
    private _frontage = _opt getOrDefault ["frontage", [60, 80] select _sbf];
    private _sector = _opt getOrDefault ["sectorDistance", [300, 600] select _sbf];
    private _connect = _opt getOrDefault ["trench", !_sbf && {_quality == "DELIBERATE"}];
    private _bags = missionNamespace getVariable ["OPORD_sandbags", 2]; // 0 off, 1 statics, 2 statics + undug positions
    private _side = side _group;
    private _deadline = time + (missionNamespace getVariable ["OPORD_bpTimeout", 600]);
    private _digTime = ([120, 45] select (_quality == "HASTY")) * (missionNamespace getVariable ["OPORD_buildTimeScale", 1]);
    private _right = _dir + 90;

    [_group] call OPORD_fnc_lockPosture;
    _group setBehaviour "AWARE";
    _group setCombatMode "YELLOW";
    _group setFormDir _dir;
    {
        if (!isNull objectParent _x && {!((vehicle _x) isKindOf "StaticWeapon")}) then {
            [_x] orderGetIn false; unassignVehicle _x; doGetOut _x;
        };
    } forEach units _group;

    private _units = (units _group) select { alive _x };
    private _leader = leader _group;

    // ---- Static kits and crews ----
    private _kits = if (_useStatics) then { [_group, _centre, _radius] call OPORD_fnc_findStaticKits } else { [] };
    _kits = (_kits select { !((_x select 0) isKindOf "StaticMortar") }) + (_kits select { (_x select 0) isKindOf "StaticMortar" });
    private _maxStatics = floor ((count _units) / 2);
    if (count _kits > _maxStatics) then { _kits resize _maxStatics; };

    private _free = +_units;
    private _crews = [];
    {
        _x params ["_to", "_wBag", "_wSrc", "_bBag", "_bSrc", "_kind"];
        private _g = objNull;
        if (_wSrc in _free) then { _g = _wSrc; } else {
            private _cands = _free select { _x != _leader };
            if (_cands isEqualTo []) then { _cands = +_free; };
            private _ref = _wSrc;
            _cands = [_cands, [], { _x distance _ref }, "ASCEND"] call BIS_fnc_sortBy;
            _g = _cands param [0, objNull];
        };
        _free = _free - [_g];
        _crews pushBack _g;
    } forEach _kits;

    // ---- Layout ----
    private _nPos = if (_free isEqualTo []) then { 0 } else { ceil ((count _free) / 2) };
    private _layout = [_centre, _dir, _type, _frontage, _nPos max 1, _kits, _sector] call OPORD_fnc_planLayout;
    private _positions = _layout get "positions";
    private _slots = _layout get "statics";
    if (_nPos == 0) then { _positions = []; };
    [_group, _centre, _dir, _positions, _slots] call OPORD_fnc_debugMarkers;

    // Fill positions centre-out; leader first.
    private _order = [];
    { _order pushBack _forEachIndex; } forEach _positions;
    _order = [_order, [], { (_positions select _x select 0) distance2D _centre }, "ASCEND"] call BIS_fnc_sortBy;
    _free = ([_leader] arrayIntersect _free) + (_free - [_leader]);
    private _posMembers = _positions apply { [] };
    { (_posMembers select (_order select (floor (_forEachIndex / 2)))) pushBack _x; } forEach _free;

    // ---- Ammo bearers (ACE CSW) ----
    // Each static's crew draws matching CSW ammo from the kit's own vehicle / crate, or the nearest
    // container that has some; tripod carriers drop any matching ammo they carry at the slot.
    private _ammoMax = missionNamespace getVariable ["OPORD_staticAmmoCount", 4];
    private _ammoSrc = [];
    {
        private _slotPos = if ((_x select 5) == "static") then { getPosATL (_x select 2) } else { (_slots select _forEachIndex) select 0 };
        _ammoSrc pushBack ([_x, _centre, _radius, _slotPos] call OPORD_fnc_findAmmoSource);
    } forEach _kits;
    private _kitAmmo = _kits apply { [] };
    private _slotCache = _kits apply { objNull };

    // ---- Tasks ----
    // Unit task: [unit, stage, target, kitIndex, lastOrder]
    private _tasks = [];
    {
        private _kit = _kits select _forEachIndex;
        private _slot = _slots select _forEachIndex;
        private _slotPos = if ((_kit select 5) == "static") then { getPosATL (_kit select 2) } else { _slot select 0 };
        private _src = _kit select 2;
        private _fetch = ((_kit select 5) in ["bag", "csw"]) && {!(_src isKindOf "CAManBase")};
        if (!isNull _x) then {
            private _aSrc = _ammoSrc select _forEachIndex;
            private _stage = switch (true) do {
                case _fetch: { "fetch" };
                case (!isNull _aSrc): { "ammo" };
                default { "toSlot" };
            };
            private _tgt = switch (_stage) do {
                case "fetch": { getPosATL _src };
                case "ammo": { getPosATL _aSrc };
                default { _slotPos };
            };
            _tasks pushBack [_x, _stage, _tgt, _forEachIndex, -99];
        };
    } forEach _crews;
    private _deliver = []; // tripod carriers walking their base to a slot first: [unit, kitIndex]
    {
        private _bSrc = _x select 4;
        if (!isNull _bSrc && {_bSrc isKindOf "CAManBase"} && {_bSrc != (_crews select _forEachIndex)}) then {
            _deliver pushBack [_bSrc, _forEachIndex];
        };
    } forEach _kits;
    {
        private _pIdx = _forEachIndex;
        private _members = _x;
        private _pPos = (_positions select _pIdx) select 0;
        {
            private _lat = if (count _members > 1) then { [-0.9, 0.9] select (_forEachIndex mod 2) } else { 0 };
            private _spot = _pPos getPos [abs _lat, [_right - 180, _right] select (_lat >= 0)];
            private _u = _x;
            private _dIdx = _deliver findIf { (_x select 0) == _u };
            // The parapet rises IN FRONT of the spot (like a player placing a trench); the digger
            // works just behind his own spot, never inside the model.
            private _digSpot = _spot getPos [0.8, ((_positions select _pIdx) select 1) + 180];
            if (_dIdx >= 0) then {
                private _k = (_deliver select _dIdx) select 1;
                _tasks pushBack [_u, "deliver", (_slots select _k) select 0, _k, -99, _pIdx, _spot, _digSpot];
            } else {
                _tasks pushBack [_u, "toPos", [_spot, _digSpot] select _dig, -1, -99, _pIdx, _spot, _digSpot];
            };
        } forEach _members;
    } forEach _posMembers;

    // ---- Unified fire trench ----
    // With connected trenches, the pairs don't dig separate parapets: the group digs ONE fire
    // trench along the position line (extended 3 m past each end), parapet in front, and every
    // soldier fights from its lane. No second line behind them, no overlaps.
    private _unified = _connect && {_dig} && {count _positions >= 2};
    private _fireId = format ["%1_fire", groupId _group];
    private _laneSt = switch (([] call OPORD_fnc_trenchMethod) select 0) do { case "TERRAIN"; case "HYBRID": { [3, 7] }; default { [1, 5] }; };
    if (_unified) then {
        missionNamespace setVariable ["OPORD_tlDone_" + _fireId, false];
        private _rv = [sin _right, cos _right, 0];
        private _byLat = [_positions, [_centre, _rv], { ((_x select 0) vectorDiff (_input0)) vectorDotProduct _input1 }, "ASCEND"] call BIS_fnc_sortBy;
        private _route = _byLat apply { +(_x select 0) };
        private _first = _route select 0; private _last = _route select -1;
        _route = [_first getPos [3, _last getDir _first]] + _route + [_last getPos [3, _first getDir _last]];
        private _reserved = (_tasks select { count _x > 6 }) apply { _x select 6 };
        [_route, _side, createHashMapFromArray [["group", _group], ["id", _fireId], ["fipoFacing", _dir],
            ["dynamicStart", true], ["dynamicEnd", true], ["reserved", _reserved]]] call OPORD_fnc_buildTrenchLine;
    };

    // Position state: [trench, isGrad, progress, done]
    private _posState = _positions apply { [objNull, false, 0, false] };
    private _assembled = _kits apply { objNull };
    private _lastAnim = createHashMap;

    private _fnc_order = {
        params ["_t"];
        _t params ["_u", "_stage", "_target", "", "_last"];
        if ((_u distance2D _target) > 3 && {time - _last > 10 || {speed _u < 0.5 && {time - _last > 4}}}) then {
            _u doMove _target;
            _t set [4, time];
        };
    };

    // ---- Main loop ----
    while { time < _deadline && {({ alive _x } count (units _group)) > 0} } do {
        sleep 2;
        {
            private _t = _x;
            _t params ["_u", "_stage", "_target", "_k"];
            if (!alive _u || {_stage == "done"}) then { continue };
            if !([_u] call OPORD_fnc_unitFree) then { continue };
            private _near = (_u distance2D _target) <= 3;
            switch (_stage) do {
                case "fetch": {
                    private _kSrc = _kits select _k select 2;
                    if ((_u distance2D _kSrc) <= 5) then {
                        private _aSrc = _ammoSrc select _k;
                        if (_aSrc isEqualTo _kSrc) then {
                            (_kitAmmo select _k) append ([_aSrc, [_kits select _k select 0] call OPORD_fnc_staticAmmoClasses, _ammoMax] call OPORD_fnc_takeStaticAmmo);
                        };
                        if (!isNull _aSrc && {_aSrc isNotEqualTo _kSrc}) then {
                            _t set [1, "ammo"]; _t set [2, getPosATL _aSrc];
                        } else {
                            _t set [1, "toSlot"]; _t set [2, (_slots select _k) select 0];
                        };
                        _t set [4, -99];
                    } else { [_t] call _fnc_order; };
                };
                case "ammo": {
                    private _aSrc = _ammoSrc select _k;
                    if (isNull _aSrc || {(_u distance2D _aSrc) <= 5}) then {
                        (_kitAmmo select _k) append ([_aSrc, [_kits select _k select 0] call OPORD_fnc_staticAmmoClasses, _ammoMax] call OPORD_fnc_takeStaticAmmo);
                        private _slotPos = if ((_kits select _k select 5) == "static") then { getPosATL (_kits select _k select 2) } else { (_slots select _k) select 0 };
                        _t set [1, "toSlot"]; _t set [2, _slotPos]; _t set [4, -99];
                    } else { [_t] call _fnc_order; };
                };
                case "toSlot": {
                    if (_near) then {
                        private _kit = _kits select _k;
                        private _bSrc = _kit select 4;
                        private _baseReady = isNull _bSrc || {!(_bSrc isKindOf "CAManBase")} || {!alive _bSrc}
                            || {(_bSrc distance2D _target) < 10} || {_bSrc == _u};
                        if (_baseReady || {time > (_t param [7, time + 90])}) then {
                            private _s = [_kit, _target, (_slots select _k) select 1, _u, _kitAmmo select _k, _slotCache select _k] call OPORD_fnc_assembleStatic;
                            _assembled set [_k, _s];
                            if (_bags >= 1) then {
                                private _isMortar = (_kit select 0) isKindOf "StaticMortar";
                                [getPosATL _s, (_slots select _k) select 1, ["ROUND", "RING"] select _isMortar] call OPORD_fnc_placeSandbags;
                            };
                            if (_camo && {!((_kit select 0) isKindOf "StaticMortar")}) then {
                                [_target getPos [1.5, (_slots select _k select 1) + 180], (_slots select _k) select 1, _side, "SMALL"] call OPORD_fnc_conceal;
                            };
                            _t set [1, "done"];
                        } else {
                            if (count _t < 8) then { _t set [7, time + 90]; };
                        };
                    } else { [_t] call _fnc_order; };
                };
                case "deliver": {
                    if (_near || {!isNull (_assembled select _k)}) then {
                        // Tripod carrier: leave any matching CSW ammo he carries at the weapon.
                        private _acc = [_kits select _k select 0] call OPORD_fnc_staticAmmoClasses;
                        private _mine = (magazines _u) select { _x in _acc };
                        if (count _mine > _ammoMax) then { _mine resize _ammoMax; };
                        if (_mine isNotEqualTo []) then {
                            { _u removeMagazineGlobal _x; } forEach _mine;
                            private _s = _assembled select _k;
                            private _cache = if (isNull _s) then { _slotCache select _k } else { _s getVariable ["OPORD_ammoCache", objNull] };
                            _cache = [[_target, getPosATL _s] select (!isNull _s), _mine, _cache] call OPORD_fnc_dropStaticAmmo;
                            if (isNull _s) then { _slotCache set [_k, _cache]; } else {
                                _s setVariable ["OPORD_ammoCache", _cache, true];
                                // Already manned but empty: ACE only reloads on get-in / out-of-ammo, so prompt it.
                                if (!someAmmo _s && {alive gunner _s} && {!isNil "ace_csw_fnc_ai_reload"}) then {
                                    [_s, gunner _s, currentWeapon _s] call ace_csw_fnc_ai_reload;
                                };
                            };
                        };
                        _t set [1, "toPos"]; _t set [2, [_t select 6, _t select 7] select _dig]; _t set [4, -99];
                    } else { [_t] call _fnc_order; };
                };
                case "toPos": {
                    if (_near) then {
                        doStop _u;
                        _u doWatch (_t select 6);
                        _t set [1, ["ready", "dig"] select _dig];
                    } else { [_t] call _fnc_order; };
                };
                case "dig": {
                    if ((time - (_lastAnim getOrDefault [netId _u, -99])) > 6 && {speed _u < 0.5}) then {
                        _u playMoveNow "AinvPknlMstpSnonWnonDnon_medic4";
                        _lastAnim set [netId _u, time];
                    };
                };
            };
        } forEach _tasks;

        // Positions: dig, conceal, occupy.
        {
            private _pIdx = _forEachIndex;
            private _st = _posState select _pIdx;
            if (_st select 3) then { continue };
            private _members = _tasks select { ((_x param [5, -1]) isEqualTo _pIdx) && {alive (_x select 0)} };
            if (_members isEqualTo []) then { _st set [3, true]; continue };
            if (_members findIf { !((_x select 1) in ["dig", "ready"]) } >= 0) then { continue };
            (_positions select _pIdx) params ["_pPos", "_pDir"];

            if (_unified) then {
                if !(missionNamespace getVariable ["OPORD_tlDone_" + _fireId, false]) then { continue };
            };
            if (_dig && {!_unified}) then {
                if (isNull (_st select 0)) then {
                    ([_pPos, _pDir, count _members, _side] call OPORD_fnc_createTrench) params ["_obj", "_isGrad"];
                    _st set [0, _obj]; _st set [1, _isGrad];
                    if (!_isGrad) then { _st set [2, 1]; };
                };
                private _diggers = if (([_group] call OPORD_fnc_groupUnderFire) select 0) then { 0 } else { { [_x select 0] call OPORD_fnc_unitFree } count _members };
                if (_diggers > 0 && {(_st select 2) < 1}) then {
                    _st set [2, ((_st select 2) + (2 / _digTime) * (_diggers / 2 max 0.5)) min 1];
                    if (_st select 1) then { [_st select 0, _st select 2] call OPORD_fnc_setTrenchProgress; };
                };
                if ((_st select 2) < 1) then { continue };
            };

            // Complete: parapet for undug positions, conceal, hand over to DCO.
            if (!_dig && {_bags >= 2}) then { [_pPos, _pDir, "SHORT"] call OPORD_fnc_placeSandbags; };
            if (_camo) then {
                [_pPos, _pDir, _side, ["SMALL", "MEDIUM"] select (count _members > 2), _st select 0, _quality == "DELIBERATE" && {_st select 1}] call OPORD_fnc_conceal;
            };
            // Behind a parapet (GRAD or sandbags): prone in cover, crouched to fire over it.
            // No parapet: prone in cover, prone-high to fire.
            private _profile = switch (true) do {
                case (_unified): { createHashMapFromArray [["coverStance", _laneSt select 0], ["shootingStance", _laneSt select 1]] };
                case (_dig || {_bags >= 2}): { createHashMapFromArray [["coverStance", 1], ["shootingStance", 5]] };
                default { createHashMapFromArray [["coverStance", 1], ["shootingStance", 2]] };
            };
            _profile set ["sectorDistance", _sector];
            _profile set ["sectorWidth", [0.5, 0.3] select _sbf];
            {
                _x params ["_u"];
                private _spot = _x select 6;
                // Step into the finished position (avoids AI pathing over the parapet).
                if (missionNamespace getVariable ["OPORD_snapIntoPosition", true] && {[_u] call OPORD_fnc_unitFree}) then {
                    _u doWatch objNull;
                    _spot = [_u, _spot, _pDir] call OPORD_fnc_safeSnap;
                };
                private _f = [_spot, _pDir, _side, _u, _profile] call OPORD_fnc_createFipo;
                if (isNull _f) then { _u doWatch (_spot getPos [100, _pDir]); _u setUnitPos "MIDDLE"; };
                _x set [1, "done"];
            } forEach _members;
            _st set [3, true];
        } forEach _positions;

        private _pending = (_tasks findIf { alive (_x select 0) && {(_x select 1) != "done"} }) >= 0;
        if (!_pending) exitWith {};
    };

    private _state = ["READY", "PARTIAL"] select ((_tasks findIf { alive (_x select 0) && {(_x select 1) != "done"} }) >= 0);
    _group setVariable ["OPORD_bpState", _state, true];
    _group setVariable ["OPORD_bpStatics", _assembled select { !isNull _x }, true];
    [format ["%1 battle position %2 (%3 positions, %4 statics)", _type, _state, count _positions, count (_assembled select { !isNull _x })]] call OPORD_fnc_log;
    ["OPORD_battlePositionReady", [_group, _type, _state]] call CBA_fnc_globalEvent;

    // Improve the position: a fire trench linking the positions (behind them) and a
    // communication trench to the rear. Dug progressively; pauses while the group is in combat.
    if (_connect && {count _positions >= 2}) then {
        // Order positions left to right (lateral offset along the line).
        private _rv = [sin _right, cos _right, 0];
        private _byLat = [_positions, [_centre, _rv], { ((_x select 0) vectorDiff (_input0)) vectorDotProduct _input1 }, "ASCEND"] call BIS_fnc_sortBy;
        // Keep the fire trench clear of the fighting positions: >= 6 m or 2 terrain cells behind,
        // so lowering its lane doesn't move the ground under them.
        private _back = 6 max ((getTerrainInfo select 2) * 2);
        private _fire = _byLat apply { (_x select 0) getPos [_back, _dir + 180] };
        private _rearStart = _centre getPos [_back, _dir + 180];
        private _comm = [_rearStart, _centre getPos [45, _dir + 180]];
        private _o1 = createHashMapFromArray [["group", _group], ["id", format ["%1_fire", groupId _group]],
            ["fipoFacing", _dir], ["dynamicStart", true], ["dynamicEnd", true]];     // alternates + flank positions
        private _o2 = createHashMapFromArray [["group", _group], ["id", format ["%1_comm", groupId _group]],
            ["fipoFacing", _dir], ["dynamicEnd", true]];                             // movement + rear position
        // Unified mode already dug the fire trench through the positions: only the communication
        // trench remains, starting from the middle of the line.
        if (!_unified) then { [_fire, _side, _o1] call OPORD_fnc_buildTrenchLine; }
        else { _comm set [0, _centre getPos [1.5, _dir + 180]]; };
        [_comm, _side, _o2] call OPORD_fnc_buildTrenchLine;
    };
};
