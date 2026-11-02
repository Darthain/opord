params [
    ["_commander",createHashMap,[createHashMap]],
    ["_provider",[],[[]]],
    ["_searchPos",[],[[]]],
    ["_radius",350,[0]]
];
if (!isServer || {(count _commander) isEqualTo 0} || {_provider isEqualTo []} || {_searchPos isEqualTo []}) exitWith {false};
_provider params ["_group","_entry"];
if (isNull _group) exitWith {false};
_entry params ["_operator",["_source","",[""]],["_thermal",false,[true]],["_isBackpack",false,[true]]];
if (isNull _operator) exitWith {false};

private _class = "";
private _u = [_operator] call ARTIC_fnc_scanUnitUASCapabilities;
_class = _u getOrDefault ["reconClass",""];
if (_class isEqualTo "") then {
    _class = switch (side _group) do {case west:{"B_UAV_01_F"};case east:{"O_UAV_01_F"};case resistance:{"I_UAV_01_F"};default{""};};
};
if (_class isEqualTo "" || {!(isClass (configFile >> "CfgVehicles" >> _class))}) exitWith {false};

_operator setVariable ["ARTIC_uasBusyUntil",time + 120,true];
private _launch = (getPosATL _operator) vectorAdd [0,0,1.5];
private _drone = createVehicle [_class,_launch,[],0,"NONE"];
if (isNull _drone) exitWith {_operator setVariable ["ARTIC_uasBusyUntil",0,true]; false};
private _droneGroup = createVehicleCrew _drone;
_drone engineOn true;
_drone setVariable ["ARTIC_uasMission","RECON",true];
_drone setVariable ["ARTIC_uasCommander",_commander get "id",true];

private _training = [_commander getOrDefault ["training","REGULAR"]] call ARTIC_fnc_getTraining;
private _skill = _training getOrDefault ["uasSkill",0.55];
private _scanRadius = (_radius * (0.7 + (0.5 * _skill))) max 220 min 650;
private _alt = 65 + (35 * _skill);
_drone flyInHeight _alt;

private _wp = _droneGroup addWaypoint [_searchPos,0];
_wp setWaypointType "MOVE";
_wp setWaypointSpeed "NORMAL";
_wp setWaypointBehaviour "CARELESS";
_wp setWaypointCompletionRadius 80;

private _deadline = time + 150;
waitUntil {sleep 1; !alive _drone || {time > _deadline} || {_drone distance2D _searchPos < 120}};
if (!alive _drone) exitWith {_operator setVariable ["ARTIC_uasBusyUntil",time + 30,true]; false};

private _contacts = [];
private _side = _commander get "side";
private _end = time + (35 + 35 * _skill);
private _phase = 0;
while {alive _drone && {time < _end}} do {
    private _orbit = _searchPos getPos [120 + (80 * _skill),_phase];
    private _owp = _droneGroup addWaypoint [_orbit,0];
    _owp setWaypointType "MOVE";
    _owp setWaypointSpeed "LIMITED";
    _owp setWaypointBehaviour "CARELESS";
    _owp setWaypointCompletionRadius 60;
    _phase = (_phase + 90) mod 360;

    private _near = _drone nearEntities [["Man","LandVehicle","StaticWeapon"],_scanRadius];
    {
        if (alive _x && {(_side getFriend side _x) < 0.6}) then {
            private _from = getPosASL _drone;
            private _to = eyePos _x;
            if !(lineIntersects [_from,_to,_drone,_x]) then {_contacts pushBackUnique _x;};
        };
    } forEach _near;
    sleep 5;
};

[_commander get "id",_contacts,_drone] call ARTIC_fnc_reportUASContacts;

// Return/recover is abstracted in this alpha. A surviving recon drone returns to its operator and is removed.
private _returnWp = _droneGroup addWaypoint [getPosATL _operator,0];
_returnWp setWaypointType "MOVE";
_returnWp setWaypointSpeed "NORMAL";
_returnWp setWaypointCompletionRadius 50;
private _returnDeadline = time + 120;
waitUntil {sleep 1; !alive _drone || {time > _returnDeadline} || {_drone distance2D _operator < 70}};
if (alive _drone) then {deleteVehicleCrew _drone; deleteVehicle _drone;};
_operator setVariable ["ARTIC_uasBusyUntil",time + 30,true];
true
