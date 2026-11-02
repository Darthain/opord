/*
    ARTIC v0.3.30 - how closely is one section engaged with the enemy right now?
    Server-safe: uses only public group variables (works for HC-owned sections).

    Returns [state, enemyPos, distance]:
      ENGAGED - the section is in direct contact (soldier LOS or being shot at) and its latest
                contact call is within ARTIC_engagedDistance (200 m), or it is reacting to
                effective contact with a live known enemy inside that distance.
      CLOSE   - a live known enemy is within ARTIC_closeContactDistance (100 m) of the section,
                even if nobody has seen him yet (shared / UAS picture).
      NONE    - otherwise.

    Contact-aware replanning treats ENGAGED and CLOSE sections as COMMITTED: they are not
    marched away from the enemy to a new deployment point; the best placed one fixes in place.
*/
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {["NONE",[],1e9]};
private _ref = _group getVariable ["ARTIC_sectionReferencePos",[]];
if (_ref isEqualTo [] || {(count _ref) < 2}) then {_ref = getPosATL leader _group;};
private _engagedD = missionNamespace getVariable ["ARTIC_engagedDistance",200];
private _closeD = missionNamespace getVariable ["ARTIC_closeContactDistance",100];
private _inContact = _group getVariable ["ARTIC_inContact",false];
private _reacting = _group getVariable ["ARTIC_reacting",false];

// latest contact call of this section
private _callP = [];
private _callD = 1e9;
private _call = _group getVariable ["ARTIC_contactCall",[]];
if (_call isNotEqualTo [] && {(CBA_missionTime - (_call select 0)) < 60}) then {
    private _o = _call param [6,objNull];
    if (isNull _o || {[_o] call ARTIC_fnc_isCombatEffectiveTarget}) then {
        _callP = +(_call select 1);
        _callD = _ref distance2D _callP;
    };
};

// nearest live known enemy from the platoon's shared picture
private _nearP = [];
private _nearD = 1e9;
{
    _x params ["_o","_p","_t"];
    if (_p isEqualType [] && {(count _p) >= 2} && {(time - _t) < 120} && {[_o] call ARTIC_fnc_isCombatEffectiveTarget}) then {
        private _d = _ref distance2D _p;
        if (_d < _nearD) then {_nearD = _d; _nearP = +_p;};
    };
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);

if ((_inContact || {_reacting}) && {_callD < _engagedD}) exitWith {["ENGAGED",_callP,_callD]};
if (_reacting && {_nearD < _engagedD}) exitWith {["ENGAGED",_nearP,_nearD]};
if (_nearD < _closeD) exitWith {["CLOSE",_nearP,_nearD]};
if (_callD < _closeD) exitWith {["CLOSE",_callP,_callD]};
["NONE",[],_nearD min _callD]
