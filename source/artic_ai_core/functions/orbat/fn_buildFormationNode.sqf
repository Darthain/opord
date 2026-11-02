params [
    ["_logic", objNull, [objNull]],
    ["_parent", objNull, [objNull]],
    ["_inheritedDoctrine", "CONVENTIONAL", [""]],
    ["_inheritedTraining", "REGULAR", [""]],
    ["_commanderId", "", [""]]
];

if (isNull _logic) exitWith { createHashMap };

private _id = _logic getVariable ["FormationId", format ["FORM_%1", netId _logic]];
private _name = _logic getVariable ["FormationName", _id];
private _level = toUpper (_logic getVariable ["FormationLevel", "PLATOON"]);

private _doctrine = toUpper (_logic getVariable ["DoctrineOverride", "INHERIT"]);
if (_doctrine isEqualTo "INHERIT") then { _doctrine = _inheritedDoctrine; };

private _training = toUpper (_logic getVariable ["TrainingOverride", "INHERIT"]);
if (_training isEqualTo "INHERIT") then { _training = _inheritedTraining; };

private _synced = synchronizedObjects _logic;
private _childLogics = _synced select {
    _x isKindOf "ARTIC_Module_Formation" && {_x isNotEqualTo _parent}
};

private _groups = [];
{
    if !(_x isKindOf "Module_F") then {
        private _g = if (_x isKindOf "Man") then { group _x } else { group effectiveCommander _x };
        if (!isNull _g) then { _groups pushBackUnique _g; };
    };
} forEach _synced;

private _children = [];
{
    private _child = [_x, _logic, _doctrine, _training, _commanderId] call ARTIC_fnc_buildFormationNode;
    if ((count _child) > 0) then { _children pushBack _child; };
} forEach _childLogics;

{
    _x setVariable ["ARTIC_enabled", true, true];
    _x setVariable ["ARTIC_commanderId", _commanderId, true];
    _x setVariable ["ARTIC_formationId", _id, true];
    _x setVariable ["ARTIC_doctrine", _doctrine, true];
    _x setVariable ["ARTIC_training", _training, true];
    if (isNil {_x getVariable "ARTIC_morale"}) then {
        _x setVariable ["ARTIC_morale", 100, true];
    };
} forEach _groups;

createHashMapFromArray [
    ["id",_id],["name",_name],["level",_level],["logic",_logic],
    ["doctrine",_doctrine],["training",_training],["groups",_groups],
    ["children",_children],["intent",""],["intentPos",[]]
]
