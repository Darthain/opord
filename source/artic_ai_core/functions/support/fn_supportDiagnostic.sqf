/*
    Compact support diagnostic. ACE Mk6 range is tested against the mortar
    vehicle and also reports the physical-round fallback envelope.
*/
params [
    ["_support",createHashMap,[createHashMap]],
    ["_commander",createHashMap,[createHashMap]],
    ["_targetPos",[],[[]]],
    ["_wanted","HE",[""]]
];
if ((count _support) isEqualTo 0 || {(count _commander) isEqualTo 0}) exitWith {};

private _logic = _support getOrDefault ["logic",objNull];
private _cmdLogic = _commander getOrDefault ["logic",objNull];
private _cmdId = _commander getOrDefault ["id",""];
private _linkedBySync = !isNull _logic && {!isNull _cmdLogic} && {_logic in (synchronizedObjects _cmdLogic)};
private _linkedById = _cmdId in (_support getOrDefault ["commanderIds",[]]);
private _linked = _linkedBySync || _linkedById;
private _busy = time < (_support getOrDefault ["busyUntil",0]);
private _assets = _support getOrDefault ["assets",[]];
private _assetBits = [];
private _aceAmmoHandling = (!isNil "ace_mk6mortar_useAmmoHandling") && {ace_mk6mortar_useAmmoHandling};
private _wantedUpper = toUpper _wanted;
private _aceRound = if (_wantedUpper isEqualTo "SMOKE") then {"ACE_1Rnd_82mm_Mo_Smoke"} else {"ACE_1Rnd_82mm_Mo_HE"};
private _vanillaEquivalent = if (_wantedUpper isEqualTo "SMOKE") then {"8Rnd_82mm_Mo_Smoke_white"} else {"8Rnd_82mm_Mo_shells"};

{
    private _obj = _x;
    private _veh = if (!isNull _obj && {_obj isKindOf "Man"}) then {vehicle _obj} else {_obj};
    if (isNull _veh) then {
        _assetBits pushBack "NULL";
    } else {
        private _alive = alive _veh;
        private _crewAlive = ({alive _x} count crew _veh);
        private _ammo = if (_alive) then {getArtilleryAmmo [_veh]} else {[]};
        private _rangeAny = false;
        if (_targetPos isNotEqualTo []) then {
            {
                if (_targetPos inRangeOfArtillery [[_veh],_x]) exitWith {_rangeAny = true;};
            } forEach _ammo;
        };

        private _aceCount = 0;
        private _aceRange = false;
        private _aceRangeFallback = false;
        private _gunner = gunner _veh;
        if (_alive && {_aceAmmoHandling} && {!isNull _gunner}) then {
            private _carriers = ((units group _gunner) select {alive _x && {_x distance _veh <= 18}}) + (crew _veh);
            _carriers = _carriers arrayIntersect _carriers;
            {
                _aceCount = _aceCount + ({_x isEqualTo _aceRound} count magazines _x);
            } forEach _carriers;
            if (_targetPos isNotEqualTo []) then {
                _aceRange = _targetPos inRangeOfArtillery [[_veh],_vanillaEquivalent];
                private _d = _veh distance2D _targetPos;
                _aceRangeFallback = _d >= 75 && {_d <= 4200};
            };
        };

        _assetBits pushBack format ["%1 alive=%2 crew=%3 local=%4 owner=%5 ammo=%6 rangeAny=%7 aceHandling=%8 aceRound=%9 aceCount=%10 aceRangeVeh=%11 aceEnvelope=%12 dist=%13m",
            typeOf _veh,_alive,_crewAlive,local _veh,owner _veh,_ammo,_rangeAny,_aceAmmoHandling,_aceRound,_aceCount,_aceRange,_aceRangeFallback,
            if (_targetPos isEqualTo []) then {-1} else {round (_veh distance2D _targetPos)}
        ];
    };
} forEach _assets;

private _linkLabel = format ["linked=%1(sync=%2,id=%3)",_linked,_linkedBySync,_linkedById];
private _requestLabel = format ["request=%1 grid=%2",_wantedUpper,if (_targetPos isEqualTo []) then {"NONE"} else {mapGridPosition _targetPos}];
[format ["SupportDiag %1 cmd=%2 %3 role=%4 busy=%5 assets=%6 %7 :: %8",
    _support getOrDefault ["id","SUPPORT"],_cmdId,_linkLabel,_support getOrDefault ["role",""],_busy,count _assets,_requestLabel,_assetBits joinString " | "
],"SUPPORT"] call ARTIC_fnc_debug;
