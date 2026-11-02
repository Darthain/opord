params [["_group",grpNull,[grpNull]], ["_range",1200,[0]]];
if (isNull _group || {!alive leader _group}) exitWith {objNull};

private _leader = leader _group;
private _side = side _group;
private _scored = [];
private _seen = [];

private _sectorBonus = {
    params ["_pos"];
    private _sector = _group getVariable ["ARTIC_battleFireSector",[]];
    private _focus = _group getVariable ["ARTIC_battleFocus",[]];
    if ((count _sector) isNotEqualTo 2 || {_focus isEqualTo []}) exitWith {0};
    private _axis = _group getVariable ["ARTIC_battleAxis",0];
    private _right = _axis + 90;
    private _lat = {
        params ["_p"];
        private _d = _focus distance2D _p;
        private _ang = ((_focus getDir _p) - _right);
        _d * cos _ang
    };
    private _a = [_sector select 0] call _lat;
    private _b = [_sector select 1] call _lat;
    private _x = [_pos] call _lat;
    private _lo = (_a min _b) - 30;
    private _hi = (_a max _b) + 30;
    if (_x >= _lo && {_x <= _hi}) then {85} else {-45}
};

// Local knowledge gets the strongest weighting.
{
    private _obj = _x;
    if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {(_side getFriend side _obj) < 0.6}) then {
        private _dist = _leader distance2D _obj;
        if (_dist <= _range) then {
            private _knowledge = _leader knowsAbout _obj;
            private _p = getPosATL _obj;
            _scored pushBack [(_knowledge * 300) - _dist + ([_p] call _sectorBonus),_obj,"LOCAL",_p];
            _seen pushBackUnique _obj;
        };
    };
} forEach (_leader targets [true,_range]);

// Add sibling/UAS reports. Their score decays with age so a stale report cannot
// dominate a fresh locally observed contact forever.
{
    _x params ["_obj","_lastPos","_t","_source","_formation","_confidence",["_sourceType","GROUND"]];
    if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {!(_obj in _seen)} && {(_side getFriend side _obj) < 0.6}) then {
        private _age = time - _t;
        private _dist = _leader distance2D _lastPos;
        if (_age < 90 && {_dist <= (_range + 200)}) then {
            private _sourceBonus = if (_sourceType isEqualTo "UAS") then {45} else {20};
            private _score = (_confidence * 280) + _sourceBonus - _dist - (_age * 2.2) + ([_lastPos] call _sectorBonus);
            _scored pushBack [_score,_obj,format ["SHARED:%1",_sourceType],_lastPos];
        };
    };
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);

// v0.3.27: persistent battle tracks outlive the short radio/UAS cache.
{
    _x params ["_obj","_lastPos","_t",["_sourceType","BATTLE"]];
    if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {!(_obj in _seen)} && {(_side getFriend side _obj) < 0.6}) then {
        private _age = time - _t;
        private _dist = _leader distance2D _lastPos;
        if (_age < 600 && {_dist <= (_range + 450)}) then {
            private _score = 120 - _dist - (_age * 0.20) + ([_lastPos] call _sectorBonus);
            _scored pushBack [_score,_obj,format ["BATTLE:%1",_sourceType],_lastPos];
            _seen pushBackUnique _obj;
        };
    };
} forEach (_group getVariable ["ARTIC_battleTracks",[]]);

if (_scored isEqualTo []) exitWith {objNull};
_scored sort false;
private _best = _scored select 0;
_best params ["_score","_target","_source","_lastKnown"];
_group setVariable ["ARTIC_targetSource",_source,true];
_group setVariable ["ARTIC_targetLastKnownPos",_lastKnown,true];
_target
