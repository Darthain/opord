/*
    Returns all platoon formation logic objects currently present in ARTIC commander ORBATs.
    These logic objects are used as list items by the CBA platoon state machine because
    CBA state-machine items must support setVariable/getVariable.
*/
if (!isServer) exitWith {[]};
private _out = [];
private _walk = {
    params ["_nodes","_commanderId"];
    {
        private _n = _x;
        private _logic = _n getOrDefault ["logic",objNull];
        private _level = toUpper (_n getOrDefault ["level",""]);
        if (!isNull _logic) then {
            _logic setVariable ["ARTIC_runtimeCommanderId",_commanderId,false];
            _logic setVariable ["ARTIC_runtimeFormationId",_n getOrDefault ["id",""],false];
            _logic setVariable ["ARTIC_runtimeFormationLevel",_level,false];
            if (_level isEqualTo "PLATOON") then {_out pushBackUnique _logic;};
        };
        [_n getOrDefault ["children",[]],_commanderId] call _walk;
    } forEach _nodes;
};
{
    private _commander = ARTIC_Commanders getOrDefault [_x,createHashMap];
    if ((count _commander) > 0) then {
        [_commander getOrDefault ["orbat",[]],_commander getOrDefault ["id",_x]] call _walk;
    };
} forEach keys ARTIC_Commanders;
_out
