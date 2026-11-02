/*
    Execute an artillery command where the weapon is local.

    Success means a real Fired event was observed. v0.3.3 could log "firing"
    merely because doArtilleryFire had been issued; v0.3.4 does not.
*/
params [
    ["_veh",objNull,[objNull]],
    ["_targetPos",[],[[]]],
    ["_ammo","",[""]],
    ["_rounds",1,[0]],
    ["_aceShim",false,[true]],
    ["_aceRoundClass","",[""]]
];
if (isNull _veh || {!local _veh} || {!alive _veh} || {_targetPos isEqualTo []} || {_ammo isEqualTo ""}) exitWith {false};

private _gunner = gunner _veh;
if (isNull _gunner || {!alive _gunner}) exitWith {false};

private _rangeOK = _targetPos inRangeOfArtillery [[_veh],_ammo];
if (!_rangeOK && {_aceShim} && {_veh isKindOf "StaticMortar"}) then {
    private _d = _veh distance2D _targetPos;
    _rangeOK = _d >= 75 && {_d <= 4200};
};
if (!_rangeOK) exitWith {
    [format ["Local artillery rejected target: %1 is not in range for %2",mapGridPosition _targetPos,_ammo],"SUPPORT"] call ARTIC_fnc_debug;
    false
};

if (!_aceShim) exitWith {
    _veh setVariable ["ARTIC_artilleryShotFired",false,false];
    private _eh = _veh addEventHandler ["Fired",{
        params ["_platform"];
        _platform setVariable ["ARTIC_artilleryShotFired",true,false];
    }];

    _veh doArtilleryFire [_targetPos,_ammo,round (_rounds max 1)];
    private _deadline = time + 12;
    waitUntil {
        sleep 0.2;
        !alive _veh || {_veh getVariable ["ARTIC_artilleryShotFired",false]} || {time > _deadline}
    };
    _veh removeEventHandler ["Fired",_eh];

    private _ok = _veh getVariable ["ARTIC_artilleryShotFired",false];
    if (_ok) then {
        [format ["Artillery Fired event confirmed from %1 using %2",typeOf _veh,_ammo],"SUPPORT"] call ARTIC_fnc_debug;
    } else {
        [format ["Artillery FIRE_TIMEOUT from %1 using %2",typeOf _veh,_ammo],"SUPPORT"] call ARTIC_fnc_debug;
    };
    _ok
};

if (_aceRoundClass isEqualTo "") exitWith {false};

/*
    v0.3.6 ACE Mk6 path (checked against ACE 3.21.2 ace_mk6mortar / ace_csw):
    - ACE redefines mortar_82mm to accept ONLY ACE_1Rnd_82mm_Mo_* rounds, so the round
      loaded and fired must be the ACE class (_aceRoundClass), not the vanilla
      8Rnd_82mm_Mo_* magazine passed in _ammo. Injecting the vanilla magazine could never
      fire.
    - ACE's own AI reload (ace_csw_fnc_ai_reload) runs on get-in and when the tube runs
      dry after a shot, and takes a round from the gunner / nearby friendly supplies. If
      ACE has already loaded a round, ARTIC fires that one and does not remove another
      from inventory, so each shot costs exactly one physical round.
    - v0.3.4/0.3.5 used "unitTurret _gunner", a one-argument use of a two-argument
      command: the whole file failed to compile, so this function never existed at
      runtime.
*/
private _turretPath = (assignedVehicleRole _gunner) param [1, [0]];
if !(_turretPath isEqualType []) then {_turretPath = [0];};
private _requested = round (_rounds max 1);
private _firedCount = 0;
private _abort = false;

for "_shotIndex" from 1 to _requested do {
    if (_abort || {!alive _veh} || {isNull _gunner} || {!alive _gunner}) exitWith {};

    // Is a round already in the tube (ACE auto-reload, or left from a timed-out shot)?
    private _loaded = ((magazinesAllTurrets _veh) findIf {(_x select 0) isEqualTo _aceRoundClass && {(_x select 2) > 0}}) > -1;
    private _carrier = objNull;

    if (!_loaded) then {
        private _carriers = ((units group _gunner) select {alive _x && {_x distance _veh <= 18}}) + (crew _veh);
        _carriers = _carriers arrayIntersect _carriers;
        {
            if (isNull _carrier && {_aceRoundClass in magazines _x}) then {_carrier = _x;};
        } forEach _carriers;
    };

    if (!_loaded && {isNull _carrier}) exitWith {
        [format ["ACE mortar stopped: no physical %1 remains near %2 after %3 confirmed shot(s)",_aceRoundClass,typeOf _veh,_firedCount],"SUPPORT"] call ARTIC_fnc_debug;
    };

    // Inject one ACE round into the tube; the physical round is only removed from the
    // carrier after a real Fired event.
    if (!_loaded) then {
        _veh addMagazineTurret [_aceRoundClass,_turretPath,1];
    };

    _veh setVariable ["ARTIC_aceMortarShotFired",false,false];
    private _eh = _veh addEventHandler ["Fired", {
        params ["_platform"];
        _platform setVariable ["ARTIC_aceMortarShotFired",true,false];
    }];

    _veh doArtilleryFire [_targetPos,_aceRoundClass,1];

    private _deadline = time + 12;
    waitUntil {
        sleep 0.2;
        !alive _veh || {_veh getVariable ["ARTIC_aceMortarShotFired",false]} || {time > _deadline}
    };
    _veh removeEventHandler ["Fired",_eh];

    if (_veh getVariable ["ARTIC_aceMortarShotFired",false]) then {
        if (!isNull _carrier) then {_carrier removeMagazine _aceRoundClass;};
        _firedCount = _firedCount + 1;
        [format ["ACE mortar Fired event %1/%2 confirmed using %3 (%4)",_firedCount,_requested,_aceRoundClass,["round already loaded by ACE","supplied by " + name _carrier] select (!isNull _carrier)],"SUPPORT"] call ARTIC_fnc_debug;
        sleep 3;
    } else {
        // No shot: take back the round ARTIC injected; the physical round is kept.
        if (!isNull _carrier) then {_veh removeMagazineTurret [_aceRoundClass,_turretPath];};
        [format ["ACE mortar FIRE_TIMEOUT on %1 using %2; physical round retained; mission aborted",typeOf _veh,_aceRoundClass],"SUPPORT"] call ARTIC_fnc_debug;
        _abort = true;
    };
};

_firedCount > 0
