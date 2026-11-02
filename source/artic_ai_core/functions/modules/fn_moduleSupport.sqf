params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};

private _id = _logic getVariable ["SupportId", format ["SUPPORT_%1", netId _logic]];
private _synced = synchronizedObjects _logic;
private _assets = _synced select { !(_x isKindOf "Module_F") };
private _commanderModules = _synced select { _x isKindOf "ARTIC_Module_Commander" };
private _commanderIds = _commanderModules apply {_x getVariable ["CommanderId",""]};
_commanderIds = _commanderIds select {_x isNotEqualTo ""};

ARTIC_SupportAssets set [_id, createHashMapFromArray [
    ["id",_id],
    ["logic",_logic],
    ["role",toUpper (_logic getVariable ["SupportRole","MORTAR"])],
    ["priority",(_logic getVariable ["Priority",50]) max 1 min 100],
    ["ammoClass",_logic getVariable ["AmmoClass",""]],
    ["rounds",round ((_logic getVariable ["Rounds",4]) max 1)],
    ["assets",_assets],
    ["commanderIds",_commanderIds],
    ["busyUntil",0]
]];
_logic setVariable ["ARTIC_registered",true,true];

[format ["Registered support asset %1 role=%2 assets=%3 commanders=%4",
    _id,
    toUpper (_logic getVariable ["SupportRole","MORTAR"]),
    count _assets,
    _commanderIds
],"SUPPORT"] call ARTIC_fnc_debug;
