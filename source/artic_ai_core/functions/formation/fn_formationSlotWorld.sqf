/*
    ARTIC - world position of a soldier's formation slot (v0.3.9).
    _validate = true: pull the slot toward the guide if it's in water or the line from the
    guide to it passes through a building (only done when a new move order is issued).
    Returns [] if the soldier has no slot or the section has no guide.
*/
params [["_unit",objNull,[objNull]],["_group",grpNull,[grpNull]],["_validate",false,[true]]];
private _guide = _group getVariable ["ARTIC_guide",[]];
if (_guide isEqualTo []) exitWith {[]};
private _slots = (_group getVariable ["ARTIC_formSlots",["",createHashMap]]) select 1;
private _s = _slots getOrDefault [netId _unit,[]];
if (_s isEqualTo []) exitWith {[]};
_guide params ["_gPos","_gDir"];
private _sp = _group getVariable ["ARTIC_formSpacing",1];
_s params ["_lat","_fwd"];
// v0.3.14: heavy left / heavy right - mirrored so the MG side faces the likely contact
if (_group getVariable ["ARTIC_formMirror",false]) then {_lat = -_lat;};

private _p = +_gPos;
if ((abs _fwd) > 0.01) then {_p = _p getPos [(abs _fwd) * _sp, _gDir + ([0,180] select (_fwd < 0))];};
if ((abs _lat) > 0.01) then {_p = _p getPos [(abs _lat) * _sp, _gDir + ([90,-90] select (_lat < 0))];};
_p set [2,0];
if (!_validate) exitWith {_p};

for "_i" from 1 to 3 do {
    private _blocked = surfaceIsWater _p;
    if (!_blocked) then {
        private _hits = lineIntersectsSurfaces [(AGLToASL _gPos) vectorAdd [0,0,1], (AGLToASL _p) vectorAdd [0,0,1], _unit, objNull, true, 1, "GEOM", "NONE"];
        if (_hits isNotEqualTo []) then {
            private _o = (_hits select 0) select 2;
            _blocked = !isNull _o && {_o isKindOf "House" || {_o isKindOf "Wall"}};
        };
    };
    if (!_blocked) exitWith {};
    _p = _gPos vectorAdd ((_p vectorDiff _gPos) vectorMultiply 0.6);
    _p set [2,0];
};
_p
