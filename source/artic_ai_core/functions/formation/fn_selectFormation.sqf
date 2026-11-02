/*
    ARTIC - choose the section formation from an assessment (v0.3.9).

    Order of rules (first match wins):
      1. CONTACT (developing)  -> LINE facing the enemy: bring every rifle to bear
                                  before the plan shifts to suppress / flank.
      2. HALTED                -> DIAMOND (< 8 fit) / BOX (8+): all-round security.
      3. THREAT ALL-ROUND      -> known threats spread > 120 deg around the section:
                                  BOX_DIAMOND (8+) / DIAMOND.
      4. CONTACT EXPECTED      -> nearest threat < 450 m:
           ahead (+-45 deg)    -> VEE (AGGRESSIVE/SF/CONVENTIONAL) or WEDGE
           on a flank          -> ECHELON toward it
           behind              -> DIAMOND
      5. CONTACT POSSIBLE      -> threat < 900 m: WEDGE (open) / COLUMN (close country)
      6. SAFE                  -> COLUMN if more than 300 m to go (speed) or close
                                  country / the platoon asks for file; else WEDGE.
    Doctrine flavour: MILITIA and INSURGENT don't use BOX / BOX_DIAMOND / ECHELON
    (they fall back to WEDGE / COLUMN); RECON prefers COLUMN and DIAMOND.

    Training hysteresis: a new choice must persist before the section changes to it
    (POOR ~12 s, ELITE ~3 s). Contact LINE is immediate.

    Returns [formation, facingDir (-1 = direction of travel), reason]
*/
params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]],["_travelDir",0,[0]]];

// Tactical plays may temporarily request a formation (for example LINE at the final
// coordination line). It is separate from the mission/test override and is cleared when
// the play finishes.
private _tacticalOverride = _group getVariable ["ARTIC_tacticalFormationOverride",""];
if (_tacticalOverride isNotEqualTo "") exitWith {
    _group setVariable ["ARTIC_formationPending",["",0],false];
    [toUpper _tacticalOverride,-1,"tactical override"]
};

// v0.3.10: test / mission override, e.g. _group setVariable ["ARTIC_formationOverride","BOX"]
// ("" = normal assessment). Used by the formation test harness.
private _override = _group getVariable ["ARTIC_formationOverride",""];
if (_override isNotEqualTo "") exitWith {
    _group setVariable ["ARTIC_formationPending",["",0],false];
    [toUpper _override, -1, "override"]
};
([_group] call ARTIC_fnc_getProfile) params ["_doctrine","","","_training"];
private _coord = _training getOrDefault ["coordination",0.55];
private _leader = leader _group;
private _ref = _group getVariable ["ARTIC_sectionReferencePos",getPosATL _leader];
private _fitCount = {[_x] call ARTIC_fnc_isFit} count units _group;
private _big = _fitCount >= 8;

private _dest = _group getVariable ["ARTIC_sectionDestination",[]];
private _halted = _dest isEqualTo [] || {(_ref distance2D (_dest select 0)) < 15};
private _toGo = if (_dest isEqualTo []) then {0} else {_ref distance2D (_dest select 0)};
private _mp = [_group] call ARTIC_fnc_getMovementProfile;
private _close = (_mp getOrDefault ["terrain","OPEN"]) isEqualTo "CLOSE";
private _pm = _group getVariable ["ARTIC_platoonMove",[]];
private _hint = _pm param [4,""];
private _marchOwned = _pm isNotEqualTo [] && {(CBA_missionTime - (_pm select 3)) < 30} && {!(_group getVariable ["ARTIC_platoonTacticalReleased",false])};
// v0.3.17: shared/UAS intelligence and even long-range visual contact may shape the
// platoon route, but they do not reshape the section while the platoon still owns the
// approach. Contact reactions remain available at individual level; formation changes
// wait until the platoon explicitly releases the section into the tactical play.
if (_marchOwned) exitWith {
    _group setVariable ["ARTIC_formationPending",["",0],false];
    private _mf = if (_hint isEqualTo "FILE") then {"COLUMN"} else {"WEDGE"};
    [_mf,-1,"platoon approach locked"]
};

// threats: own target + shared contact reports
private _threats = [];
if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {_threats pushBack getPosATL _target;};
{
    if ([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget && {(time - (_x select 2)) < 120}) then {_threats pushBack (_x select 1);};
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
private _near = 1e6; private _nearPos = [];
{private _d = _ref distance2D _x; if (_d < _near) then {_near = _d; _nearPos = _x;};} forEach _threats;
private _bearings = (_threats select {(_ref distance2D _x) < 900}) apply {(((_ref getDir _x) - _travelDir) + 360) % 360};
private _spread = 0;
if ((count _bearings) >= 2) then {
    // largest angular gap; spread = 360 - gap
    private _b = +_bearings; _b sort true;
    private _gap = 360 - ((_b select (count _b - 1)) - (_b select 0));
    for "_i" from 1 to (count _b - 1) do {_gap = _gap max ((_b select _i) - (_b select (_i - 1)));};
    _spread = 360 - _gap;
};

// v0.3.14: the crow's foot is the forward-threat formation (two pairs wide toward the
// likely contact, command group in the middle). ARTIC_useCrowsFoot = false restores VEE.
private _fwdForm = ["VEE","CROWS_FOOT"] select (missionNamespace getVariable ["ARTIC_useCrowsFoot",true]);

private _developing = (time < (_group getVariable ["ARTIC_developUntil",0])) || {_group getVariable ["ARTIC_holdContactLine",false]};   // v0.3.25: contact LINE also while holding
private _tacticalGuide = _group getVariable ["ARTIC_tacticalGuideActive",false];
private _pick = switch (true) do {
    case (_developing && {_nearPos isNotEqualTo []}): {["LINE", _ref getDir _nearPos, "contact: develop fire"]};
    // During a tactical guide move, a temporary halt at a phase point must not make the
    // section collapse into an all-round BOX while the enemy is known in front.
    case (_tacticalGuide && {_near < 450}): {
        private _rel = (((_ref getDir _nearPos) - _travelDir) + 360) % 360;
        switch (true) do {
            case (_rel <= 45 || {_rel >= 315}): {[_fwdForm, -1, "tactical: threat ahead"]};
            case (_rel > 45 && {_rel < 135}): {["ECHELON_RIGHT", -1, "tactical: threat right"]};
            case (_rel > 225 && {_rel < 315}): {["ECHELON_LEFT", -1, "tactical: threat left"]};
            default {["DIAMOND", -1, "tactical: threat rear"]};
        }
    };
    case (_halted): {[["DIAMOND","BOX"] select _big, -1, "halted: all-round"]};
    case (_spread > 120): {[["DIAMOND","BOX_DIAMOND"] select _big, -1, "threats all round"]};
    case (_near < 450): {
        private _rel = (((_ref getDir _nearPos) - _travelDir) + 360) % 360;
        switch (true) do {
            case (_rel <= 45 || {_rel >= 315}): {[["WEDGE",_fwdForm] select (_doctrine in ["AGGRESSIVE","SPECIAL_FORCES","CONVENTIONAL"]), -1, "contact expected ahead"]};
            case (_rel > 45 && {_rel < 135}): {["ECHELON_RIGHT", -1, "threat on right flank"]};
            case (_rel > 225 && {_rel < 315}): {["ECHELON_LEFT", -1, "threat on left flank"]};
            default {["DIAMOND", -1, "threat behind"]};
        }
    };
    case (_near < 900): {[["WEDGE","COLUMN"] select _close, -1, "contact possible"]};
    default {
        if (_close || {_toGo > 300} || {_hint isEqualTo "FILE"}) then {["COLUMN", -1, "safe: speed"]} else {["WEDGE", -1, "safe"]}
    };
};

// doctrine flavour
private _f = _pick select 0;
if (_doctrine in ["MILITIA","INSURGENT"]) then {
    if (_f in ["BOX","BOX_DIAMOND","DIAMOND"]) then {_f = ["WEDGE","COLUMN"] select _close;};
    if (_f in ["ECHELON_LEFT","ECHELON_RIGHT","VEE","CROWS_FOOT"]) then {_f = "WEDGE";};
};
if (_doctrine isEqualTo "RECON" && {_f in ["WEDGE","VEE","CROWS_FOOT"]} && {_near > 450}) then {_f = "COLUMN";};
_pick set [0,_f];

// hysteresis (contact LINE is immediate)
private _current = _group getVariable ["ARTIC_formation",""];
if (_f isEqualTo _current || {_developing}) exitWith {
    _group setVariable ["ARTIC_formationPending",["",0],false];
    _pick
};
private _hold = 3 + 12 * (1 - _coord);
private _pending = _group getVariable ["ARTIC_formationPending",["",0]];
if ((_pending select 0) isNotEqualTo _f) then {
    _group setVariable ["ARTIC_formationPending",[_f,time],false];
};
if (_current isEqualTo "" || {(time - ((_group getVariable ["ARTIC_formationPending",["",time]]) select 1)) >= _hold}) exitWith {_pick};
[_current, -1, "holding (change pending)"]
