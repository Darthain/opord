params [
    ["_commander",createHashMap,[createHashMap]],
    ["_objective",createHashMap,[createHashMap]]
];
if ((count _commander) isEqualTo 0 || {(count _objective) isEqualTo 0}) exitWith {-1};
if !(_objective getOrDefault ["active",true]) exitWith {-1};

private _side = _commander get "side";
private _type = _objective get "type";
private _priority = _objective get "priority";
private _pos = _objective get "position";
private _radius = _objective get "radius";

// AO gate: if a commander has a synchronized AO, objectives outside it are ignored.
private _cmdLogic = _commander get "logic";
private _aoModules = (synchronizedObjects _cmdLogic) select { _x isKindOf "ARTIC_Module_AO" };
if (_aoModules isNotEqualTo []) then {
    private _ao = _aoModules select 0;
    private _aoRadius = _ao getVariable ["Radius",3000];
    if ((_ao distance2D _pos) > _aoRadius) exitWith {-1};
};

private _friendly = 0;
private _enemy = 0;
{
    if (alive _x && {_x distance2D _pos <= _radius}) then {
        private _s = side group _x;
        if (_s isEqualTo _side) then {
            _friendly = _friendly + 1;
        } else {
            if ((_side getFriend _s) < 0.6) then { _enemy = _enemy + 1; };
        };
    };
} forEach allUnits;

private _siteBonus = 0;
private _siteModules = (synchronizedObjects _cmdLogic) select { _x isKindOf "ARTIC_Module_Site" };
{
    private _sid = _x getVariable ["SiteId",""];
    private _site = ARTIC_Sites getOrDefault [_sid,createHashMap];
    if ((count _site) > 0 && {(_site get "position") distance2D _pos <= ((_site get "radius") + _radius)}) then {
        _siteBonus = _siteBonus max (_site getOrDefault ["strategicValue",0]);
    };
} forEach _siteModules;

private _need = 1;
switch (_type) do {
    case "DEFEND": { _need = 1 + (_enemy * 0.25) + (if (_friendly isEqualTo 0) then {1} else {0}); };
    case "CAPTURE": { _need = 1 + (_enemy * 0.20) + (if (_friendly isEqualTo 0) then {0.5} else {0}); };
    case "DELAY": { _need = 1 + (_enemy * 0.30); };
    case "RECON": { _need = 0.8 + (_enemy * 0.05); };
    case "RAID": { _need = 0.9 + (_enemy * 0.10); };
    case "SCREEN": { _need = 0.8 + (_enemy * 0.10); };
    case "DENY": { _need = 1 + (_enemy * 0.20); };
};

((_priority * 10) + (_siteBonus * 2)) * _need
