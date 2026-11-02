/*
    ARTIC v0.3.25 - section fire control while reacting to contact (contact LINE).

    Runs while the section is developing the situation or holding its contact LINE
    (max 150 s per run; restarted while the hold continues). Every ~3 s:
      - firing positions from cover are (re)assigned every 20 s (fn_assignFirePositions)
      - combat mode RED (engage), engine auto-attack stays off (ARTIC owns movement)
      - MG / autorifle      : suppress the nearest threat position continuously
      - riflemen            : engage a visible enemy (doTarget), otherwise ~half suppress
      - grenadiers          : HE (fn_fireHE) at the threat when 50-350 m away and the enemy
                              is in a group, in a building or not directly visible
                              (15 s per grenadier)
      - AT                  : target enemy vehicles / static weapons within 450 m
      - anyone              : hand grenade at an enemy within 35 m (15 s per soldier)
    Threats: the section's target, shared contacts near it, and its last contact call.
*/
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {};
if (_group getVariable ["ARTIC_reactFireActive",false]) exitWith {};
_group setVariable ["ARTIC_reactFireActive",true,false];
private _start = time;
private _nextPositions = 0;
_group setCombatMode "RED";
["Contact drill: section returning fire from cover (fire control active)",groupId _group] call ARTIC_fnc_debug;

while {
    local _group
    && {time < _start + 150}
    && {(time < (_group getVariable ["ARTIC_developUntil",0])) || {_group getVariable ["ARTIC_holdContactLine",false]}}
} do {
    private _target = [_group] call ARTIC_fnc_findTarget;
    private _threats = [];
    if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {_threats pushBack (getPosATL _target);};
    private _call = _group getVariable ["ARTIC_contactCall",[]];
    if (_call isNotEqualTo [] && {(CBA_missionTime - (_call select 0)) < 120}) then {_threats pushBack (_call select 1);};
    private _anchor = _threats param [0,[]];
    private _vehicles = [];
    {
        _x params ["_o","_p","_t"];
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 120}) then {
            if (_anchor isEqualTo [] || {(_p distance2D _anchor) < 150}) then {
                if ((_threats findIf {(_x distance2D _p) < 8}) < 0) then {_threats pushBack _p;};
                if ((vehicle _o) isNotEqualTo _o) then {_vehicles pushBackUnique (vehicle _o);};
            };
        };
    } forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
    if (_threats isEqualTo []) exitWith {};

    if (time >= _nextPositions) then {
        _nextPositions = time + 20;
        private _n = [_group,_threats] call ARTIC_fnc_assignFirePositions;
        [format ["Contact drill: %1 soldier(s) given firing positions from cover",_n],groupId _group] call ARTIC_fnc_debug;
    };

    private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
    private _mgs = _caps getOrDefault ["mg",[]];
    private _grens = _caps getOrDefault ["grenadier",[]];
    private _ats = _caps getOrDefault ["at",[]];
    {
        private _u = _x;
        if ([_u] call ARTIC_fnc_isFit && {local _u} && {!isPlayer _u} && {(_u getVariable ["ARTIC_reactionState",[]]) isEqualTo []}) then {
            private _near = ([_threats,[],{_x distance2D _u},"ASCEND"] call BIS_fnc_sortBy) select 0;
            private _dNear = _u distance2D _near;
            private _sees = [_target] call ARTIC_fnc_isCombatEffectiveTarget && {[getPosATL _u,_target] call ARTIC_fnc_hasLineOfSight};
            switch (true) do {
                // close enemy: hand grenade
                case (_dNear < 35 && {time > (_u getVariable ["ARTIC_nextGrenade",0])} && {
                    ((magazines _u) findIf {(_x find "HandGrenade") > -1 || {(_x find "MiniGrenade") > -1}}) > -1}): {
                    _u setVariable ["ARTIC_nextGrenade",time + 15,false];
                    private _mz = if (((magazines _u) findIf {(_x find "MiniGrenade") > -1}) > -1 && {((magazines _u) findIf {(_x find "HandGrenade") > -1}) < 0}) then {"MiniGrenadeMuzzle"} else {"HandGrenadeMuzzle"};
                    _u doWatch _near;
                    [_u,_mz] spawn {params ["_u","_mz"]; sleep 1.5; if ([_u] call ARTIC_fnc_isFit) then {_u forceWeaponFire [_mz,_mz];};};
                };
                // AT on vehicles / statics
                case (_u in _ats && {(_vehicles findIf {(_x distance2D _u) < 450}) > -1}): {
                    private _v = ([_vehicles,[],{_x distance2D _u},"ASCEND"] call BIS_fnc_sortBy) select 0;
                    _u reveal [_v,4];
                    _u doTarget _v;
                };
                // grenadier HE at groups / cover / buildings / unseen enemy
                case (_u in _grens && {_dNear > 50} && {_dNear < 350} && {time > (_u getVariable ["ARTIC_nextHE",0])} && {
                    (count _threats) >= 2 || {!_sees} || {(nearestObjects [_near,["House"],10]) isNotEqualTo []}}): {
                    if ([_u,_near] call ARTIC_fnc_fireHE) then {_u setVariable ["ARTIC_nextHE",time + 15,false];} else {_u setVariable ["ARTIC_nextHE",time + 60,false];};
                };
                // MG: continuous suppression
                case (_u in _mgs): {
                    if (_sees) then {_u doTarget _target;} else {_u doSuppressiveFire (AGLToASL (_near vectorAdd [0,0,1]));};
                };
                default {
                    if (_sees) then {
                        _u reveal [_target,4];
                        _u doTarget _target;
                    } else {
                        if (random 1 < 0.5) then {_u doSuppressiveFire (AGLToASL (_near vectorAdd [0,0,1]));};
                    };
                };
            };
        };
    } forEach (units _group);
    sleep 3;
};
_group setVariable ["ARTIC_reactFireActive",false,false];
