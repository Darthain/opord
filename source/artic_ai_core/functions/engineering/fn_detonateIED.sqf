/*
    ARTIC - command-detonate an IEDD IED (v0.2.1).
    Uses IEDD's own server event (iedd_modules_explode), the same one IEDD's Zeus
    "explode" action uses: it forces a live (non-dud) detonation.
    Use for ambush initiation (Battle Book: ambushes sprung with an explosive).
*/
params [["_ied", objNull, [objNull]]];
if (isNull _ied || {!isClass (configFile >> "CfgPatches" >> "iedd_modules")}) exitWith {false};
["iedd_modules_explode", [_ied]] call CBA_fnc_serverEvent;
true
