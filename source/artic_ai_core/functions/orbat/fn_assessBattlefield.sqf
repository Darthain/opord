/*
    Assess the friendly force committed to a battlefield against the currently
    known hostile force. This is deliberately an estimate, not omniscient truth.
*/
params [
    ["_commander",createHashMap,[createHashMap]],
    ["_groups",[],[[]]],
    ["_battlefield",createHashMap,[createHashMap]]
];
private _friendlyStrength = 0;
private _mg = 0; private _gl = 0; private _at = 0; private _aa = 0; private _med = 0; private _eng = 0;
private _veh = 0; private _recon = 0; private _fpvAP = 0; private _fpvAT = 0;
private _roles = [];
{
    private _c = [_x] call ARTIC_fnc_scanGroupCapabilities;
    _friendlyStrength = _friendlyStrength + (_c getOrDefault ["strength",0]);
    _mg = _mg + count (_c getOrDefault ["mg",[]]);
    _gl = _gl + count (_c getOrDefault ["grenadier",[]]);
    _at = _at + count (_c getOrDefault ["at",[]]);
    _aa = _aa + count (_c getOrDefault ["aa",[]]);
    _med = _med + count (_c getOrDefault ["medic",[]]);
    _eng = _eng + count (_c getOrDefault ["engineer",[]]);
    _veh = _veh + count (_c getOrDefault ["vehicles",[]]);
    _recon = _recon + count (_c getOrDefault ["reconUAS",[]]);
    _fpvAP = _fpvAP + count (_c getOrDefault ["fpvAP",[]]) + count (_c getOrDefault ["fpvAPTI",[]]);
    _fpvAT = _fpvAT + count (_c getOrDefault ["fpvAT",[]]) + count (_c getOrDefault ["fpvATTI",[]]);
    {_roles pushBackUnique _x;} forEach (_c getOrDefault ["roles",[]]);
} forEach _groups;

private _enemyStrength = _battlefield getOrDefault ["contactCount",0];
private _eInf = _battlefield getOrDefault ["enemyInfantry",_enemyStrength];
private _eVeh = _battlefield getOrDefault ["enemyVehicles",0];
private _eArm = _battlefield getOrDefault ["enemyArmour",0];
private _eStatic = _battlefield getOrDefault ["enemyStatic",0];
private _eAir = _battlefield getOrDefault ["enemyAir",0];

private _linkedSupport = false;
if ((count _commander) > 0) then {
    private _cmdId = _commander getOrDefault ["id",""];
    {
        private _asset = _y;
        if ((count _asset) > 0 && {(_asset getOrDefault ["commanderId",""]) isEqualTo _cmdId}) then {
            private _objects = (_asset getOrDefault ["assets",[]]) select {!isNull _x && {alive _x}};
            if (_objects isNotEqualTo []) exitWith {_linkedSupport = true;};
        };
    } forEach ARTIC_SupportAssets;
};

private _friendlyPower = _friendlyStrength + (_mg * 2.2) + (_gl * 1.2) + (_at * 1.8) + (_veh * 2.5) + (_fpvAP * 1.2) + (_fpvAT * 2.0) + ([0,4] select _linkedSupport);
private _enemyPower = (_eInf max 1) + (_eVeh * 2.5) + (_eArm * 5.0) + (_eStatic * 2.3) + (_eAir * 5.5);
private _ratio = _friendlyPower / (_enemyPower max 1);
private _friendlySize = switch (true) do {
    case (_friendlyStrength <= 4): {"TEAM"};
    case (_friendlyStrength <= 12): {"SECTION"};
    case (_friendlyStrength <= 40): {"PLATOON"};
    case (_friendlyStrength <= 120): {"COMPANY"};
    default {"BATTALION_PLUS"};
};
private _enemySizeFallback = switch (true) do {
    case (_enemyStrength <= 4): {"TEAM"};
    case (_enemyStrength <= 12): {"SECTION"};
    case (_enemyStrength <= 40): {"PLATOON"};
    default {"COMPANY_PLUS"};
};
private _enemySize = _battlefield getOrDefault ["enemySize",_enemySizeFallback];
private _lineGroups = _groups select {([_x] call ARTIC_fnc_scanGroupCapabilities) getOrDefault ["strength",0] >= 4};
private _plan = switch (true) do {
    case (_ratio < 0.55): {"HOLD_FOR_SUPPORT"};
    case ((count _lineGroups) >= 4): {"TWO_AXIS_WITH_RESERVE"};
    case ((count _lineGroups) >= 3): {"FIX_LEFT_RIGHT"};
    case ((count _lineGroups) isEqualTo 2): {"FIX_SINGLE_FLANK"};
    default {"SINGLE_AXIS"};
};
private _assaultAllowed = (_ratio >= 0.72) || {_linkedSupport} || {_fpvAP > 0} || {_fpvAT > 0};
// Capability mismatch can veto an otherwise favourable headcount. A platoon that
// has located armour but has no AT/AT-FPV/support should establish the battlefield
// and hold rather than charging because it numerically outnumbers the crews.
if (_eArm > 0 && {_at <= 0} && {_fpvAT <= 0} && {!_linkedSupport}) then {_assaultAllowed = false; _plan = "HOLD_FOR_ANTI_ARMOUR";};

createHashMapFromArray [
    ["friendlyStrength",_friendlyStrength],["friendlySize",_friendlySize],["friendlyPower",_friendlyPower],
    ["enemyStrength",_enemyStrength],["enemySize",_enemySize],["enemyPower",_enemyPower],["forceRatio",_ratio],
    ["mg",_mg],["grenadiers",_gl],["at",_at],["aa",_aa],["medics",_med],["engineers",_eng],["vehicles",_veh],
    ["reconUAS",_recon],["fpvAP",_fpvAP],["fpvAT",_fpvAT],["roles",_roles],["linkedSupport",_linkedSupport],
    ["plan",_plan],["assaultAllowed",_assaultAllowed]
]
