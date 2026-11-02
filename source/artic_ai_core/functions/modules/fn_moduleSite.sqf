params ["_logic"];
if (!isServer || {isNull _logic}) exitWith {};
private _id = _logic getVariable ["SiteId", format ["SITE_%1", netId _logic]];
private _entry = createHashMapFromArray [
    ["id",_id],["name",_logic getVariable ["SiteName","Site"]],
    ["logic",_logic],["type",toUpper (_logic getVariable ["SiteType","TOWN"])],
    ["strategicValue",(_logic getVariable ["StrategicValue",50]) max 0 min 100],
    ["defensibility",(_logic getVariable ["Defensibility",0.5]) max 0 min 1],
    ["supplyValue",(_logic getVariable ["SupplyValue",0]) max 0 min 100],
    ["radius",(_logic getVariable ["Radius",150]) max 25],
    ["position",getPosATL _logic],["owner",sideUnknown]
];
ARTIC_Sites set [_id,_entry];
_logic setVariable ["ARTIC_registered",true,true];
