params [["_commander",createHashMap,[createHashMap]]];
if (!isServer || {(count _commander) isEqualTo 0}) exitWith {};
if !(_commander getOrDefault ["autoUAS",true]) exitWith {};
if (time < (_commander getOrDefault ["uasPendingUntil",0])) exitWith {};

private _cmdId = _commander get "id";
private _objectiveId = _commander getOrDefault ["currentObjective",""];
private _objective = ARTIC_Objectives getOrDefault [_objectiveId,createHashMap];
private _objPos = if ((count _objective) > 0) then {_objective getOrDefault ["position",[]]} else {[]};
private _objRadius = if ((count _objective) > 0) then {_objective getOrDefault ["radius",250]} else {250};
private _objType = if ((count _objective) > 0) then {_objective getOrDefault ["type",""]} else {""};

private _doctrine = [_commander getOrDefault ["doctrine","CONVENTIONAL"]] call ARTIC_fnc_getDoctrine;
private _trainingName = _commander getOrDefault ["training","REGULAR"];
private _training = [_trainingName] call ARTIC_fnc_getTraining;
private _reconBias = _doctrine getOrDefault ["uasReconBias",0.5];
private _strikeBias = _doctrine getOrDefault ["uasStrikeBias",0.5];
private _uasSkill = _training getOrDefault ["uasSkill",0.55];

private _reports = _commander getOrDefault ["uasContacts",[]];
_reports = _reports select {([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - (_x select 1)) < 180}};
_commander set ["uasContacts",_reports];

private _strikeCandidates = [];
{
    _x params ["_obj","_t"];
    private _score = 10;
    private _mission = "FPV_AP";
    private _cfg = configFile >> "CfgVehicles" >> typeOf _obj;
    private _armor = getNumber (_cfg >> "armor");
    if (_obj isKindOf "Tank" || {_armor >= 120}) then {_score = 100; _mission = "FPV_AT";} else {
        if (_obj isKindOf "LandVehicle" || {_obj isKindOf "StaticWeapon"}) then {_score = 65; _mission = "FPV_AT";} else {_score = 35; _mission = "FPV_AP";};
    };
    if (_objPos isNotEqualTo [] && {_obj distance2D _objPos <= (_objRadius + 600)}) then {_score = _score + 20;};
    _strikeCandidates pushBack [_score,_mission,_obj];
} forEach _reports;

private _lastStrike = _commander getOrDefault ["lastUASStrike",-1000];
private _strikeCooldown = _commander getOrDefault ["uasStrikeCooldown",90];
if (_strikeCandidates isNotEqualTo [] && {(time - _lastStrike) >= _strikeCooldown}) then {
    _strikeCandidates sort false;
    private _best = _strikeCandidates select 0;
    _best params ["_score","_mission","_target"];
    private _provider = [_commander,_mission,getPosATL _target] call ARTIC_fnc_findUASProvider;
    private _lastDbg = _commander getOrDefault ["uasStrikeDebugAt",-1000];
    if (_provider isEqualTo []) then {
        if ((time - _lastDbg) > 120) then {
            [format ["UAS strike candidate %1 score=%2, but no ready %3 provider found (next report in 2 min)",typeOf _target,_score,_mission],_cmdId] call ARTIC_fnc_debug;
            _commander set ["uasStrikeDebugAt",time];
        };
    } else {
        _provider params ["_pg","_entry"];
        private _operator = _entry select 0;
        private _chance = ((_strikeBias * 0.62) + (_uasSkill * 0.38)) min 0.98;
        private _deterministic = (_trainingName in ["VETERAN","ELITE"]) && {_score >= 50};
        if ((time - _lastDbg) > 20) then {
            [format ["UAS strike assessment: %1 score=%2 provider=%3 operator=%4 chance=%5",_mission,_score,groupId _pg,name _operator,(round (_chance*100))/100],_cmdId] call ARTIC_fnc_debug;
            _commander set ["uasStrikeDebugAt",time];
        };
        if (_deterministic || {random 1 < _chance}) exitWith {
            [grpNull,_mission,getPosATL _target,_target,_cmdId] call ARTIC_fnc_requestUAS;
            _commander set ["lastUASStrike",time];
            _commander set ["uasPendingUntil",time + 20];
        };
    };
};

if (_objPos isEqualTo []) exitWith {};
private _lastRecon = _commander getOrDefault ["lastUASRecon",-1000];
private _reconCooldown = _commander getOrDefault ["uasReconCooldown",180];
private _needRecon = (_reports isEqualTo []) || {_objType in ["RECON","SCREEN","RAID"]};
if (_needRecon && {(time - _lastRecon) >= _reconCooldown}) then {
    private _provider = [_commander,"RECON",_objPos] call ARTIC_fnc_findUASProvider;
    private _reconChance = if (_objType isEqualTo "RECON") then {1} else {(_reconBias * 0.70) + (_uasSkill * 0.30)};
    if (_provider isNotEqualTo [] && {random 1 < _reconChance}) then {
        [grpNull,"RECON",_objPos,objNull,_cmdId] call ARTIC_fnc_requestUAS;
        _commander set ["lastUASRecon",time];
        _commander set ["uasPendingUntil",time + 20];
    };
};
