/*
    ARTIC v0.3.17 - world slot around a temporary fireteam guide.
    Used by tactical split manoeuvres without reviving the retired majority-centroid
    anchor system.
*/
params [
    ["_unit",objNull,[objNull]],
    ["_anchor",[],[[]]],
    ["_dir",0,[0]],
    ["_spacing",1,[0]],
    ["_line",false,[true]]
];
if (isNull _unit || {_anchor isEqualTo []}) exitWith {[]};
private _idx = _unit getVariable ["ARTIC_teamSlot",0];
private _slot = if (_line) then {
    // 4-man fireteam line; extras extend outwards.
    switch (_idx) do {
        case 0: {[0,0]};
        case 1: {[-5,0]};
        case 2: {[5,0]};
        case 3: {[-10,0]};
        case 4: {[10,0]};
        default {
            private _side = [-1,1] select (_idx mod 2);
            [_side * (10 + 4 * floor ((_idx - 3) / 2)),0]
        };
    }
} else {
    // Compact combat wedge around the fireteam guide.
    switch (_idx) do {
        case 0: {[0,3]};
        case 1: {[-4,-2]};
        case 2: {[4,-2]};
        case 3: {[0,-6]};
        case 4: {[-7,-6]};
        default {
            private _row = floor ((_idx - 5) / 2);
            private _side = [-1,1] select (_idx mod 2);
            [_side * (7 + 3 * _row),-6 - 3 * _row]
        };
    }
};
_slot params ["_lat","_fwd"];
private _p = +_anchor;
if ((abs _fwd) > 0.01) then {_p = _p getPos [(abs _fwd) * _spacing,_dir + ([0,180] select (_fwd < 0))];};
if ((abs _lat) > 0.01) then {_p = _p getPos [(abs _lat) * _spacing,_dir + ([90,-90] select (_lat < 0))];};
_p set [2,0];
_p
