/*
    ARTIC v0.3.30.2 - publish one unit of deployment progress for the platoon READY_CHECK.

    0.3.30 READY_CHECK judged progress only from the section's distance to its deployment
    point and from FIX/BLOCK/manoeuvre phase changes. A BLOCK or FIX that has arrived and is
    occupying a fire line, or moving it forward to find observation, stays in one phase at one
    distance, so the platoon saw "no progress" while soldiers were still walking to their firing
    points (0.3.30.1 Air Station: BLOCK_NOT_READY at 60 s, six seconds before the BLOCK's own
    observation verdict).

    The play calls this whenever it makes progress (a soldier reaches his point, the line moves,
    a phase step). ARTIC_deployProgressSeq is a plain counter, so the server compares values and
    never compares clocks between machines (safe for HC-owned sections).

    Arguments: 0 group, 1 optional legacy time variable to stamp (e.g. "ARTIC_blockProgressAt")
*/
params [["_group",grpNull,[grpNull]],["_timeVar","",[""]]];
if (isNull _group) exitWith {};
_group setVariable ["ARTIC_deployProgressSeq",(_group getVariable ["ARTIC_deployProgressSeq",0]) + 1,true];
if (_timeVar isNotEqualTo "") then {_group setVariable [_timeVar,time,true];};
