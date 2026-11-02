/*
    ARTIC AI v0.3.27-alpha - platoon scheme-of-manoeuvre selection.

    The planner chooses a TACTIC as well as an axis.  Support/manoeuvre is preferred when
    a credible SBF and usable manoeuvre approaches exist.  If the terrain denies useful
    support-by-fire, ARTIC can instead synchronize a double or single envelopment.

    Reassessment deliberately avoids immediately retrying the tactic that just failed.

    v0.3.30:
      - contactFix: a section of the platoon is engaged with / close to the enemy and has been
        made the FIX element where it stands. The platoon fights from contact: SUPPORT_MANOEUVRE
        (reason CONTACT_FIX_IN_PLACE) whenever at least one flank route is usable.
      - retrySame: the last failure was a TIMING failure (an element was late, the plan was
        sound) and this scheme has not already been retried. The same scheme is kept if it is
        still feasible (reason RETRY_AFTER_TIMING_<failure>).
*/
params [
    ["_groups",[],[[]]],
    ["_assessment",createHashMap,[createHashMap]],
    ["_fixValid",false,[false]],
    ["_fixCoverage",0,[0]],
    ["_fixUseful",0,[0]],
    ["_failureReason","",[""]],
    ["_previousScheme","",[""]],
    ["_leftRouteOK",true,[true]],
    ["_rightRouteOK",true,[true]],
    ["_leftRouteScore",0,[0]],
    ["_rightRouteScore",0,[0]],
    ["_contactFix",false,[false]],
    ["_retrySame",false,[false]]
];
private _line = _groups select {([_x] call ARTIC_fnc_scanGroupCapabilities) getOrDefault ["strength",0] >= 4};
private _n = count _line;
private _ratio = _assessment getOrDefault ["forceRatio",1];
private _allowed = _assessment getOrDefault ["assaultAllowed",false];
private _failure = toUpper _failureReason;
private _prev = toUpper _previousScheme;
private _mode = "HOLD";
private _reason = "NO_ASSAULT_AUTHORITY";
private _flankSide = 0;

if (_leftRouteOK || {_rightRouteOK}) then {
    _flankSide = if (_leftRouteOK && {_rightRouteOK}) then {
        if (_leftRouteScore >= _rightRouteScore) then {-1} else {1}
    } else {
        if (_leftRouteOK) then {-1} else {1}
    };
};

if (_allowed) then {
    private _fixFailure = (_failure find "FIX_") isEqualTo 0;
    private _manFailure = (_failure find "MANOEUVRE_") isEqualTo 0;
    private _blockFailure = (_failure find "BLOCK_") isEqualTo 0;
    private _bothFlanks = _leftRouteOK && {_rightRouteOK};
    private _oneFlank = _leftRouteOK || {_rightRouteOK};

    private _feasible = {
        params ["_m"];
        switch (_m) do {
            case "SUPPORT_MANOEUVRE": {_fixValid && {_oneFlank}};
            case "DOUBLE_ENVELOPMENT": {_bothFlanks && {_n >= 3}};
            case "SINGLE_ENVELOPMENT": {_oneFlank && {_n >= 2}};
            default {false};
        }
    };
    // v0.3.30: fight from contact first, then retry a sound plan that was only late.
    if (_contactFix && {_oneFlank} && {_n >= 2}) exitWith {
        _mode = "SUPPORT_MANOEUVRE";
        _reason = "CONTACT_FIX_IN_PLACE";
    };
    if (_retrySame && {[_prev] call _feasible}) exitWith {
        _mode = _prev;
        _reason = format ["RETRY_AFTER_TIMING_%1",_failure];
    };
    // Explicit tactic-change paths after failure.  Do not immediately retry the same play.
    if ((_fixFailure || {_prev isEqualTo "SUPPORT_MANOEUVRE" && {_failure isNotEqualTo ""}})
        && {_n >= 3} && {_bothFlanks} && {_ratio >= 0.95}) then {
        _mode = "DOUBLE_ENVELOPMENT";
        _reason = format ["REASSESS_SUPPORT_FAILURE_%1",_failure];
    } else {
        if (_prev isEqualTo "DOUBLE_ENVELOPMENT" && {_manFailure || {_blockFailure}}) then {
            if (_fixValid && {_oneFlank}) then {
                _mode = "SUPPORT_MANOEUVRE";
                _reason = format ["REASSESS_DOUBLE_FAILURE_TO_SUPPORT_%1",_failure];
            } else {
                if (_oneFlank && {_n >= 2} && {_ratio >= 1.05}) then {
                    _mode = "SINGLE_ENVELOPMENT";
                    _reason = format ["REASSESS_DOUBLE_FAILURE_TO_SINGLE_%1",_failure];
                };
            };
        } else {
            if (_prev isEqualTo "SINGLE_ENVELOPMENT" && {_manFailure || {_blockFailure}}) then {
                if (_fixValid && {_oneFlank}) then {
                    _mode = "SUPPORT_MANOEUVRE";
                    _reason = format ["REASSESS_SINGLE_FAILURE_TO_SUPPORT_%1",_failure];
                } else {
                    if (_bothFlanks && {_n >= 3} && {_ratio >= 1.05}) then {
                        _mode = "DOUBLE_ENVELOPMENT";
                        _reason = format ["REASSESS_SINGLE_FAILURE_TO_DOUBLE_%1",_failure];
                    };
                };
            } else {
                // Normal initial selection.
                if (_fixValid && {_oneFlank}) then {
                    _mode = "SUPPORT_MANOEUVRE";
                    _reason = format ["SBF_%1%%_%2PTS",round (_fixCoverage * 100),_fixUseful];
                } else {
                    if (_bothFlanks && {_n >= 3} && {_ratio >= 1.05}) then {
                        _mode = "DOUBLE_ENVELOPMENT";
                        _reason = "NO_CREDIBLE_SBF_TWO_SAFE_AXES";
                    } else {
                        if (_oneFlank && {_n >= 2} && {_ratio >= 1.20}) then {
                            _mode = "SINGLE_ENVELOPMENT";
                            _reason = "ONE_SAFE_FLANK_AVAILABLE";
                        } else {
                            _mode = "HOLD";
                            _reason = "NO_SAFE_TACTICAL_APPROACH";
                        };
                    };
                };
            };
        };
    };
};

createHashMapFromArray [
    ["mode",_mode],
    ["reason",_reason],
    ["lineGroups",_n],
    ["forceRatio",_ratio],
    ["requiresFix",_mode isEqualTo "SUPPORT_MANOEUVRE"],
    ["synchronized",_mode in ["SUPPORT_MANOEUVRE","DOUBLE_ENVELOPMENT","SINGLE_ENVELOPMENT"]],
    ["leftRouteOK",_leftRouteOK],
    ["rightRouteOK",_rightRouteOK],
    ["flankSide",_flankSide]
]
