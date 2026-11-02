/*
    ARTIC v0.3.21 - movement authority watchdog.

    Runs after the individual executor on the machine that owns the group.

    Authority boundary while an ARTIC guide owns infantry movement:
      ARTIC : decision/FSM layer, destinations, formation, reactions, stop/go.
      Arma  : MOVE/PATH, navmesh, obstacle avoidance, locomotion/animation.

    v0.3.21 additionally owns the group-level automatic attack gate.  The 0.3.20
    benchmark proved that seven of eight soldiers in each section were receiving engine
    ATTACK commands while the section commander remained on PLATOON_GUIDE.
*/
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group} || {isPlayer leader _group}) exitWith {};
if !(_group getVariable ["ARTIC_enabled",false]) exitWith {};
if !(missionNamespace getVariable ["ARTIC_controlWatchdog",true]) exitWith {};

private _pm = _group getVariable ["ARTIC_platoonMove",[]];
private _pmFresh = _pm isNotEqualTo [] && {(CBA_missionTime - (_pm select 3)) < 30} && {!(_group getVariable ["ARTIC_platoonTacticalReleased",false])};
private _movementOwner = _group getVariable ["ARTIC_movementOwner","FORMATION"];
private _guide = _group getVariable ["ARTIC_guide",[]];
private _guideVel = _group getVariable ["ARTIC_formVel",0];
private _guideMoving = (_group getVariable ["ARTIC_guideMoving",false]) && {_guideVel > 0.20};
private _articOwned = _pmFresh
    || {_movementOwner in ["PLATOON_GUIDE","TACTICAL_GUIDE","FIRETEAM_GUIDES"]}
    || {_movementOwner isEqualTo "FORMATION" && {_guide isNotEqualTo []}};

private _fit = (units _group) select {
    local _x && {!isPlayer _x} && {[_x] call ARTIC_fnc_isFit}
};

// If ARTIC has released movement ownership, restore only the AI feature ARTIC disabled.
if (!_articOwned) exitWith {
    {
        if (_x getVariable ["ARTIC_fsmDisabledByARTIC",false]) then {
            _x enableAI "FSM";
            _x setVariable ["ARTIC_fsmDisabledByARTIC",false,false];
        };
    } forEach _fit;
    if (_group getVariable ["ARTIC_autoAttackDisabledByARTIC",false]) then {
        _group enableAttack true;
        _group setVariable ["ARTIC_autoAttackDisabledByARTIC",false,false];
    };
};

// v0.3.21: while ARTIC owns section movement, vanilla group target assignment is NOT
// allowed to create ATTACK commands for subordinates.  Arma still owns MOVE/PATH.
_group enableAttack false;
_group setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];

// ARTIC guide movement never uses group waypoints.  Any waypoint is a second movement
// owner (Eden/Zeus/external script/vanilla command) and is removed immediately.
private _wps = waypoints _group;
if (_wps isNotEqualTo []) then {
    private _firstPos = waypointPosition (_wps select 0);
    [format ["CONTROL CONFLICT: removed %1 unexpected group waypoint(s), first=%2 owner=%3",count _wps,mapGridPosition _firstPos,_movementOwner],groupId _group] call ARTIC_fnc_debug;
    [_group] call ARTIC_fnc_clearGroupWaypoints;
};

private _takeFSM = missionNamespace getVariable ["ARTIC_takeInfantryFSMControl",true];
private _movingN = 0;
private _conflictN = 0;
private _stallN = 0;
private _attackConflictN = 0;
private _maxDelta = 0;

{
    private _u = _x;

    // Keep only the engine pieces ARTIC wants underneath its own executor.
    _u enableAI "MOVE";
    _u enableAI "PATH";
    _u disableAI "AUTOCOMBAT";
    if (_takeFSM) then {
        if !(_u getVariable ["ARTIC_fsmDisabledByARTIC",false]) then {
            _u disableAI "FSM";
            _u setVariable ["ARTIC_fsmDisabledByARTIC",true,false];
        };
    } else {
        if (_u getVariable ["ARTIC_fsmDisabledByARTIC",false]) then {
            _u enableAI "FSM";
            _u setVariable ["ARTIC_fsmDisabledByARTIC",false,false];
        };
    };

    private _task = _u getVariable ["ARTIC_unitTask",[]];
    private _type = toUpper (_task param [0,""]);
    private _reaction = _u getVariable ["ARTIC_reactionState",[]];
    private _target = _u getVariable ["ARTIC_formLastTarget",[]];
    if (_target isEqualTo []) then {_target = _u getVariable ["ARTIC_commandedMoveTarget",[]];};

    // FORMATION targets are driven by the section guide. FIRETEAM targets are explicit
    // tactical guide targets. Active survival reactions are never overwritten here.
    private _ownerMoving = _guideMoving || {_type isEqualTo "FIRETEAM"};
    private _canMove = _reaction isEqualTo [] && {_target isNotEqualTo []} && {_ownerMoving};

    private _cmd = currentCommand _u;
    private _exp = expectedDestination _u;
    private _expPos = _exp param [0,[]];
    private _expValid = _expPos isEqualType [] && {(count _expPos) >= 2} && {((abs (_expPos select 0)) + (abs (_expPos select 1))) > 1};
    private _expDelta = if (_expValid && {_target isNotEqualTo []}) then {_expPos distance2D _target} else {-1};
    if (_expDelta > _maxDelta) then {_maxDelta = _expDelta;};

    if (_canMove) then {
        _movingN = _movingN + 1;
        private _dTarget = _u distance2D _target;
        private _lastAssert = _u getVariable ["ARTIC_ctrlLastReassert",-1000];
        private _commandMissing = (!_expValid || {_cmd isEqualTo ""}) && {_dTarget > 3.5};
        private _engineAttack = _cmd isEqualTo "ATTACK";
        // v0.3.22: a destination split only counts as a conflict when the soldier is
        // actually away from his ARTIC target (> 4 m) AND the engine is running a command.
        // With no command (cmd "") the engine reports its own formation position relative
        // to the leader, so a soldier standing exactly on his ARTIC slot used to log a
        // ~20 m "conflict" (0.3.21 RPT: 136 of ~200 conflicts had cmd=""). An idle soldier
        // is handled by _commandMissing below, not treated as a competing owner.
        private _mismatch = _engineAttack || {_expDelta > 18 && {_dTarget > 4} && {_cmd isNotEqualTo ""}};

        // A destination split OR any vanilla ATTACK command is direct evidence of another
        // movement/engagement owner.  During guide movement ATTACK is never an authorised
        // engine command: ARTIC combat tasks use doTarget/doSuppressiveFire explicitly.
        if (_mismatch) then {
            _conflictN = _conflictN + 1;
            if (_engineAttack) then {_attackConflictN = _attackConflictN + 1;};
            private _lastConflictLog = _u getVariable ["ARTIC_ctrlLastConflictLog",-1000];
            if ((time - _lastConflictLog) > 3) then {
                [format ["UNITCTRL CONFLICT unit=%1 role=%2 task=%3 cmd=%4 plan=%9 toTarget=%10m engine=%5 ARTIC=%6 delta=%7m owner=%8 autoAttack=false",
                    name _u,_u getVariable ["ARTIC_formRole","?"],_type,_cmd,
                    if (_expValid) then {mapGridPosition _expPos} else {"NONE"},mapGridPosition _target,
                    if (_expDelta >= 0) then {round _expDelta} else {-1},_movementOwner,_exp param [1,"?"],round _dTarget],groupId _group] call ARTIC_fnc_debug;
                _u setVariable ["ARTIC_ctrlLastConflictLog",time,false];
            };
        };

        // Reassert moving slot ownership continuously. If the engine managed to install an
        // ATTACK command, clear its private target/watch first, then restore the ARTIC slot.
        // v0.3.22: routine re-assertion every 3 s (was 1.6 s: constant doMove restarts
        // pathfinding); conflicts and missing commands are still corrected immediately.
        if ((_mismatch || {_commandMissing} || {(time - _lastAssert) > 3}) && {_dTarget > 2.5}) then {
            if (_engineAttack) then {
                _u doTarget objNull;
                _u doWatch objNull;
            };
            _u setVariable ["ARTIC_formStopped",false,false];
            _u setVariable ["ARTIC_formSettled",false,false];
            _u setVariable ["ARTIC_unitTaskLastIssue",time,false];
            _u forceSpeed (if (_dTarget > 12) then {5} else {(_guideVel + 0.9) max 1.2});
            _u doMove _target;
            _u setVariable ["ARTIC_commandedMoveTarget",+_target,false];
            _u setVariable ["ARTIC_ctrlLastReassert",time,false];
        };

        // Per-soldier physical stall detector.  The commander-only version proved the
        // leaders were healthy; this now identifies a rifleman/medic/etc. that stops
        // moving while his ARTIC slot continues ahead.
        private _nowPos = getPosATL _u;
        private _watchPos = _u getVariable ["ARTIC_ctrlWatchPos",+_nowPos];
        private _lastProgress = _u getVariable ["ARTIC_ctrlLastProgressAt",time];
        if ((_watchPos distance2D _nowPos) > 1.5) then {
            _watchPos = +_nowPos;
            _lastProgress = time;
            _u setVariable ["ARTIC_ctrlWatchPos",_watchPos,false];
            _u setVariable ["ARTIC_ctrlLastProgressAt",_lastProgress,false];
        };
        if (_dTarget > 7 && {(time - _lastProgress) > 6}) then {
            _stallN = _stallN + 1;
            [format ["UNITCTRL STALL unit=%1 role=%2 task=%3 noProgress=%4s target=%5m cmd=%6 expectedDelta=%7",
                name _u,_u getVariable ["ARTIC_formRole","?"],_type,round (time - _lastProgress),round _dTarget,_cmd,
                if (_expDelta >= 0) then {round _expDelta} else {-1}],groupId _group] call ARTIC_fnc_debug;
            _u setVariable ["ARTIC_formStopped",false,false];
            _u setVariable ["ARTIC_formSettled",false,false];
            _u setVariable ["ARTIC_formCatchUp",_dTarget > 12,false];
            _u setVariable ["ARTIC_speedApplied",-99,false];
            _u forceSpeed (if (_dTarget > 12) then {5} else {(_guideVel + 0.9) max 1.2});
            _u doMove _target;
            _u setVariable ["ARTIC_commandedMoveTarget",+_target,false];
            _u setVariable ["ARTIC_ctrlLastReassert",time,false];
            _u setVariable ["ARTIC_ctrlWatchPos",+_nowPos,false];
            _u setVariable ["ARTIC_ctrlLastProgressAt",time,false];
        };
    } else {
        // Reset the physical-stall baseline while intentionally stationary/reacting.
        _u setVariable ["ARTIC_ctrlWatchPos",getPosATL _u,false];
        _u setVariable ["ARTIC_ctrlLastProgressAt",time,false];
    };
} forEach _fit;

// Compact group-level benchmark line. Detailed per-unit lines appear only on conflict
// or stall, so this remains readable with several sections active.
private _nextLog = _group getVariable ["ARTIC_nextMoveAuthLog",0];
if ((missionNamespace getVariable ["ARTIC_debug",false]) && {time >= _nextLog}) then {
    [format ["MOVEAUTH owner=%1 guideVel=%2 leash=%3 units=%4 moving=%5 conflicts=%6 attackCmd=%7 stalls=%8 wp=%9 maxDelta=%10 FSM=%11 autoAttack=false reposition=%12",
        _movementOwner,(round (_guideVel * 10))/10,_group getVariable ["ARTIC_guideLeashMode","?"],count _fit,_movingN,_conflictN,_attackConflictN,_stallN,
        count (waypoints _group),round _maxDelta,_takeFSM,_group getVariable ["ARTIC_repositionForAttack",false]],groupId _group] call ARTIC_fnc_debug;
    _group setVariable ["ARTIC_nextMoveAuthLog",time + 10,false];
};
