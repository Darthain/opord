params [
    ["_commander",createHashMap,[createHashMap]],
    ["_objective",createHashMap,[createHashMap]]
];
if ((count _commander) isEqualTo 0 || {(count _objective) isEqualTo 0}) exitWith {};

private _id = _commander get "id";
private _type = toUpper (_objective get "type");
private _pos = _objective get "position";
private _radius = _objective get "radius";
private _objId = _objective get "id";
private _fallback = [];

// For delay missions, use the closest friendly-controlled site behind the force as a fallback.
if (_type isEqualTo "DELAY") then {
    private _side = _commander get "side";
    private _candidates = [];
    private _cmdLogic = _commander get "logic";
    private _siteModules = (synchronizedObjects _cmdLogic) select { _x isKindOf "ARTIC_Module_Site" };
    {
        private _sid = _x getVariable ["SiteId",""];
        private _site = ARTIC_Sites getOrDefault [_sid,createHashMap];
        if ((count _site) > 0 && {(_site getOrDefault ["owner",sideUnknown]) isEqualTo _side}) then {
            _candidates pushBack [(_site get "position") distance2D _pos, _site get "position"];
        };
    } forEach _siteModules;
    if (_candidates isNotEqualTo []) then {
        _candidates sort true;
        _fallback = (_candidates select 0) select 1;
    };
};

/*
    v0.3.21: objective PURPOSE is no longer converted immediately into a section-level
    ATTACK order.  CAPTURE becomes the strategic intent SEIZE.  The platoon planner is
    responsible for choosing HOW to seize the objective (axis, release, hold, SBF,
    manoeuvre lanes) and only arms executable FIX/ATTACK orders at tactical release.

    Unknown objective types are deliberately rejected instead of defaulting to ATTACK.
*/
private _intent = switch (_type) do {
    case "CAPTURE": {"SEIZE"};
    case "DEFEND": {"DEFEND"};
    case "DELAY": {"DELAY"};
    case "RECON": {"RECON"};
    case "RAID": {"RAID"};
    case "SCREEN": {"SCREEN"};
    case "DENY": {"DEFEND"};
    default {""};
};

if (_intent isEqualTo "") exitWith {
    [format ["Objective %1 has unsupported type '%2'; no formation intent assigned",_objId,_type],_id] call ARTIC_fnc_debug;
};

{
    [_x,_intent,_pos,_radius,_id,_fallback,format ["%1:%2",_objId,_intent]] call ARTIC_fnc_assignFormationIntent;
} forEach (_commander getOrDefault ["orbat",[]]);

_commander set ["currentObjective",_objId];
[format ["Assigned strategic %1 at %2 (%3)",_intent,mapGridPosition _pos,_objId],_id] call ARTIC_fnc_debug;
