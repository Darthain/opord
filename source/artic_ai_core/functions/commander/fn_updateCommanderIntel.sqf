/*
    Builds a commander contact picture and pushes recent reports back down to
    sibling groups. v0.3.1 only aggregated upward; groups then selected targets
    from their own leader's targets list, so sections could fight different
    battles with no lateral picture.

    Contact report layout:
      [object,lastKnownPos,time,sourceGroupId,sourceFormationId,confidence,sourceType]
*/
params [["_commander",createHashMap,[createHashMap]]];
if ((count _commander) isEqualTo 0) exitWith {[]};

private _side = _commander get "side";
private _roots = _commander getOrDefault ["orbat",[]];
private _groups = [];
{ _groups append ([_x] call ARTIC_fnc_getFormationGroups); } forEach _roots;
_groups = _groups arrayIntersect _groups;

private _reportMap = createHashMap;

// Preserve fresh last-known reports when a contact temporarily drops out of LOS.
{
    _x params ["_obj","_pos","_t","_source","_formation","_confidence",["_sourceType","GROUND"]];
    if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - _t) < 90}) then {
        private _key = netId _obj;
        if (_key isEqualTo "") then {_key = str _obj;};
        _reportMap set [_key,_x];
    };
} forEach (_commander getOrDefault ["contactReports",[]]);

{
    private _g = _x;
    if (!isNull _g && {alive leader _g}) then {
        private _leader = leader _g;
        private _formation = _g getVariable ["ARTIC_formationId",""];
        private _targets = _leader targets [true,2500];
        {
            private _obj = _x;
            if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {(_side getFriend side _obj) < 0.6}) then {
                private _confidence = (((_leader knowsAbout _obj) / 4) max 0.25) min 1;
                private _key = netId _obj;
                if (_key isEqualTo "") then {_key = str _obj;};
                private _old = _reportMap getOrDefault [_key,[]];
                if (_old isEqualTo [] || {_confidence >= (_old select 5)} || {(time - (_old select 2)) > 10}) then {
                    _reportMap set [_key,[_obj,getPosATL _obj,time,groupId _g,_formation,_confidence,"GROUND"]];
                };
            };
        } forEach _targets;
    };
} forEach _groups;

// UAS contacts are already positively observed by ARTIC's sensor routine. Fold
// them into the same tactical picture without erasing their separate history.
{
    _x params ["_obj","_t"];
    if (([_obj] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - _t) < 180} && {(_side getFriend side _obj) < 0.6}) then {
        private _key = netId _obj;
        if (_key isEqualTo "") then {_key = str _obj;};
        _reportMap set [_key,[_obj,getPosATL _obj,_t,"UAS","",0.95,"UAS"]];
    };
} forEach (_commander getOrDefault ["uasContacts",[]]);

private _reports = [];
{_reports pushBack _y;} forEach _reportMap;
_reports = _reports select {([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - (_x select 2)) < 90}};
_commander set ["contactReports",_reports];
_commander set ["knownEnemies",_reports apply {_x select 0}];

// Lateral dissemination. Ground contacts are shared within the same formation
// (normally the platoon); UAS reports are commander-level and go to every group.
{
    private _g = _x;
    if (!isNull _g && {alive leader _g}) then {
        private _formation = _g getVariable ["ARTIC_formationId",""];
        private _shared = _reports select {
            private _sourceType = _x select 6;
            private _sourceFormation = _x select 4;
            _sourceType isEqualTo "UAS" || {_sourceFormation isEqualTo _formation}
        };
        _g setVariable ["ARTIC_sharedContacts",_shared,true];

        // v0.3.21: shared intelligence remains in ARTIC's own tactical picture.
        // Do NOT `reveal` these contacts to the vanilla group here: engine knowledge
        // can trigger automatic subordinate ATTACK commands even while PLATOON_GUIDE
        // owns movement.  Explicit ARTIC combat tasks seed engine knowledge only at
        // the moment a soldier is actually authorised to engage.

        private _lastCount = _g getVariable ["ARTIC_lastSharedContactCount",-1];
        if (_lastCount isNotEqualTo count _shared) then {
            [format ["Shared tactical picture: %1 contact(s) formation=%2",count _shared,_formation],groupId _g] call ARTIC_fnc_debug;
            _g setVariable ["ARTIC_lastSharedContactCount",count _shared,false];
        };
    };
} forEach _groups;

_reports
