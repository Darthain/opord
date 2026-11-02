params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};

private _id = _logic getVariable ["CommanderId", "EAST_CMD"];
private _side = [_logic getVariable ["SideIndex", 1]] call ARTIC_fnc_sideFromIndex;
private _entry = createHashMapFromArray [
    ["id", _id],
    ["name", _logic getVariable ["CommanderName", "ARTIC Commander"]],
    ["logic", _logic],
    ["side", _side],
    ["doctrine", toUpper (_logic getVariable ["Doctrine", "CONVENTIONAL"])],
    ["training", toUpper (_logic getVariable ["Training", "REGULAR"])],
    ["level", toUpper (_logic getVariable ["CommandLevel", "BATTALION"])],
    ["decisionInterval", (_logic getVariable ["DecisionInterval", 20]) max 5],
    ["aggression", (_logic getVariable ["Aggression", 0.55]) max 0 min 1],
    ["caution", (_logic getVariable ["Caution", 0.55]) max 0 min 1],
    ["initiative", (_logic getVariable ["Initiative", 0.60]) max 0 min 1],
    ["adaptability", (_logic getVariable ["Adaptability", 0.60]) max 0 min 1],
    ["orbat", []],
    ["knownEnemies", []],
    ["lastDecision", -1000],
    ["currentObjective", ""],
    ["autoUAS", _logic getVariable ["AutoUAS", true]],
    ["uasReconCooldown", (_logic getVariable ["UASReconCooldown", 180]) max 30],
    ["uasStrikeCooldown", (_logic getVariable ["UASStrikeCooldown", 90]) max 20],
    ["uasContacts", []],
    ["lastUASRecon", -1000],
    ["lastUASStrike", -1000],
    ["uasPendingUntil", 0]
];

ARTIC_Commanders set [_id, _entry];
_logic setVariable ["ARTIC_registered", true, true];
[format ["Registered commander %1 (%2)", _id, _side], _id] call ARTIC_fnc_debug;
