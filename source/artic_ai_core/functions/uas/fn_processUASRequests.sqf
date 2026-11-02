if (!isServer) exitWith {};
if (ARTIC_UASRequests isEqualTo []) exitWith {};

private _remaining = [];
{
    _x params ["_mission","_pos","_target","_requester","_commanderId","_requestTime"];
    if ((time - _requestTime) < 120) then {
        private _commander = ARTIC_Commanders getOrDefault [_commanderId,createHashMap];
        if ((count _commander) > 0) then {
            private _provider = [_commander,_mission,_pos] call ARTIC_fnc_findUASProvider;
            if (_provider isNotEqualTo []) then {
                switch (_mission) do {
                    case "RECON": {[_commander,_provider,_pos,350] spawn ARTIC_fnc_executeReconUAS;};
                    case "FPV_AP": {if (!isNull _target) then {[_commander,_provider,_target,"AP"] spawn ARTIC_fnc_executeFPVStrike;};};
                    case "FPV_AT": {if (!isNull _target) then {[_commander,_provider,_target,"AT"] spawn ARTIC_fnc_executeFPVStrike;};};
                };
                _commander set ["uasPendingUntil",time + 30];
            } else {
                _remaining pushBack _x;
            };
        };
    };
} forEach ARTIC_UASRequests;
ARTIC_UASRequests = _remaining;
