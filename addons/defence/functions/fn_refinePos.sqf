/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_refinePos: picks the best spot within a few metres of a planned position.
    Scores line of sight to the target area (from eye height, over terrain), avoids water,
    steep slopes and building footprints, and prefers slightly higher ground.

    Arguments: 0: Position ATL, 1: Target position ATL, 2: Search radius m (default 6)
    Return: refined position ATL
*/
params ["_pos", "_target", ["_r", 6]];
private _tgtASL = AGLToASL _target vectorAdd [0, 0, 1.5];
private _best = _pos;
private _bestScore = -1e9;
private _cands = [_pos];
for "_a" from 0 to 315 step 45 do { _cands pushBack (_pos getPos [_r, _a]); _cands pushBack (_pos getPos [_r / 2, _a + 22]); };
{
    private _p = +_x; _p set [2, 0];
    if (surfaceIsWater _p) then { continue };
    private _eye = AGLToASL _p vectorAdd [0, 0, 1.6];
    private _score = 0;
    if !(terrainIntersectASL [_eye, _tgtASL]) then { _score = _score + 100; };
    private _n = surfaceNormal _p;
    _score = _score - ((1 - (_n select 2)) * 300);               // slope penalty
    _score = _score + ((getTerrainHeightASL _p) - (getTerrainHeightASL _pos)) * 4; // slight high-ground bias
    if ((nearestTerrainObjects [_p, ["HOUSE", "BUILDING", "WALL", "ROCK", "ROCKS"], 3, false, true]) isNotEqualTo []) then { _score = _score - 200; };
    if (_score > _bestScore) then { _bestScore = _score; _best = _p; };
} forEach _cands;
_best
