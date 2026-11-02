/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_segmentLength: [class] -> [long side (m), longAxisIsX <BOOL>, short side (m)]
    Measured from the model's bounding box (cached), so earthworks are rotated, chained and
    spaced by their real footprint, whatever axis the model was built along.
*/
params ["_cls"];
if (isNil "OPORD_segLenCache") then { OPORD_segLenCache = createHashMap; };
private _c = OPORD_segLenCache get _cls;
if (!isNil "_c") exitWith { _c };
private _o = createVehicleLocal [_cls, [0, 0, 1000], [], 0, "CAN_COLLIDE"];
private _bb = boundingBoxReal _o;
deleteVehicle _o;
private _dx = ((_bb select 1) select 0) - ((_bb select 0) select 0);
private _dy = ((_bb select 1) select 1) - ((_bb select 0) select 1);
private _res = [(_dx max _dy) max 1, _dx >= _dy, (_dx min _dy) max 0.5];
OPORD_segLenCache set [_cls, _res];
_res
