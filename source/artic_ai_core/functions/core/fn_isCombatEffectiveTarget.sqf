/*
    Returns true only for a living, combat-effective target.
    ACE unconscious units and Arma incapacitated life states are deliberately
    excluded so ARTIC does not waste suppression/FPV/assault attention on them.
*/
params [["_obj",objNull,[objNull]]];
if (isNull _obj || {!alive _obj}) exitWith {false};

private _life = toUpper (lifeState _obj);
if (_life in ["INCAPACITATED","DEAD","DEAD-RESPAWN","DEAD-SWITCHING"]) exitWith {false};
if (_obj getVariable ["ACE_isUnconscious",false]) exitWith {false};

true
