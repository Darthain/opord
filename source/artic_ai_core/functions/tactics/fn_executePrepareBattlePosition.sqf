params [
    ["_group",grpNull,[grpNull]],
    ["_center",[],[[]]],
    ["_threat",objNull,[objNull]]
];
if (isNull _group || {_center isEqualTo []} || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

_group setVariable ["ARTIC_currentPlan","PREPARE_BATTLE_POSITION",true];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group enableAttack false;
_group setBehaviourStrong "AWARE";

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _layout = [_group,_center,_threat] call ARTIC_fnc_chooseBattlePositionLayout;
private _builders = +(_caps getOrDefault ["engineer",[]]);
if (_builders isEqualTo []) then {_builders = (_caps getOrDefault ["alive",[]]) select [0,((count (_caps get "alive")) min 4)];};

[format ["Preparing battle position: %1 fighting positions",count _layout],groupId _group] call ARTIC_fnc_debug;

private _constructionSkill = _training getOrDefault ["constructionSkill",0.65];
private _constructionBias = _doctrine getOrDefault ["constructionBias",0];
private _buildTime = 14 + (18 * (1 - _constructionSkill));
private _created = [];
private _useCamo = _tName in ["VETERAN","ELITE"] && {_constructionBias >= 0.6};

{
    _x params ["_pos","_dir"];
    private _builder = if (_builders isEqualTo []) then {leader _group} else {_builders select (_forEachIndex mod count _builders)};
    if (alive _builder && {local _builder}) then {
        _builder disableAI "AUTOCOMBAT";
        _builder doMove _pos;
    };
    sleep (_buildTime / ((count _builders) max 1));

    private _size = if (_forEachIndex isEqualTo 0 && {(_caps getOrDefault ["mg",[]]) isNotEqualTo []}) then {"LONG"} else {"SHORT"};
    private _fp = [_pos,_dir,_size,side _group] call ARTIC_fnc_createFightingPosition;
    if (!isNull _fp) then {
        _created pushBack _fp;
        [_fp,"TRENCH","BATTLE_POSITION",side _group,_group] call ARTIC_fnc_registerObstacle;

        // GRAD terrain camouflage is attached to each prepared fighting position.
        // The adapter safely no-ops when GRAD is not loaded.
        if (_useCamo) then {
            [_pos,_dir,side _group,"TERRAIN",_fp] call ARTIC_fnc_createConcealment;
        };
    };
} forEach _layout;

// Add a Pook support/command net when available. v0.2.1 corrected the actual
// placeable Pook class names; the adapter safely no-ops if the mod is absent.
if (_useCamo) then {
    private _dir = if (isNull _threat) then {getDir leader _group} else {_center getDir getPosATL _threat};
    private _net = [_center,_dir,side _group,"SMALL"] call ARTIC_fnc_createConcealment;
    if (!isNull _net) then {[_net,"CAMONET","CONCEALMENT",side _group,_group] call ARTIC_fnc_registerObstacle;};
};

_group setVariable ["ARTIC_battlePositionObjects",_created,true];
_group setVariable ["ARTIC_battlePositionCenter",_center,true];
_group setVariable ["ARTIC_battlePositionPrepared",true,true];

[_group] call ARTIC_fnc_finishPlan;
true
