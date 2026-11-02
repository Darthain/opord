params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {createHashMap};

private _alive = (units _group) select {alive _x};
private _mg = [];
private _grenadier = [];
private _at = [];
private _aa = [];
private _medic = [];
private _engineer = [];
private _radio = [];
private _rifle = [];
private _vehicles = [];
private _roles = [];
private _uasOperators = [];
private _reconUAS = [];
private _fpvAP = [];
private _fpvAT = [];
private _fpvAPTI = [];
private _fpvATTI = [];

// Classify a secondary weapon by the ammunition it can actually fire. This avoids
// the old behaviour where every launcher, including MANPADS, was treated as AT.
private _classifyLauncher = {
    params ["_weapon"];
    if (_weapon isEqualTo "") exitWith {[false,false]};

    private _wCfg = configFile >> "CfgWeapons" >> _weapon;
    private _mags = +getArray (_wCfg >> "magazines");
    private _muzzles = getArray (_wCfg >> "muzzles");
    {
        if !(_x isEqualTo "this") then {
            _mags append getArray (_wCfg >> _x >> "magazines");
        };
    } forEach _muzzles;
    _mags = _mags arrayIntersect _mags;

    private _atCap = false;
    private _aaCap = false;
    {
        private _mCfg = configFile >> "CfgMagazines" >> _x;
        private _ammoClass = getText (_mCfg >> "ammo");
        private _aCfg = configFile >> "CfgAmmo" >> _ammoClass;
        private _airLock = getNumber (_aCfg >> "airLock");
        private _hit = getNumber (_aCfg >> "hit");
        private _indirect = getNumber (_aCfg >> "indirectHit");
        private _token = toLower format ["%1 %2",_x,_ammoClass];
        private _isAAAmmo = (_airLock > 0) ||
            {_token find "_aa" >= 0} ||
            {_token find "stinger" >= 0} ||
            {_token find "igla" >= 0} ||
            {_token find "strela" >= 0} ||
            {_token find "sam" >= 0};

        if (_isAAAmmo) then {
            _aaCap = true;
        } else {
            if ((_hit > 40) || {_indirect > 20}) then {_atCap = true;};
        };
    } forEach _mags;

    // Conservative fallback for unusual modded launchers with no exposed magazine
    // list. Manual Role Override remains available for anything still ambiguous.
    if (_mags isEqualTo []) then {
        private _w = toLower _weapon;
        if ((_w find "stinger" >= 0) || {_w find "igla" >= 0} || {_w find "strela" >= 0} || {_w find "_aa" >= 0}) then {
            _aaCap = true;
        } else {
            _atCap = true;
        };
    };

    [_atCap,_aaCap]
};

{
    private _u = _x;
    private _pw = primaryWeapon _u;
    private _pcfg = configFile >> "CfgWeapons" >> _pw;
    private _parents = toLower str ([_pcfg,true] call BIS_fnc_returnParents);
    private _isMG = (_parents find "machinegun" >= 0) || {toLower _pw find "lmg" >= 0} || {toLower _pw find "mmg" >= 0};
    private _muzzles = getArray (_pcfg >> "muzzles");
    private _isGrenadier = count _muzzles > 1;

    private _sw = secondaryWeapon _u;
    private _launcherCaps = [_sw] call _classifyLauncher;
    private _isAT = _launcherCaps select 0;
    private _isAA = _launcherCaps select 1;

    private _ucfg = configFile >> "CfgVehicles" >> typeOf _u;
    private _isMedic = (getNumber (_ucfg >> "attendant") > 0) || {getNumber (_ucfg >> "ace_medical_medicClass") > 0};
    private _isEngineer = (getNumber (_ucfg >> "engineer") > 0) || {getNumber (_ucfg >> "canDeactivateMines") > 0};

    if (_isMG) then {_mg pushBackUnique _u;};
    if (_isGrenadier) then {_grenadier pushBackUnique _u;};
    if (_isAT) then {_at pushBackUnique _u;};
    if (_isAA) then {_aa pushBackUnique _u;};
    if (_isMedic) then {_medic pushBackUnique _u;};
    if (_isEngineer) then {_engineer pushBackUnique _u;};

    private _hasRadio = false;
    if !(isNil "acre_api_fnc_hasRadio") then {
        _hasRadio = [_u] call acre_api_fnc_hasRadio;
    } else {
        // Vanilla radio is a better fallback than the previous "has backpack"
        // approximation. The leader is retained as a command node if a mod strips it.
        _hasRadio = ("ItemRadio" in assignedItems _u) || {_u isEqualTo leader _group};
    };
    if (_hasRadio) then {_radio pushBackUnique _u;};

    private _uas = [_u] call ARTIC_fnc_scanUnitUASCapabilities;
    if (_uas getOrDefault ["operator",false]) then {_uasOperators pushBackUnique _u;};
    private _rc = _uas getOrDefault ["reconClass",""];
    if (_rc isNotEqualTo "") then {_reconUAS pushBack [_u,_uas getOrDefault ["reconSource",""],false,true];};
    _fpvAP append (_uas getOrDefault ["fpvAP",[]]);
    _fpvAT append (_uas getOrDefault ["fpvAT",[]]);
    _fpvAPTI append (_uas getOrDefault ["fpvAPTI",[]]);
    _fpvATTI append (_uas getOrDefault ["fpvATTI",[]]);

    private _veh = vehicle _u;
    if (_veh isNotEqualTo _u) then {_vehicles pushBackUnique _veh;};

    if !(_isMG || _isGrenadier || _isAT || _isAA || _isMedic) then {_rifle pushBackUnique _u;};
} forEach _alive;

{
    {_roles pushBackUnique _x;} forEach ([_x] call ARTIC_fnc_scanVehicleCapabilities);
} forEach _vehicles;

if (_mg isNotEqualTo []) then {_roles pushBackUnique "SUPPRESSION";};
if (_at isNotEqualTo []) then {_roles pushBackUnique "ANTI_ARMOUR";};
if (_aa isNotEqualTo []) then {_roles pushBackUnique "ANTI_AIR";};
if (_medic isNotEqualTo []) then {_roles pushBackUnique "MEDICAL";};
if (_engineer isNotEqualTo []) then {_roles pushBackUnique "ENGINEER";};
if (_radio isNotEqualTo []) then {_roles pushBackUnique "COMMUNICATIONS";};
if (_uasOperators isNotEqualTo []) then {_roles pushBackUnique "UAS_OPERATOR";};
if (_reconUAS isNotEqualTo []) then {_roles pushBackUnique "RECON_UAS";};
if ((_fpvAP isNotEqualTo []) || {_fpvAPTI isNotEqualTo []}) then {_roles pushBackUnique "FPV_AP";};
if ((_fpvAT isNotEqualTo []) || {_fpvATTI isNotEqualTo []}) then {_roles pushBackUnique "FPV_AT";};

{_roles pushBackUnique _x;} forEach (_group getVariable ["ARTIC_roleOverrides",[]]);

private _result = createHashMapFromArray [
    ["alive",_alive],["leader",leader _group],["mg",_mg],["grenadier",_grenadier],
    ["at",_at],["aa",_aa],["medic",_medic],["engineer",_engineer],
    ["radio",_radio],["rifle",_rifle],["vehicles",_vehicles],["roles",_roles],
    ["uasOperators",_uasOperators],["reconUAS",_reconUAS],
    ["fpvAP",_fpvAP],["fpvAT",_fpvAT],["fpvAPTI",_fpvAPTI],["fpvATTI",_fpvATTI],
    ["strength",count _alive]
];

if (ARTIC_debug) then {
    private _sig = format ["%1|AT%2|AA%3|R%4|AP%5|FPVAT%6",str _roles,count _at,count _aa,count _reconUAS,(count _fpvAP)+(count _fpvAPTI),(count _fpvAT)+(count _fpvATTI)];
    if (_sig isNotEqualTo (_group getVariable ["ARTIC_capDebugSig",""])) then {
        _group setVariable ["ARTIC_capDebugSig",_sig,false];
        [format ["Capabilities roles=%1 AT=%2 AA=%3 recon=%4 fpvAP=%5 fpvAT=%6",_roles,count _at,count _aa,count _reconUAS,(count _fpvAP)+(count _fpvAPTI),(count _fpvAT)+(count _fpvATTI)],groupId _group] call ARTIC_fnc_debug;
    };
};
_result
