if (!isServer) exitWith {};

{
    private _site = _y;
    private _pos = _site get "position";
    private _radius = _site get "radius";
    private _near = allUnits select { alive _x && {_x distance2D _pos <= _radius} };

    private _west = 0;
    private _east = 0;
    private _ind = 0;
    {
        switch (side group _x) do {
            case west: {_west = _west + 1;};
            case east: {_east = _east + 1;};
            case resistance: {_ind = _ind + 1;};
        };
    } forEach _near;

    private _best = sideUnknown;
    private _bestCount = 0;
    {
        _x params ["_s","_c"];
        if (_c > _bestCount) then {_best = _s; _bestCount = _c;};
    } forEach [[west,_west],[east,_east],[resistance,_ind]];

    if (_bestCount > 0) then {_site set ["owner",_best];};
} forEach ARTIC_Sites;
