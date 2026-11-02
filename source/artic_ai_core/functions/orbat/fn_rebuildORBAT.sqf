params [["_commander", createHashMap, [createHashMap]]];
if (!isServer || {(count _commander) isEqualTo 0}) exitWith { [] };

private _logic = _commander get "logic";
private _id = _commander get "id";
private _doctrine = _commander get "doctrine";
private _training = _commander get "training";

private _roots = (synchronizedObjects _logic) select { _x isKindOf "ARTIC_Module_Formation" };
private _orbat = [];
{
    private _node = [_x, objNull, _doctrine, _training, _id] call ARTIC_fnc_buildFormationNode;
    if ((count _node) > 0) then { _orbat pushBack _node; };
} forEach _roots;

_commander set ["orbat", _orbat];
[format ["ORBAT rebuilt: %1 root formation(s)", count _orbat], _id] call ARTIC_fnc_debug;
_orbat
