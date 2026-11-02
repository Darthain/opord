/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_groupUnderFire: [group] -> [underFire <BOOL>, reason <STRING>]
    Engineering pauses only when the group is genuinely threatened, not merely aware of a distant
    enemy (Arma flips a group to COMBAT for any known enemy, which used to stop digging entirely):
      - a soldier is suppressed (getSuppression > 0.25)
      - DCO reported a soldier pinned down in the last 20 s
      - a known enemy within "Dig safety radius" (setting, default 150 m) of the leader
*/
params ["_group"];
if (isNull _group) exitWith { [false, ""] };
private _units = (units _group) select { alive _x };
if (_units isEqualTo []) exitWith { [false, ""] };
if ((_units findIf { getSuppression _x > 0.25 }) >= 0) exitWith { [true, "suppressed"] };
if (((_group getVariable ["OPORD_pinnedTimes", []]) findIf { time - _x < 20 }) >= 0) exitWith { [true, "pinned down"] };
private _r = missionNamespace getVariable ["OPORD_digSafeRadius", 150];
private _near = (leader _group) targets [true, _r, [], 30];
if (_near isNotEqualTo []) exitWith { [true, format ["enemy within %1 m", round _r]] };
[false, ""]
