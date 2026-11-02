/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_buildTrenchLine: digs a trench (or anti-tank ditch) along a chain of points,
    progressively, using the method that suits the map's terrain grid (OPORD_fnc_trenchMethod):

      TERRAIN  real trench: TerrainLib lowers the line ~1.6 m (fine grids)
      HYBRID   TerrainLib lowers a shallow lane ~1.0 m, lined with chained GRAD trench segments
      OBJECTS  chained GRAD trench segments (or sandbag walls on both sides without GRAD)
      AT_DITCH (type) TerrainLib ditch ~2.5 m deep, 4 m wide, any grid; tank traps if available

    Arguments:
      0: Points ATL <ARRAY of positions> (2+)
      1: Side
      2: Options HashMap (optional): "type" "TRENCH"|"AT_DITCH", "method" "AUTO"|..., "depth" m,
         "timePer10m" s, "group" (builders: one free soldier works the active section; building
         pauses while the group is in combat), "id" STRING,
         Fighting positions along the trench (DCO stepping stones, unassigned):
         "fipoFacing" deg (absolute) or "fipoSide" "LEFT"|"RIGHT" (relative to the route),
         "dynamicStart" / "dynamicEnd" BOOL: dynamic positions at the ends facing outward
         (active only when an enemy is in their sector).
    Return: trench line id. Raises "OPORD_trenchLineDone" [id, method] when finished.
    Routes are stored in OPORD_trenchLines (id -> [points, method, side, type]) for OPORD movement.
*/
params ["_points", ["_side", east], ["_opt", createHashMap]];
if (count _points < 2) exitWith { "" };
private _grp = _opt getOrDefault ["group", grpNull];
if (!isNull _grp && {!local _grp}) exitWith { ["OPORD_buildTrench", _this, leader _grp] call CBA_fnc_targetEvent; "" };

if (isNil "OPORD_trenchCounter") then { OPORD_trenchCounter = 0; };
OPORD_trenchCounter = OPORD_trenchCounter + 1;
private _id = _opt getOrDefault ["id", format ["TL_%1_%2", clientOwner, OPORD_trenchCounter]];
[_points, _side, _opt, _id] spawn {
    params ["_points", "_side", "_opt", "_id"];
    private _type = toUpperANSI (_opt getOrDefault ["type", "TRENCH"]);
    private _grp = _opt getOrDefault ["group", grpNull];
    ([] call OPORD_fnc_trenchMethod) params ["_auto", "_cell"];
    private _method = toUpperANSI (_opt getOrDefault ["method", "AUTO"]);
    if (_method == "AUTO") then { _method = _auto; };
    if (_type == "AT_DITCH") then { _method = ["OBJECTS", "AT_DITCH"] select !isNil "TerrainLib_fnc_setTerrainHeight"; };
    private _terrain = _method in ["TERRAIN", "HYBRID", "AT_DITCH"];
    private _objects = _method in ["HYBRID", "OBJECTS"];
    private _depth = _opt getOrDefault ["depth", switch (_method) do {
        case "TERRAIN": { missionNamespace getVariable ["OPORD_trenchDepth", 1.6] };
        case "HYBRID": { 1.0 };
        case "AT_DITCH": { 2.5 };
        default { 0 };
    }];
    private _width = [1.5, 4] select (_method == "AT_DITCH");
    private _per10 = _opt getOrDefault ["timePer10m", missionNamespace getVariable ["OPORD_trenchTimePer10m", 60]];
    private _grad = isClass (configFile >> "CfgVehicles" >> "GRAD_envelope_long") && {!isNil "grad_trenches_functions_fnc_setTrenchProgress"};
    private _segCls = ["Land_BagFence_Long_F", "GRAD_envelope_long"] select _grad;
    ([_segCls] call OPORD_fnc_segmentLength) params ["_segLen", "_segLongX"];
    _segLen = _segLen max 1.5;
    private _shortLen = if (_grad) then { (["GRAD_envelope_short"] call OPORD_fnc_segmentLength) select 0 } else { 1.5 };
    private _rotFlip = (missionNamespace getVariable ["OPORD_trenchRotationOffset", 180]) == 180;
    private _trap = ["Land_CzechHedgehog_01_new_F", "Land_CzechHedgehog_01_old_F", "Land_CzechHedgehog_01_F"] select { isClass (configFile >> "CfgVehicles" >> _x) } param [0, ""];

    [format ["Trench line %1: %2 (terrain cell %3 m), %4 points.", _id, _method, _cell, count _points]] call OPORD_fnc_log;
    if (isNil "OPORD_trenchLines") then { OPORD_trenchLines = createHashMap; };
    OPORD_trenchLines set [_id, [_points, _method, _side, _type]];
    publicVariable "OPORD_trenchLines";

    if (missionNamespace getVariable ["OPORD_debug", false]) then {
        private _m = createMarker [format ["OPORD_%1", _id], _points select 0];
        _m setMarkerShapeLocal "POLYLINE";
        _m setMarkerColorLocal (["ColorKhaki", "ColorRed"] select (_type == "AT_DITCH"));
        private _poly = [];
        { _poly append [_x select 0, _x select 1]; } forEach _points;
        _m setMarkerPolyline _poly;
    };

    private _lastAnim = -99;
    private _fFacing = _opt getOrDefault ["fipoFacing", -1];
    private _fSide = toUpperANSI (_opt getOrDefault ["fipoSide", ""]);
    private _chain = _type == "TRENCH" && {_fFacing >= 0 || {_fSide in ["LEFT", "RIGHT"]}};
    private _spacing = missionNamespace getVariable ["OPORD_trenchFipoSpacing", 6];
    // Stances by lane depth: deep terrain trench -> stand to fire; hybrid lane + parapet ->
    // stand-low; parapet on flat ground -> crouch over it.
    private _st = switch (_method) do { case "TERRAIN": { [3, 7] }; case "HYBRID": { [3, 7] }; default { [1, 5] }; };
    private _reserved = _opt getOrDefault ["reserved", []]; // soldiers' own spots: no stepping stones there
    private _acc = 0;
    private _fnc_face = {
        params ["_segDir"];
        if (_fFacing >= 0) exitWith { _fFacing };
        [_segDir + 90, _segDir - 90] select (_fSide == "LEFT")
    };
    for "_i" from 0 to ((count _points) - 2) do {
        private _a = _points select _i;
        private _b = _points select (_i + 1);
        private _segDir = _a getDir _b;
        private _total = _a distance2D _b;
        private _subN = ceil (_total / 8) max 1;
        // Plan the parapet over the WHOLE segment (long pieces end to end, short pieces filling
        // the remainder), then raise the pieces stretch by stretch as it's dug. Planning per 8 m
        // stretch meant a long piece never fitted, leaving gaps.
        private _segPieces = []; // [class, length, start offset]
        if (_objects && {_grad}) then {
            private _gap = 0.2;
            private _at = 0;
            while { _at + _segLen <= _total } do { _segPieces pushBack ["GRAD_envelope_long", _segLen, _at]; _at = _at + _segLen + _gap; };
            while { (_total - _at) >= (_shortLen * 0.7) } do { _segPieces pushBack ["GRAD_envelope_short", _shortLen, _at]; _at = _at + _shortLen + _gap; };
        };
        // A position at every bend, so straight-line hops don't cut corners over open ground.
        if (_chain && {_i > 0}) then { [_a, [_segDir] call _fnc_face, _side, false, _id, _st, _reserved] call OPORD_fnc_trenchFipo; };
        for "_s" from 0 to (_subN - 1) do {
            private _p1 = _a getPos [_total * _s / _subN, _segDir];
            private _p2 = _a getPos [_total * (_s + 1) / _subN, _segDir];
            private _subLen = _p1 distance2D _p2;

            // Lining objects for this stretch, created sunk (dug up with the passes).
            // Parapet along the enemy side of the route; soldiers and stepping-stone positions
            // use the lane behind it (lowered terrain on TERRAIN / HYBRID). Pieces never go on
            // the route itself, and long + short pieces are fitted without overlap.
            private _lining = [];
            if (_objects) then {
                private _faceDir = [_segDir] call _fnc_face;
                private _bermLeft = if (_chain) then { ((_faceDir - _segDir + 720) mod 360) > 180 } else { true };
                private _lat = [_segDir + 90, _segDir - 90] select _bermLeft;
                private _frontLeft = [_bermLeft, !_bermLeft] select _rotFlip;
                if (_grad) then {
                    private _sStart = _total * _s / _subN;
                    private _sEnd = _total * (_s + 1) / _subN;
                    {
                        _x params ["_cls", "_len", "_start"];
                        private _mid = _start + _len / 2;
                        if (_mid < _sStart || {_mid >= _sEnd && {_s < _subN - 1}}) then { continue };
                        private _off = (([_cls] call OPORD_fnc_segmentLength) select 2) / 2 + 0.6;
                        private _s1 = (_a getPos [_start, _segDir]) getPos [_off, _lat];
                        private _s2 = (_a getPos [_start + _len, _segDir]) getPos [_off, _lat];
                        private _c = (_a getPos [_mid, _segDir]) getPos [_off, _lat];
                        _s1 set [2, 0]; _s2 set [2, 0]; _c set [2, 0];
                        if !([_c, _len * 0.4] call OPORD_fnc_earthworkClear) then { continue };
                        private _o = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
                        private _tex = surfaceTexture _c;
                        if ((toLowerANSI _tex) find "_co.paa" >= 0) then { _o setObjectTextureGlobal [0, _tex]; };
                        _o setPosATL _c;
                        [_o, _s1, _s2, (([_cls] call OPORD_fnc_segmentLength) select 1), _frontLeft] call OPORD_fnc_orientAlong;
                        [_o, 0] call grad_trenches_functions_fnc_setTrenchProgress;
                        _o setVariable ["OPORD_engineeringObject", true, true];
                        _lining pushBack _o;
                    } forEach _segPieces;
                } else {
                    private _n = floor (_subLen / 3) max 1;
                    for "_k" from 0 to (_n - 1) do {
                        private _c = (_p1 getPos [(_k + 0.5) * (_subLen / _n), _segDir]) getPos [1.1, _lat];
                        if ([_c, 1.2] call OPORD_fnc_earthworkClear) then {
                            _lining append ([_c, _segDir, "LONG"] call OPORD_fnc_placeSandbags);
                        };
                    };
                };
            };

            private _passes = 4;
            private _dt = ((_per10 * _subLen / 10) / _passes) max 0.5;
            for "_p" from 1 to _passes do {
                // Builders under fire: wait (distant awareness of an enemy doesn't stop work).
                private _paused = false;
                waitUntil {
                    sleep 2;
                    if (isNull _grp || {({ alive _x } count units _grp) == 0}) exitWith { true };
                    ([_grp] call OPORD_fnc_groupUnderFire) params ["_uf", "_why"];
                    if (_uf && {!_paused}) then { _paused = true; [format ["Trench line %1 paused: %2.", _id, _why]] call OPORD_fnc_log; };
                    if (!_uf && {_paused}) then { [format ["Trench line %1 resumed.", _id]] call OPORD_fnc_log; };
                    !_uf
                };
                // Cosmetic: one free builder works this stretch.
                if (!isNull _grp && {time - _lastAnim > 6}) then {
                    private _free = (units _grp) select { [_x] call OPORD_fnc_unitFree && {isNull objectParent _x} };
                    if (_free isNotEqualTo []) then {
                        private _w = ([_free, [], { _x distance2D _p1 }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                        // Work from beside the trench (rear side), not on top of it.
                        private _rearSide = if (_chain) then { ([_segDir] call _fnc_face) + 180 } else { _segDir - 90 };
                        private _ws = _p1 getPos [4, _rearSide];
                        if ((_w distance2D _ws) > 3) then { _w doMove _ws; } else { _w doWatch _p1; _w playMoveNow "AinvPknlMstpSnonWnonDnon_medic4"; };
                        _lastAnim = time;
                    };
                };
                sleep _dt;
                private _prog = _p / _passes;
                if (_terrain && {_depth > 0}) then { [_p1, _p2, _width, _depth, _prog] call OPORD_fnc_terrainDigSegment; };
                if (_grad) then { { [_x, _prog] call OPORD_fnc_setTrenchProgress; } forEach _lining; };
            };
            // Stretch fully dug: stepping-stone fighting positions along it.
            if (_chain) then {
                private _d = _spacing - _acc;
                while { _d <= _subLen } do {
                    [_p1 getPos [_d, _segDir], [_segDir] call _fnc_face, _side, false, _id, _st, _reserved] call OPORD_fnc_trenchFipo;
                    _d = _d + _spacing;
                };
                _acc = _subLen - (_d - _spacing);
            };
            if (_type == "AT_DITCH" && {_trap != ""}) then {
                private _t = createVehicle [_trap, _p1 getPos [_width, _segDir - 90], [], 0, "CAN_COLLIDE"];
                _t setVariable ["OPORD_engineeringObject", true, true];
            };
        };
    };
    // Dynamic positions at the ends, facing outward (flanks / rear): DCO activates them only
    // when an enemy appears in their sector.
    if (_type == "TRENCH") then {
        private _n = count _points;
        if (_opt getOrDefault ["dynamicStart", false]) then {
            [_points select 0, (_points select 1) getDir (_points select 0), _side, true, _id + "_dyn", _st, _reserved] call OPORD_fnc_trenchFipo;
        };
        if (_opt getOrDefault ["dynamicEnd", false]) then {
            [_points select (_n - 1), (_points select (_n - 2)) getDir (_points select (_n - 1)), _side, true, _id + "_dyn", _st, _reserved] call OPORD_fnc_trenchFipo;
        };
    };
    [format ["Trench line %1 finished (%2, %3 fighting positions).", _id, _method, missionNamespace getVariable ["OPORD_tfCount_" + _id, 0]]] call OPORD_fnc_log;
    missionNamespace setVariable ["OPORD_tlDone_" + _id, true];
    ["OPORD_trenchLineDone", [_id, _method]] call CBA_fnc_globalEvent;
};
_id
