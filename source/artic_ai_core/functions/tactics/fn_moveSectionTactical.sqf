/*
    ARTIC v0.3.13/v0.3.30 - persistent section-guide movement inside a tactical play.

    The old moveElement path issued independent destinations to every soldier and was
    the main source of 100-300 m dispersion during FIX/LEFT/RIGHT execution. This
    routine keeps the section guide + formation slots alive while the play is active.
    Immediate individual danger reactions may still temporarily override a slot.

    Returns true when the section guide and the majority of fit soldiers consolidate.

    v0.3.30:
      - The timeout argument is a MINIMUM. The actual deadline scales with the distance to
        the destination ((25 + d / ARTIC_moveTimeoutPace) s, pace 1.1 m/s, 30..420 s) and is
        extended while the guide keeps closing, up to 1.6 x that value. 0.3.29 used fixed
        65-80 s for 150-290 m legs, so long stages failed by construction (0.3.29 RPT: 23
        MANOEUVRE_ROUTE_FAILED, the first one with no enemy contact at all).
      - Fails early with NO_PROGRESS when the guide has not closed by 4 m for
        ARTIC_moveNoProgressSeconds (40 s).
      - Accepts arrival when the guide has been inside the tolerance for 15 s even if one or
        two soldiers are still off their slots.
      - Optional play identity [planId, taskId, requireArmed]: the move ends at once when the
        play becomes stale (ARTIC_fnc_isPlayStale).
      - Result published as ARTIC_lastMoveResult (OK / TIMEOUT / NO_PROGRESS / ABORTED / LOCALITY).
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_destination",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_timeout",70,[0]],
    ["_tolerance",14,[0]],
    ["_label","TACTICAL",[""]],
    ["_playIdentity",[],[[]]]
];
if (isNull _group || {!local _group} || {_destination isEqualTo []}) exitWith {false};
private _fit = (units _group) select {[_x] call ARTIC_fnc_isFit && {local _x}};
if (_fit isEqualTo []) exitWith {false};
private _moveStarted = time;
private _m = _group getVariable ["ARTIC_metrics",createHashMap];
_m set ["movesAttempted",(_m getOrDefault ["movesAttempted",0]) + 1];
_group setVariable ["ARTIC_metrics",_m,false];

private _ref0 = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];
private _dist0 = _ref0 distance2D _destination;
private _pace = (missionNamespace getVariable ["ARTIC_moveTimeoutPace",1.1]) max 0.3;
private _scaled = ((25 + _dist0 / _pace) max 30) min 420;
private _base = _timeout max _scaled;

_group setVariable ["ARTIC_tacticalGuideActive",true,false];
_group setVariable ["ARTIC_movementOwner","TACTICAL_GUIDE",false];
_group setVariable ["ARTIC_movementPhase","COMBAT",false];
[_group,_destination] call ARTIC_fnc_setSectionDestination;
{
    [_x,"FORMATION",[],_target,(_base * 1.6) + 20,8] call ARTIC_fnc_setUnitTask;
    _x setVariable ["ARTIC_idleTask",false,false];
} forEach _fit;

[format ["%1 guide movement -> %2 (%3m)",_label,mapGridPosition _destination,round ((_group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group]) distance2D _destination)],groupId _group] call ARTIC_fnc_debug;

private _deadline = time + _base;
private _hardCap = time + ((_base * 1.6) min 600);
private _noProgressLimit = missionNamespace getVariable ["ARTIC_moveNoProgressSeconds",40];
private _bestD = _dist0;
private _lastProgress = time;
private _arrivedAt = -1;
private _result = "TIMEOUT";
private _ok = false;
waitUntil {
    sleep 0.5;
    if (!local _group) exitWith {_result = "LOCALITY"; true};
    if (_playIdentity isNotEqualTo [] && {[_group,_playIdentity param [0,""],_playIdentity param [1,""],_playIdentity param [2,true]] call ARTIC_fnc_isPlayStale}) exitWith {_result = "ABORTED"; true};
    private _ref = _group getVariable ["ARTIC_sectionReferencePos",[]];
    if (_ref isEqualTo []) then {
        private _g = _group getVariable ["ARTIC_guide",[]];
        _ref = if (_g isNotEqualTo []) then {+(_g select 0)} else {getPosATL leader _group};
    };
    private _alive = _fit select {[_x] call ARTIC_fnc_isFit};
    // v0.3.14: completion is judged on each soldier's distance from HIS OWN SLOT, scaled by
    // the formation spacing. 0.3.13 also required every soldier within 32 m of the guide,
    // which a column (~45 m) or echelon (~32 m) can never satisfy, so those phases always
    // ran to their timeout.
    private _scale = (_group getVariable ["ARTIC_formSpacing",1]) max 0.65;
    private _nearTol = 14 * _scale;
    private _near = 0;
    private _dists = [];
    {
        private _slot = [_x,_group,false] call ARTIC_fnc_formationSlotWorld;
        if (_slot isNotEqualTo []) then {
            private _d = _x distance2D _slot;
            _dists pushBack _d;
            if (_d <= _nearTol) then {_near = _near + 1;};
        };
    } forEach _alive;
    _dists sort false;
    private _second = if ((count _dists) >= 2) then {_dists select 1} else {_dists param [0,0]};
    private _nA = count _alive;
    private _need = if (_nA isEqualTo 0) then {0} else {((ceil (_nA * 0.85)) min ((_nA - 1) max 1)) max 1};
    private _dNow = _ref distance2D _destination;
    // One straggler is tolerated (second-worst must be within 25 m x scale of his slot).
    _ok = _dNow <= _tolerance && {_near >= _need} && {_second <= 22 * _scale};
    // v0.3.30: guide in place for 15 s counts as arrived even with one or two stragglers
    if (_dNow <= _tolerance) then {
        if (_arrivedAt < 0) then {_arrivedAt = time;};
        if ((time - _arrivedAt) > 15 && {_near >= (ceil (_nA * 0.5))}) then {_ok = true;};
    } else {
        _arrivedAt = -1;
    };
    // v0.3.30: progress watchdog; keep the deadline alive while the guide keeps closing
    if (_dNow < (_bestD - 4)) then {
        _bestD = _dNow;
        _lastProgress = time;
        if (time > (_deadline - 12)) then {_deadline = (_deadline + 12) min _hardCap;};
    };
    if (_ok) exitWith {_result = "OK"; true};
    if (_dNow > _tolerance && {(time - _lastProgress) > _noProgressLimit}) exitWith {_result = "NO_PROGRESS"; true};
    time > _deadline
};
_group setVariable ["ARTIC_lastMoveResult",_result,false];

private _m2 = _group getVariable ["ARTIC_metrics",createHashMap];
_m2 set ["moveSeconds",(_m2 getOrDefault ["moveSeconds",0]) + (time - _moveStarted)];
if (_ok) then {
    _m2 set ["movesCompleted",(_m2 getOrDefault ["movesCompleted",0]) + 1];
} else {
    _m2 set ["movesFailed",(_m2 getOrDefault ["movesFailed",0]) + 1];
};
_group setVariable ["ARTIC_metrics",_m2,false];
if (!_ok && {local _group}) then {
    private _ref = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];
    // v0.3.22: remaining route length vs straight line, to spot urban/terrain detours
    private _gp = (_group getVariable ["ARTIC_guide",[]]) param [0,_ref];
    private _pathLen = 0; private _prev = _gp;
    {_pathLen = _pathLen + (_prev distance2D _x); _prev = _x;} forEach (_group getVariable ["ARTIC_guidePath",[]]);
    if (_pathLen <= 0) then {_pathLen = _gp distance2D _destination;};
    if (_result isNotEqualTo "ABORTED") then {
        [format ["%1 guide movement incomplete (%5 after %6 s, allowed %7 s): ref=%2m from goal, route remaining %3m (straight %4m); holding coherent section for reassessment",_label,round (_ref distance2D _destination),round _pathLen,round (_gp distance2D _destination),_result,round (time - _moveStarted),round _base],groupId _group] call ARTIC_fnc_debug;
    };
};
_ok
