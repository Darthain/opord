/*
    Select and execute one artillery/mortar fire mission.

    v0.3.4a hotfix:
    - Removes the outer-scope _confirmed variable that could become undefined
      after the local/remote execution branch in live Arma.
    - Returns the result directly from the locality branch.
    - Keeps ACE Mk6 physical-ammo handling isolated from vanilla artillery.
*/
params [
    ["_support",createHashMap,[createHashMap]],
    ["_targetPos",[],[[]]],
    ["_type","HE",[""]],
    ["_requester",grpNull,[grpNull]]
];
if (!isServer || {(count _support) isEqualTo 0} || {_targetPos isEqualTo []}) exitWith {false};

private _assets = (_support getOrDefault ["assets",[]]) select {!isNull _x && {alive _x}};
if (_assets isEqualTo []) exitWith {false};

private _wanted = toUpper _type;
private _overrideAmmo = _support getOrDefault ["ammoClass",""];
private _selectedVeh = objNull;
private _selectedAmmo = "";
private _selectedAceRound = "";
private _useAceShim = false;
private _aceRoundCount = 0;
private _hadAmmo = false;
private _hadRange = false;
private _aceAmmoHandling = (!isNil "ace_mk6mortar_useAmmoHandling") && {ace_mk6mortar_useAmmoHandling};

private _aceRoundForType = if (_wanted isEqualTo "SMOKE") then {"ACE_1Rnd_82mm_Mo_Smoke"} else {"ACE_1Rnd_82mm_Mo_HE"};
private _vanillaRoundForType = if (_wanted isEqualTo "SMOKE") then {"8Rnd_82mm_Mo_Smoke_white"} else {"8Rnd_82mm_Mo_shells"};

{
    if (isNull _selectedVeh) then {
        private _obj = _x;
        private _veh = if (_obj isKindOf "Man") then {vehicle _obj} else {_obj};
        if (!isNull _veh && {alive _veh}) then {
            private _isMk6 = _veh isKindOf "StaticMortar" || {typeOf _veh in ["O_Mortar_01_F","B_Mortar_01_F","I_Mortar_01_F"]};
            private _useAceForThis = _aceAmmoHandling && {_isMk6};

            if (_useAceForThis) then {
                private _gunner = gunner _veh;
                private _carriers = [];
                if (!isNull _gunner) then {
                    _carriers append ((units group _gunner) select {alive _x && {_x distance _veh <= 18}});
                };
                _carriers append (crew _veh);
                _carriers = _carriers arrayIntersect _carriers;

                private _countRounds = 0;
                {
                    _countRounds = _countRounds + ({_x isEqualTo _aceRoundForType} count magazines _x);
                } forEach _carriers;

                if (_countRounds > 0) then {
                    _hadAmmo = true;

                    // Evaluate range using the MORTAR VEHICLE. ACE physical-ammo
                    // handling can hide the normal artillery magazine until loaded,
                    // so a conservative Mk6 envelope is retained as the fallback.
                    private _rangeOK = _targetPos inRangeOfArtillery [[_veh],_vanillaRoundForType];
                    if (!_rangeOK) then {
                        private _available = getArtilleryAmmo [_veh];
                        {
                            if (_targetPos inRangeOfArtillery [[_veh],_x]) exitWith {_rangeOK = true;};
                        } forEach _available;
                    };
                    if (!_rangeOK) then {
                        private _d = _veh distance2D _targetPos;
                        _rangeOK = _d >= 75 && {_d <= 4200};
                    };

                    if (_rangeOK) then {
                        _hadRange = true;
                        _selectedVeh = _veh;
                        _selectedAmmo = _vanillaRoundForType;
                        _selectedAceRound = _aceRoundForType;
                        _useAceShim = true;
                        _aceRoundCount = _countRounds;
                    };
                };
            } else {
                private _available = getArtilleryAmmo [_veh];
                if (_available isNotEqualTo []) then {
                    _hadAmmo = true;
                    private _ammo = _overrideAmmo;
                    if (_ammo isEqualTo "") then {
                        if (_wanted isEqualTo "SMOKE") then {
                            private _smoke = _available select {
                                private _l = toLower _x;
                                (_l find "smoke" >= 0) || {_l find "wp" >= 0}
                            };
                            _ammo = if (_smoke isNotEqualTo []) then {_smoke select 0} else {""};
                        } else {
                            private _he = _available select {
                                private _l = toLower _x;
                                (_l find "smoke" < 0) &&
                                {_l find "flare" < 0} &&
                                {_l find "illum" < 0} &&
                                {_l find "laser" < 0}
                            };
                            _ammo = if (_he isNotEqualTo []) then {_he select 0} else {_available select 0};
                        };
                    };

                    if (_ammo isNotEqualTo "" && {_ammo in _available}) then {
                        if (_targetPos inRangeOfArtillery [[_veh],_ammo]) then {
                            _hadRange = true;
                            _selectedVeh = _veh;
                            _selectedAmmo = _ammo;
                        };
                    };
                };
            };
        };
    };
} forEach _assets;

if (isNull _selectedVeh) exitWith {
    private _why = if (!_hadAmmo) then {
        if (_aceAmmoHandling) then {"NO_VANILLA_OR_ACE_PHYSICAL_AMMO"} else {"NO_ARTILLERY_AMMO"}
    } else {
        if (!_hadRange) then {"OUT_OF_RANGE_OR_WRONG_AMMO"} else {"NO_VALID_WEAPON"}
    };
    [format ["Support %1 cannot service %2 at %3 (%4)",_support getOrDefault ["id","SUPPORT"],_wanted,mapGridPosition _targetPos,_why],"SUPPORT"] call ARTIC_fnc_debug;
    false
};

private _rounds = round ((_support getOrDefault ["rounds",4]) max 1);
if (_useAceShim) then {_rounds = _rounds min _aceRoundCount;};

// IMPORTANT: return directly from the locality branch. This avoids the live
// engine scope failure seen in v0.3.4 where _confirmed could be undefined at
// the post-branch check even though it had been declared before the branch.
if (local _selectedVeh) exitWith {
    private _ok = [_selectedVeh,_targetPos,_selectedAmmo,_rounds,_useAceShim,_selectedAceRound] call ARTIC_fnc_localArtilleryFire;

    if (_ok) then {
        [format ["%1 fire mission CONFIRMED %2 x%3 at %4 for %5 (mode=%6 physicalRound=%7)",
            _support getOrDefault ["id","SUPPORT"],
            _selectedAmmo,_rounds,mapGridPosition _targetPos,
            if (isNull _requester) then {"unknown"} else {groupId _requester},
            if (_useAceShim) then {"ACE_PHYSICAL_AMMO"} else {"VANILLA_ARTILLERY"},
            _selectedAceRound
        ],"SUPPORT"] call ARTIC_fnc_debug;
    } else {
        [format ["%1 fire mission FAILED: no Fired event from %2",_support getOrDefault ["id","SUPPORT"],typeOf _selectedVeh],"SUPPORT"] call ARTIC_fnc_debug;
    };

    _ok
};

// HC-owned support: dispatch to the machine that owns the mortar. We return
// true here only to acknowledge dispatch; the local executor itself prints the
// real Fired/FIRE_TIMEOUT result on the owner.
[_selectedVeh,_targetPos,_selectedAmmo,_rounds,_useAceShim,_selectedAceRound] remoteExec ["ARTIC_fnc_localArtilleryFire",_selectedVeh];
[format ["%1 fire mission dispatched to weapon owner %2 (%3 x%4 at %5)",
    _support getOrDefault ["id","SUPPORT"],owner _selectedVeh,_selectedAmmo,_rounds,mapGridPosition _targetPos
],"SUPPORT"] call ARTIC_fnc_debug;
true
