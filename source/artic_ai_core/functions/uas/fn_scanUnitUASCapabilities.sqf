params [["_unit",objNull,[objNull]]];
if (isNull _unit) exitWith {createHashMap};

private _assigned = assignedItems _unit;
private _terminal = (_assigned findIf {toLower _x find "uavterminal" >= 0}) >= 0;
private _bp = backpack _unit;
private _reconClass = "";
private _reconSource = "";

if (_bp isNotEqualTo "" && {toLower _bp find "crocus_" < 0}) then {
    private _bCfg = configFile >> "CfgVehicles" >> _bp;
    if (isClass _bCfg) then {
        private _assembleTo = getText (_bCfg >> "assembleInfo" >> "assembleTo");
        if (_assembleTo isNotEqualTo "" && {isClass (configFile >> "CfgVehicles" >> _assembleTo)}) then {
            private _uCfg = configFile >> "CfgVehicles" >> _assembleTo;
            if (getNumber (_uCfg >> "isUav") > 0) then {
                _reconClass = _assembleTo;
                _reconSource = _bp;
            };
        };
    };
};

private _mags = magazines _unit;
private _countMag = {
    params ["_class"];
    {_x isEqualTo _class} count _mags
};

private _ap = [];
private _at = [];
private _apTI = [];
private _atTI = [];

{
    _x params ["_item","_kind","_thermal"];
    private _n = [_item] call _countMag;
    for "_i" from 1 to _n do {
        private _entry = [_unit,_item,_thermal,false];
        switch (_kind) do {
            case "AP": {if (_thermal) then {_apTI pushBack _entry} else {_ap pushBack _entry};};
            case "AT": {if (_thermal) then {_atTI pushBack _entry} else {_at pushBack _entry};};
        };
    };
} forEach [
    ["Item_Crocus_AP","AP",false],
    ["Item_Crocus_AT","AT",false],
    ["Item_Crocus_AP_TI","AP",true],
    ["Item_Crocus_AT_TI","AT",true]
];

if (_bp isNotEqualTo "") then {
    private _l = toLower _bp;
    if (_l find "crocus_ap_ti_bag" >= 0) then {_apTI pushBack [_unit,_bp,true,true];};
    if (_l find "crocus_at_ti_bag" >= 0) then {_atTI pushBack [_unit,_bp,true,true];};
    if (_l find "crocus_ap_bag" >= 0 && {_l find "_ti_" < 0}) then {_ap pushBack [_unit,_bp,false,true];};
    if (_l find "crocus_at_bag" >= 0 && {_l find "_ti_" < 0}) then {_at pushBack [_unit,_bp,false,true];};
};

private _operator = _terminal || {_reconClass isNotEqualTo ""} || {_ap isNotEqualTo []} || {_at isNotEqualTo []} || {_apTI isNotEqualTo []} || {_atTI isNotEqualTo []};

createHashMapFromArray [
    ["unit",_unit],
    ["operator",_operator],
    ["terminal",_terminal],
    ["reconClass",_reconClass],
    ["reconSource",_reconSource],
    ["fpvAP",_ap],
    ["fpvAT",_at],
    ["fpvAPTI",_apTI],
    ["fpvATTI",_atTI]
]
