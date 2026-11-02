if (!isServer) exitWith {};

{
    private _commander = _y;
    private _cmdId = _commander getOrDefault ["id",""];
    private _cmdLogic = _commander getOrDefault ["logic",objNull];
    private _roots = _commander getOrDefault ["orbat",[]];
    private _groups = [];
    {_groups append ([_x] call ARTIC_fnc_getFormationGroups);} forEach _roots;
    _groups = _groups arrayIntersect _groups;

    {
        private _g = _x;
        private _req = _g getVariable ["ARTIC_supportRequest",[]];
        if (_req isNotEqualTo []) then {
            _req params ["_type","_pos","_requestTime"];
            if ((time - _requestTime) >= 120) then {
                [format ["Support request %1 at %2 expired after 120s",_type,mapGridPosition _pos],groupId _g] call ARTIC_fnc_debug;
                _g setVariable ["ARTIC_supportRequest",[],true];
            } else {
                private _candidates = [];
                private _relevant = [];

                {
                    private _asset = _y;
                    private _logic = _asset getOrDefault ["logic",objNull];
                    private _role = _asset getOrDefault ["role",""];
                    private _linkedBySync = !isNull _logic && {!isNull _cmdLogic} && {_logic in (synchronizedObjects _cmdLogic)};
                    private _linkedById = _cmdId in (_asset getOrDefault ["commanderIds",[]]);
                    private _linked = _linkedBySync || _linkedById;

                    if (_linked && {_role in ["MORTAR","ARTILLERY","FIRES"]}) then {
                        _relevant pushBack _asset;
                        private _readyTime = time >= (_asset getOrDefault ["busyUntil",0]);
                        private _assetsAlive = (_asset getOrDefault ["assets",[]]) select {!isNull _x && {alive _x}};
                        if (_readyTime && {_assetsAlive isNotEqualTo []}) then {
                            // Do not reject on getArtilleryAmmo here. v0.3.1 could
                            // collapse every ammo/crew/range failure into "no ready
                            // mortar". executeFireMission owns exact validation and
                            // produces an explicit rejection reason.
                            _candidates pushBack [_asset getOrDefault ["priority",50],_asset];
                        };
                    };
                } forEach ARTIC_SupportAssets;

                if (_candidates isNotEqualTo []) then {
                    _candidates sort false;
                    private _fired = false;
                    private _usedAsset = createHashMap;
                    {
                        if (!_fired) then {
                            private _asset = _x select 1;
                            if ([_asset,_pos,_type,_g] call ARTIC_fnc_executeFireMission) then {
                                _fired = true;
                                _usedAsset = _asset;
                            };
                        };
                    } forEach _candidates;

                    if (_fired) then {
                        _usedAsset set ["busyUntil",time + 45];
                        // De-duplicate near-identical section requests against the same target area.
                        {
                            private _r2 = _x getVariable ["ARTIC_supportRequest",[]];
                            if (_r2 isNotEqualTo []) then {
                                _r2 params ["_t2","_p2","_tm2"];
                                if (_t2 isEqualTo _type && {_p2 distance2D _pos < 100}) then {
                                    _x setVariable ["ARTIC_supportRequest",[],true];
                                };
                            };
                        } forEach _groups;
                    } else {
                        private _lastDbg = _g getVariable ["ARTIC_supportNoAssetDebug",-1000];
                        if ((time - _lastDbg) > 20) then {
                            [format ["Registered fire-support asset(s) could not service %1 at %2; diagnostics follow",_type,mapGridPosition _pos],groupId _g] call ARTIC_fnc_debug;
                            {[_x,_commander,_pos,_type] call ARTIC_fnc_supportDiagnostic;} forEach _relevant;
                            _g setVariable ["ARTIC_supportNoAssetDebug",time,false];
                        };
                    };
                } else {
                    private _lastDbg = _g getVariable ["ARTIC_supportNoAssetDebug",-1000];
                    // v0.3.22: with no linked asset at all, stop this section requesting for
                    // 3 min and log once per 3 min instead of every 20 s.
                    if (_relevant isEqualTo []) then {
                        _g setVariable ["ARTIC_supportUnavailableUntil",time + 180,true];
                        _g setVariable ["ARTIC_supportRequest",[],true];
                    };
                    if ((time - _lastDbg) > ([20,180] select (_relevant isEqualTo []))) then {
                        if (_relevant isEqualTo []) then {
                            [format ["No commander-linked mortar/artillery support module for %1 request at %2",_type,mapGridPosition _pos],groupId _g] call ARTIC_fnc_debug;
                            // If modules exist but are not linked, print them too; this catches Eden sync errors.
                            {[_y,_commander,_pos,_type] call ARTIC_fnc_supportDiagnostic;} forEach ARTIC_SupportAssets;
                        } else {
                            [format ["All linked fire-support assets are busy/dead for %1 request at %2; diagnostics follow",_type,mapGridPosition _pos],groupId _g] call ARTIC_fnc_debug;
                            {[_x,_commander,_pos,_type] call ARTIC_fnc_supportDiagnostic;} forEach _relevant;
                        };
                        _g setVariable ["ARTIC_supportNoAssetDebug",time,false];
                    };
                };
            };
        };
    } forEach _groups;
} forEach ARTIC_Commanders;
