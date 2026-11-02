params [
    ["_anchor",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_radius",16,[0]],
    ["_preferHidden",false,[true]],
    ["_requireLOS",false,[true]]
];
if (_anchor isEqualTo []) exitWith {[]};

private _best = +_anchor;
private _bestScore = -1e9;
private _samples = 14;

for "_i" from 0 to (_samples - 1) do {
    private _angle = (_i * (360 / _samples)) + random 10;
    private _dist = 2 + random (_radius max 4);
    private _p = _anchor getPos [_dist,_angle];
    if !(surfaceIsWater _p) then {
        private _normal = surfaceNormal _p;
        private _slope = acos (((_normal select 2) max -1) min 1);
        if (_slope < 28) then {
            private _cover = [_p] call ARTIC_fnc_coverScore;
            private _los = if (isNull _target) then {false} else {[_p,_target] call ARTIC_fnc_hasLineOfSight};
            if !(_requireLOS && {!isNull _target} && {!_los}) then {
                private _score = (_cover * 55) + ((1 - (_slope / 28)) * 15) - (_dist * 0.35);
                if (!isNull _target) then {
                    if (_preferHidden) then {
                        _score = _score + (if (_los) then {-28} else {28});
                    } else {
                        // Firing-position searches strongly prefer actual LOS. This
                        // is deliberately much stronger than v0.3.0's +10 bonus.
                        _score = _score + (if (_los) then {35} else {-20});
                    };
                };
                if (_score > _bestScore) then {_bestScore = _score; _best = _p;};
            };
        };
    };
};
_best
