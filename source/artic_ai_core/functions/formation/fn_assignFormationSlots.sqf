/*
    ARTIC - assign each fit soldier a formation slot by role (v0.3.9).

    Roles from ARTIC_fnc_scanGroupCapabilities: group leader = CMD, medic = MEDIC,
    MG/autorifle = MG, launcher = AT, grenadier = GREN, 2IC = highest-ranked other
    soldier (not MG/AT/medic where possible), SCOUT = a rifleman at the point.

    Training:
      specialistAssignment  chance each soldier ends up in his proper slot; low values
                            swap people around (sloppy placement)
      coordination          low values sometimes put the commander at the point
                            ("leading from the front" instead of controlling the section)

    Cached per formation + membership; recomputed when either changes.
    Returns hashmap netId(unit) -> [lateral, forward, role]
*/
params [["_group",grpNull,[grpNull]],["_formation","WEDGE",[""]]];
if (isNull _group) exitWith {createHashMap};

private _fit = (units _group) select {[_x] call ARTIC_fnc_isFit};
private _key = format ["%1|%2", _formation, (_fit apply {netId _x}) joinString ","];
private _cache = _group getVariable ["ARTIC_formSlots",["",createHashMap]];
if ((_cache select 0) isEqualTo _key) exitWith {_cache select 1};

// ---- roles --------------------------------------------------------------------------
private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _leader = leader _group;
private _roleOf = createHashMap;
{_roleOf set [netId _x,"RIFLE"];} forEach _fit;
{if (_x in _fit) then {_roleOf set [netId _x,"GREN"];};} forEach (_caps getOrDefault ["grenadier",[]]);
{if (_x in _fit) then {_roleOf set [netId _x,"AT"];};} forEach (_caps getOrDefault ["at",[]]);
{if (_x in _fit) then {_roleOf set [netId _x,"MG"];};} forEach (_caps getOrDefault ["mg",[]]);
{if (_x in _fit) then {_roleOf set [netId _x,"MEDIC"];};} forEach (_caps getOrDefault ["medic",[]]);
if (_leader in _fit) then {_roleOf set [netId _leader,"CMD"];};

// 2IC: highest rank among the rest, preferring riflemen/grenadiers
private _cands = _fit select {(_roleOf get netId _x) in ["RIFLE","GREN"]};
if (_cands isEqualTo []) then {_cands = _fit select {(_roleOf get netId _x) isNotEqualTo "CMD"};};
if (_cands isNotEqualTo []) then {
    private _second = ([_cands,[],{rankId _x},"DESCEND"] call BIS_fnc_sortBy) select 0;
    _roleOf set [netId _second,"SECOND"];
};
// point man: a remaining rifleman (or grenadier)
private _scoutC = _fit select {(_roleOf get netId _x) isEqualTo "RIFLE"};
if (_scoutC isEqualTo []) then {_scoutC = _fit select {(_roleOf get netId _x) isEqualTo "GREN"};};
if (_scoutC isNotEqualTo []) then {_roleOf set [netId (_scoutC select 0),"SCOUT"];};

// ---- slots ------------------------------------------------------------------------------
private _slots = +([_formation] call ARTIC_fnc_getFormationTemplate);
private _minFwd = 0;
{_minFwd = _minFwd min (_x select 2);} forEach _slots;
private _extra = 0;
while {(count _slots) < (count _fit)} do {
    _extra = _extra + 1;
    if (_formation isEqualTo "CROWS_FOOT") then {
        // extra men go to the front groups, toward the most likely contact
        private _side = [-1,1] select (_extra mod 2);
        _slots pushBack ["RIFLE", _side * (4.4 + 0.7 * floor ((_extra - 1) / 2)), 1.2 + 0.6 * floor ((_extra - 1) / 2)];
    } else {
        private _side = [-1,1] select (_extra mod 2);
        _slots pushBack ["RIFLE", _side, _minFwd - (ceil (_extra / 2)) * 1.2];
    };
};

private _assign = createHashMap;       // slotIndex -> unit
private _taken = [];
{
    private _role = _x;
    {
        _x params ["_sRole"];
        if (_sRole isEqualTo _role && {!(_forEachIndex in (keys _assign))}) then {
            private _u = _fit findIf {!(_x in _taken) && {(_roleOf get netId _x) isEqualTo _role}};
            if (_u > -1) then {_assign set [_forEachIndex,_fit select _u]; _taken pushBack (_fit select _u);};
        };
    } forEach _slots;
} forEach ["CMD","MEDIC","SECOND","MG","AT","GREN","SCOUT"];

// v0.3.14: everyone else fills the remaining slots in template order, choosing the best
// available substitute for the slot's role (a second MG slot takes a grenadier, then AT,
// then a rifleman). The CMD slot is only ever the commander's.
private _rest = _fit - _taken;
private _fallback = createHashMapFromArray [
    ["MG",["MG","GREN","AT","SCOUT","RIFLE"]],
    ["GREN",["GREN","AT","RIFLE","SCOUT"]],
    ["AT",["AT","GREN","RIFLE","SCOUT"]],
    ["SCOUT",["SCOUT","RIFLE","GREN"]],
    ["RIFLE",["RIFLE","SCOUT","GREN","AT","MG"]],
    ["SECOND",["RIFLE","GREN","SCOUT"]],
    ["MEDIC",["RIFLE","SCOUT"]]
];
{
    if (_rest isEqualTo []) exitWith {};
    private _sRole = _x select 0;
    if (!(_forEachIndex in (keys _assign)) && {_sRole isNotEqualTo "CMD"}) then {
        private _pick = -1;
        {
            private _want = _x;
            if (_pick < 0) then {_pick = _rest findIf {(_roleOf get netId _x) isEqualTo _want};};
        } forEach (_fallback getOrDefault [_sRole,["RIFLE"]]);
        if (_pick < 0) then {_pick = 0;};
        _assign set [_forEachIndex,_rest deleteAt _pick];
    };
} forEach _slots;

// ---- training noise -----------------------------------------------------------------
([_group] call ARTIC_fnc_getProfile) params ["","","","_training"];
private _spec = _training getOrDefault ["specialistAssignment",0.6];
private _coord = _training getOrDefault ["coordination",0.55];
private _idx = keys _assign;
{
    if (random 1 < ((1 - _spec) * 0.5)) then {
        private _other = selectRandom _idx;
        private _uA = _assign get _x; private _uB = _assign get _other;
        private _rA = _roleOf getOrDefault [netId _uA,"RIFLE"];
        private _rB = _roleOf getOrDefault [netId _uB,"RIFLE"];
        // Command, medic and 2IC positions are hard-protected. Training noise may
        // make rifle/specialist placement sloppy, but never sends the medic to point.
        if !(_rA in ["CMD","MEDIC","SECOND"] || {_rB in ["CMD","MEDIC","SECOND"]}) then {
            _assign set [_x,_uB]; _assign set [_other,_uA];
        };
    };
} forEach _idx;
if (false) then {
    // Commanders remain in the protected command slot; individual initiative is handled elsewhere
    private _cmdIdx = _idx findIf {(_assign get _x) isEqualTo _leader};
    private _frontIdx = _idx findIf {((_slots select _x) select 0) isEqualTo "SCOUT"};
    if (_cmdIdx > -1 && {_frontIdx > -1}) then {
        private _a = _idx select _cmdIdx; private _b = _idx select _frontIdx;
        private _uB = _assign get _b;
        _assign set [_a,_uB]; _assign set [_b,_leader];
    };
};

private _result = createHashMap;
{
    private _s = _slots select _x;
    private _u = _y;
    _result set [netId _u,[_s select 1,_s select 2,_s select 0]];
    _u setVariable ["ARTIC_formRole",_roleOf get netId _u,false];
} forEach _assign;

_group setVariable ["ARTIC_formSlots",[_key,_result],false];
_result
