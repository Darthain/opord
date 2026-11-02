params [
    ["_commander",createHashMap,[createHashMap]],
    ["_provider",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_payload","AP",[""]]
];
if (!isServer || {(count _commander) isEqualTo 0} || {_provider isEqualTo []} || {isNull _target}) exitWith {false};
_provider params ["_group","_entry"];
if (isNull _group) exitWith {false};
_entry params ["_operator",["_source","",[""]],["_thermal",false,[true]],["_isBackpack",false,[true]]];
if (isNull _operator) exitWith {false};

private _kind = toUpper _payload;
private _class = [side _group,_kind,_thermal] call ARTIC_fnc_getCrocusClass;
if (_class isEqualTo "") then {_class = [side _group,_kind,false] call ARTIC_fnc_getCrocusClass;};
if (_class isEqualTo "") exitWith {false};

if (_source isNotEqualTo "") then {[_operator,_source,_isBackpack] call ARTIC_fnc_consumeUASItem;};
_operator setVariable ["ARTIC_uasBusyUntil",time + 90,true];

private _training = [_commander getOrDefault ["training","REGULAR"]] call ARTIC_fnc_getTraining;
private _skill = _training getOrDefault ["uasSkill",0.55];
private _speed = if (_kind isEqualTo "AT") then {19 + (5 * _skill)} else {21 + (6 * _skill)};
private _targetPos = getPosATL _target;
private _opPos = getPosATL _operator;
private _launchDir = _operator getDir _target;

/*
    v0.3.3 SAFE LAUNCH
    Crocus is an armed impact UAV. Spawning it only a few metres over the
    operator can cause an immediate collision/detonation and kill the launch
    team. Spawn it well forward and high, make it temporarily invulnerable,
    and disable collision with nearby friendlies until it has established safe
    separation. If it cannot separate, abort rather than arming beside troops.
*/
private _launch = _opPos getPos [22,_launchDir];
_launch set [2,(_opPos select 2) + 18];
private _drone = createVehicle [_class,_launch,[],0,"FLY"];
if (isNull _drone) exitWith {_operator setVariable ["ARTIC_uasBusyUntil",0,true]; false};

_drone allowDamage false;
_drone setDir _launchDir;
_drone setVariable ["ARTIC_uasSafeLaunch",true,true];
_drone setVariable ["ARTIC_uasMission",format ["FPV_%1",_kind],true];
_drone setVariable ["ARTIC_uasCommander",_commander get "id",true];

private _launchFriendlies = allUnits select {
    alive _x &&
    {(side _group) getFriend (side _x) >= 0.6} &&
    {_x distance2D _operator < 40}
};
{
    _drone disableCollisionWith _x;
} forEach _launchFriendlies;

private _droneGroup = createVehicleCrew _drone;
_drone engineOn true;
_drone setVelocityModelSpace [0,12,3];

[format ["FPV_%1 safe-launched by %2 at %3m separation; damage inhibited during launch",_kind,name _operator,round (_drone distance _operator)],_commander get "id"] call ARTIC_fnc_debug;

// Give the aircraft a few seconds to establish safe separation before arming.
private _safeEnd = time + 6;
waitUntil {
    sleep 0.2;
    !alive _drone || {!alive _operator} || {(_drone distance _operator) > 28} || {time > _safeEnd}
};

if (!alive _drone) exitWith {
    _operator setVariable ["ARTIC_uasBusyUntil",time + 20,true];
    false
};

if ((_drone distance _operator) < 16) exitWith {
    [format ["FPV_%1 launch aborted: safe separation not achieved (%2m)",_kind,round (_drone distance _operator)],_commander get "id"] call ARTIC_fnc_debug;
    deleteVehicleCrew _drone;
    deleteVehicle _drone;
    _operator setVariable ["ARTIC_uasBusyUntil",time + 20,true];
    false
};

_drone setDamage 0;
_drone allowDamage true;
_drone setVariable ["ARTIC_uasSafeLaunch",false,true];
{
    if (!isNull _x) then {_drone enableCollisionWith _x;};
} forEach _launchFriendlies;

[format ["FPV_%1 armed/released at %2m from operator",_kind,round (_drone distance _operator)],_commander get "id"] call ARTIC_fnc_debug;

private _launchPos = getPosATL _drone;
private _dirToTarget = _launchPos getDir _targetPos;
private _stage = _targetPos getPos [120 + (70 * (1 - _skill)),_dirToTarget + 180];
_stage set [2,35 + (20 * _skill)];

[format ["FPV_%1 transit stage %2m from target",_kind,round (_stage distance2D _targetPos)],_commander get "id"] call ARTIC_fnc_debug;

// Phase 1: Crocus/Arma owns stable transit.
if (!isNull _droneGroup) then {
    _drone flyInHeight (35 + (20 * _skill));
    private _wp = _droneGroup addWaypoint [_stage,0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCompletionRadius 35;
};

private _transitEnd = time + 70;
waitUntil {
    sleep 0.5;
    !alive _drone || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)} || {time > _transitEnd} || {_drone distance2D _stage < 55}
};

if (!alive _drone || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)}) exitWith {
    if (alive _drone) then {deleteVehicleCrew _drone; deleteVehicle _drone;};
    _operator setVariable ["ARTIC_uasBusyUntil",time + 20,true];
    false
};

// Phase 2: remove the AI/autopilot before ARTIC takes terminal guidance.
deleteVehicleCrew _drone;
[format ["FPV_%1 terminal guidance started at %2m",_kind,round (_drone distance2D _target)],_commander get "id"] call ARTIC_fnc_debug;

private _end = time + 45;
private _lastDist = 1e9;
while {alive _drone && {[_target] call ARTIC_fnc_isCombatEffectiveTarget} && {time < _end}} do {
    private _origin = getPosASL _drone;
    private _aim = getPosASL _target;
    _aim set [2,(_aim select 2) + (if (_target isKindOf "Man") then {0.8} else {1.2})];
    private _vdir = _origin vectorFromTo _aim;
    private _vlat = vectorNormalized (_vdir vectorCrossProduct [0,0,1]);
    private _vup = _vlat vectorCrossProduct _vdir;
    _drone setVectorDirAndUp [_vdir,_vup];
    _drone setVelocity (_vdir vectorMultiply _speed);

    private _d = _drone distance _target;
    if (_d < (if (_kind isEqualTo "AT") then {3.0} else {4.5})) exitWith {_drone setDamage 1;};
    if (_d > _lastDist && {_lastDist < 7}) exitWith {_drone setDamage 1;};
    _lastDist = _d;
    sleep 0.08;
};

private _targetStillEffective = [_target] call ARTIC_fnc_isCombatEffectiveTarget;
if (alive _drone) then {deleteVehicle _drone;};
_operator setVariable ["ARTIC_uasBusyUntil",time + 45,true];
if (!_targetStillEffective) exitWith {
    [format ["FPV_%1 mission aborted: target became incapacitated/non-combat-effective",_kind],_commander get "id"] call ARTIC_fnc_debug;
    false
};
[format ["FPV_%1 mission completed against %2",_kind,typeOf _target],_commander get "id"] call ARTIC_fnc_debug;
true
