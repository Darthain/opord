params [
    ["_group",grpNull,[grpNull]],
    ["_center",[],[[]]],
    ["_threat",objNull,[objNull]]
];
if (isNull _group || {_center isEqualTo []}) exitWith {[]};

private _threatPos = if (isNull _threat) then {
    // v0.3.15: face the defence context's principal direction of fire when there is one
    private _frontDir = _group getVariable ["ARTIC_defencePDF",getDir leader _group];
    _center getPos [500,_frontDir]
} else { getPosATL _threat };

private _facing = _center getDir _threatPos;
private _count = count ((units _group) select {alive _x});
private _positions = [];
private _spacing = 18;
private _num = ((_count / 2) max 2) min 5;

for "_i" from 0 to (_num - 1) do {
    private _offset = (_i - ((_num - 1) / 2)) * _spacing;
    private _p = _center getPos [abs _offset, _facing + (if (_offset >= 0) then {90} else {-90})];
    _positions pushBack [_p,_facing];
};
_positions
