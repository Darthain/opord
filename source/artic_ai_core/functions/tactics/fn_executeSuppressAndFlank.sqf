params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]]];
if (isNull _group || {!local _group} || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

private _preSchemeRole = _group getVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO"];
if (_preSchemeRole in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"]) exitWith {
    [_group,_target] call ARTIC_fnc_executePlatoonManoeuvre
};

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
if ((_caps getOrDefault ["strength",0]) < 4) exitWith {false};
private _elements = [_group,_caps] call ARTIC_fnc_assignElements;
private _support = _elements get "support";
private _manoeuvre = _elements get "manoeuvre";
private _reserve = _elements get "reserve";
// Doctrine-informed squad attack: keep the two persistent fireteams intact whenever
// both are viable. The designated base fireteam establishes the base of fire; the
// other fireteam manoeuvres. Generic element splitting remains the fallback for odd
// group sizes / casualties / non-rifle groups.
private _ftA = (_group getVariable ["ARTIC_fireteamMembersA",[]]) select {[_x] call ARTIC_fnc_isFit};
private _ftB = (_group getVariable ["ARTIC_fireteamMembersB",[]]) select {[_x] call ARTIC_fnc_isFit};
if ((count _ftA) >= 2 && {(count _ftB) >= 2}) then {
    private _baseFT = _group getVariable ["ARTIC_baseFireteam","A"];
    _support = if (_baseFT isEqualTo "B") then {+_ftB} else {+_ftA};
    _manoeuvre = if (_baseFT isEqualTo "B") then {+_ftA} else {+_ftB};
    _reserve = (_caps getOrDefault ["alive",[]]) - (_support + _manoeuvre);
};
if (_support isEqualTo [] || {_manoeuvre isEqualTo []}) exitWith {false};

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
_group setVariable ["ARTIC_currentPlan","SUPPRESS_AND_FLANK",true];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group setVariable ["ARTIC_tacticalGuideActive",false,false];
_group setVariable ["ARTIC_movementOwner","FIRETEAM_GUIDES",false];
_group enableAttack false;
_group setBehaviourStrong "COMBAT";
_group setCombatMode "RED";

private _targetPos = getPosATL _target;
private _start = getPosATL leader _group;
private _flankDistance = _training getOrDefault ["flankDistance",110];
private _supportPlan = [_group,_target,_support] call ARTIC_fnc_findSupportPosition;
private _supportPos = _supportPlan getOrDefault ["position",_start];
private _supportLOS = _supportPlan getOrDefault ["los",false];
private _flankPlan = [_group,_target,_flankDistance] call ARTIC_fnc_chooseFlankPlan;
private _flankScore = _flankPlan getOrDefault ["score",0];
private _stage1 = _flankPlan getOrDefault ["stage1",_start];
private _stage2 = _flankPlan getOrDefault ["stage2",_start];
private _side = _flankPlan getOrDefault ["side",1];
private _schemeRole = _group getVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO"];
private _axisLocked = _group getVariable ["ARTIC_axisLocked",false];

private _schemeLabel = format ["role=%1 axisLocked=%2",_schemeRole,_axisLocked];
private _flankLabel = format ["L=%1 R=%2 selected=%3 score=%4",
    (round ((_flankPlan getOrDefault ["leftScore",0]) * 100)) / 100,
    (round ((_flankPlan getOrDefault ["rightScore",0]) * 100)) / 100,
    if (_side < 0) then {"LEFT"} else {"RIGHT"},
    (round (_flankScore * 100)) / 100
];
[format [
    "SUPPRESS_AND_FLANK %1 support=%2 manoeuvre=%3 reserve=%4 | SBF LOS=%5 score=%6 move=%7m | flank %8",
    _schemeLabel,
    count _support,count _manoeuvre,count _reserve,
    _supportLOS,
    round (_supportPlan getOrDefault ["score",0]),
    round (_supportPlan getOrDefault ["moveDistance",0]),
    _flankLabel
],groupId _group] call ARTIC_fnc_debug;

[format ["Selected flank route masking=%1 cover=%2 exposure=%3 (leg1=%4 leg2=%5)",
    (round ((_flankPlan getOrDefault ["hidden",0]) * 100)) / 100,
    (round ((_flankPlan getOrDefault ["cover",0]) * 100)) / 100,
    (round ((_flankPlan getOrDefault ["routeExposure",0]) * 100)) / 100,
    (round ((_flankPlan getOrDefault ["leg1Exposure",0]) * 100)) / 100,
    (round ((_flankPlan getOrDefault ["leg2Exposure",0]) * 100)) / 100
],groupId _group] call ARTIC_fnc_debug;

// Mortar/artillery support is part of the attack plan, not a separate manual system.
[_group,_target,_flankScore,_supportLOS] call ARTIC_fnc_assessAttackSupport;

// Retained reserve does not join the assault automatically. Keep it available for
// casualties, AT threats, or a future commander/platoon decision.
{
    if (alive _x && {local _x}) then {[_x,"HOLD",getPosATL _x,_target,90,5] call ARTIC_fnc_setUnitTask;};
} forEach _reserve;

// First establish a real support-by-fire position with LOS instead of suppressing
// from wherever the section happened to make contact.
private _sbfReady = [_group,_support,_supportPos,_target,50,10,"SBF FIRETEAM",true] call ARTIC_fnc_moveFireteamTactical;
if (!_sbfReady || {!local _group}) exitWith {
    [format ["SBF occupation failed/timeout at %1; preserving %2 axis for reassessment",mapGridPosition _supportPos,_schemeRole],groupId _group] call ARTIC_fnc_debug;
    [_group] call ARTIC_fnc_finishPlan;
    false
};

if !([_supportPos,_target] call ARTIC_fnc_hasLineOfSight) exitWith {
    ["No viable support-by-fire LOS after reposition; attack held for reassessment",groupId _group] call ARTIC_fnc_debug;
    {
        if (alive _x && {local _x}) then {[_x,"HOLD",getPosATL _x,_target,12,5] call ARTIC_fnc_setUnitTask;};
    } forEach (_support + _manoeuvre);
    sleep 8;
    [_group] call ARTIC_fnc_finishPlan;
    false
};

// Validate the soldiers, not just the centre point. If pathfinding or micro-cover
// placed individual support gunners behind terrain, give them one short correction
// before abandoning the attack.
private _supportAlive = _support select {alive _x && {local _x}};
private _needLOS = ceil ((count _supportAlive) * 0.60);
private _losUnits = _supportAlive select {[getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight};
if ((count _losUnits) < _needLOS) then {
    {
        if !([getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight) then {
            private _p = [_supportPos,_target,18,false,true] call ARTIC_fnc_findCoverPosition;
            [_x,"MOVE",_p,_target,14,6] call ARTIC_fnc_setUnitTask;
            [_x] call ARTIC_fnc_individualStep;
        };
    } forEach _supportAlive;
    private _losDeadline = time + 12;
    waitUntil {
        sleep 0.5;
        !local _group || {time > _losDeadline} || {
            ({alive _x && {[getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight}} count _supportAlive) >= _needLOS
        }
    };
    _losUnits = _supportAlive select {alive _x && {[getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight}};
};

[format ["Support-by-fire LOS confirmed %1/%2",count _losUnits,count _supportAlive],groupId _group] call ARTIC_fnc_debug;
if ((count _losUnits) < _needLOS) exitWith {
    ["Insufficient support-team LOS after correction; holding attack for reassessment",groupId _group] call ARTIC_fnc_debug;
    {
        if (alive _x && {local _x}) then {[_x,"HOLD",getPosATL _x,_target,12,5] call ARTIC_fnc_setUnitTask;};
    } forEach (_support + _manoeuvre);
    sleep 8;
    [_group] call ARTIC_fnc_finishPlan;
    false
};

private _sup = [_group,_target,75,_support] spawn ARTIC_fnc_suppressElement;
private _discipline = _training getOrDefault ["suppressionDiscipline",0.6];
private _threshold = 0.22 + (_discipline * 0.42);
private _supDeadline = time + (9 + (_discipline * 10));
waitUntil {
    sleep 0.5;
    !local _group || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)} || {time > _supDeadline} || {(_group getVariable ["ARTIC_suppressionEstimate",0]) >= _threshold}
};

if (!local _group || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)}) exitWith {terminate _sup; [_group] call ARTIC_fnc_finishPlan; false};
private _supp = _group getVariable ["ARTIC_suppressionEstimate",0];
[format ["Support ready; suppression estimate %1 (threshold %2). Manoeuvre commencing",(round (_supp*100))/100,(round (_threshold*100))/100],groupId _group] call ARTIC_fnc_debug;

// If both flank routes are poor, do not blindly send the manoeuvre element across
// exposed terrain. Hold, let fires work, then reassess.
if (_flankScore < 0.26) exitWith {
    [format ["No acceptable flank route (score %1); holding manoeuvre instead of exposed assault",(round (_flankScore*100))/100],groupId _group] call ARTIC_fnc_debug;
    sleep 12;
    terminate _sup;
    [_group] call ARTIC_fnc_finishPlan;
    false
};

private _ok = [_group,_manoeuvre,_stage1,_target,60,12,"MANOEUVRE STAGE1",false] call ARTIC_fnc_moveFireteamTactical;
if (_ok && {local _group}) then {
    _ok = [_group,_manoeuvre,_stage2,_target,65,10,"MANOEUVRE STAGE2",false] call ARTIC_fnc_moveFireteamTactical;
};

if (_ok && {local _group} && {[_target] call ARTIC_fnc_isCombatEffectiveTarget}) then {
    // Make the last covered movement to an assault line before shifting support fire.
    private _assaultBearing = _targetPos getDir _stage2;
    private _assaultStage = _targetPos getPos [55,_assaultBearing];
    _assaultStage = [_assaultStage,_target,14,true] call ARTIC_fnc_findCoverPosition;
    _ok = [_group,_manoeuvre,_assaultStage,_target,50,8,"MANOEUVRE ASSAULT LINE",true] call ARTIC_fnc_moveFireteamTactical;
};

if (_ok && {local _group} && {[_target] call ARTIC_fnc_isCombatEffectiveTarget}) then {
    ["Assault line reached; shifting support fire and assaulting",groupId _group] call ARTIC_fnc_debug;
    terminate _sup;
    {
        if (alive _x && {local _x}) then {[_x,"HOLD",getPosATL _x,_target,25,4] call ARTIC_fnc_setUnitTask;};
    } forEach _support;
    private _rearBearing = _targetPos getDir _stage2;
    private _assaultAnchor = _targetPos getPos [18,_rearBearing];
    private _assaultDir = _assaultAnchor getDir _targetPos;
    _group setVariable ["ARTIC_formationFacingDir",_assaultDir,true];
    _ok = [_group,_manoeuvre,_assaultAnchor,_target,35,7,"MANOEUVRE FINAL ASSAULT",true] call ARTIC_fnc_moveFireteamTactical;
    private _assaultEnd = time + 14;
    waitUntil {sleep 0.5; !local _group || {!([_target] call ARTIC_fnc_isCombatEffectiveTarget)} || {time > _assaultEnd};};
} else {
    terminate _sup;
};

if (local _group) then {
    ["Assault phase complete; consolidating before reassessment",groupId _group] call ARTIC_fnc_debug;
    [_group] call ARTIC_fnc_finishPlan;
};
true
