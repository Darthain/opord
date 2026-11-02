/*
    Convert recent intelligence into persistent commander battlefield records.
    A battlefield is an area of concentrated hostile activity that planning can
    prepare for before direct contact. UAS reports are high-confidence triggers,
    but ground reports can refresh an already known field.
*/
params [
    ["_commander",createHashMap,[createHashMap]],
    ["_contacts",[],[[]]],
    ["_source","GROUND",[""]]
];
if (!isServer || {(count _commander) isEqualTo 0}) exitWith {[]};
private _side = _commander get "side";
private _objs = _contacts select {
    [_x] call ARTIC_fnc_isCombatEffectiveTarget && {(_side getFriend side _x) < 0.6}
};
_objs = _objs arrayIntersect _objs;
if ((count _objs) < 2) exitWith {[]};

// Greedy proximity clustering. This is intentionally cheap: it runs on commander
// updates, not every frame. A 280 m linkage keeps one defensive locality together
// without merging unrelated fights across a town.
private _clusters = [];
{
    private _o = _x;
    private _p = getPosATL _o;
    private _best = -1;
    private _bestD = 1e9;
    {
        private _members = _x;
        private _sx = 0; private _sy = 0;
        {private _q = getPosATL _x; _sx = _sx + (_q select 0); _sy = _sy + (_q select 1);} forEach _members;
        private _c = [_sx / count _members,_sy / count _members,0];
        private _d = _p distance2D _c;
        if (_d < 280 && {_d < _bestD}) then {_best = _forEachIndex; _bestD = _d;};
    } forEach _clusters;
    if (_best < 0) then {_clusters pushBack [_o]} else {(_clusters select _best) pushBackUnique _o;};
} forEach _objs;

private _ids = [];
private _cmdId = _commander getOrDefault ["id","CMD"];
private _existingIds = _commander getOrDefault ["battlefieldIds",[]];
{
    private _members = _x;
    if ((count _members) >= 2) then {
        private _sx = 0; private _sy = 0;
        {private _p = getPosATL _x; _sx = _sx + (_p select 0); _sy = _sy + (_p select 1);} forEach _members;
        private _centre = [_sx / count _members,_sy / count _members,0];
        private _radius = 70;
        {_radius = _radius max (_centre distance2D _x);} forEach _members;
        _radius = (_radius + 55) min 360;

        private _match = "";
        {
            private _bf = ARTIC_Battlefields getOrDefault [_x,createHashMap];
            if ((count _bf) > 0 && {(_bf getOrDefault ["commanderId",""]) isEqualTo _cmdId} && {((_bf getOrDefault ["centre",[0,0,0]]) distance2D _centre) < 220}) exitWith {_match = _x;};
        } forEach _existingIds;
        private _id = if (_match isEqualTo "") then {
            format ["BF_%1_%2_%3",_cmdId,mapGridPosition _centre,round time]
        } else {_match};

        private _inf = 0; private _veh = 0; private _arm = 0; private _static = 0; private _air = 0;
        {
            private _o = _x;
            if (_o isKindOf "CAManBase") then {_inf = _inf + 1} else {
                if (_o isKindOf "Air") then {_air = _air + 1} else {
                    if (_o isKindOf "Tank") then {_arm = _arm + 1} else {
                        if (_o isKindOf "StaticWeapon") then {_static = _static + 1} else {
                            if (_o isKindOf "LandVehicle") then {_veh = _veh + 1};
                        };
                    };
                };
            };
        } forEach _members;
        private _size = switch (true) do {
            case ((count _members) <= 4): {"TEAM"};
            case ((count _members) <= 12): {"SECTION"};
            case ((count _members) <= 40): {"PLATOON"};
            case ((count _members) <= 120): {"COMPANY"};
            default {"BATTALION_PLUS"};
        };
        private _old = ARTIC_Battlefields getOrDefault [_id,createHashMap];
        private _oldCount = _old getOrDefault ["contactCount",-1];
        private _sourceUse = toUpper _source;
        private _confUse = if (_sourceUse isEqualTo "UAS") then {0.95} else {0.72};
        if ((count _old) > 0 && {(_old getOrDefault ["confidence",0]) > _confUse} && {(time - (_old getOrDefault ["lastUpdated",-1e6])) < 180}) then {
            _sourceUse = _old getOrDefault ["source",_sourceUse];
            _confUse = _old getOrDefault ["confidence",_confUse];
        };
        private _contactTracks = _members apply {[_x,getPosATL _x,time]};
        private _bf = createHashMapFromArray [
            ["id",_id],["commanderId",_cmdId],["side",_side],["centre",_centre],["radius",_radius],
            ["contacts",+_members],["contactTracks",_contactTracks],["contactCount",count _members],["enemySize",_size],
            ["enemyInfantry",_inf],["enemyVehicles",_veh],["enemyArmour",_arm],["enemyStatic",_static],["enemyAir",_air],
            ["source",_sourceUse],["confidence",_confUse],
            ["lastUpdated",time]
        ];
        ARTIC_Battlefields set [_id,_bf];
        _ids pushBackUnique _id;
        if (_oldCount isNotEqualTo count _members) then {
            [format ["Battlefield %1 classified from %2: %3 contact(s), %4, radius %5m at %6",_id,toUpper _source,count _members,_size,round _radius,mapGridPosition _centre],_cmdId] call ARTIC_fnc_debug;
        };
    };
} forEach _clusters;

// Preserve other fresh fields owned by this commander.
{
    private _bf = ARTIC_Battlefields getOrDefault [_x,createHashMap];
    if ((count _bf) > 0 && {(time - (_bf getOrDefault ["lastUpdated",-1e6])) < 300}) then {_ids pushBackUnique _x;};
} forEach _existingIds;
_commander set ["battlefieldIds",_ids];
_ids
