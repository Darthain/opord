/*
    ARTIC - movement profile for a group (v0.3.8). Cached ~10 s per group.

    Terrain: CLOSE when the section anchor has dense trees/bush/buildings within 35 m,
    or at night (sight lines and control distances shrink the same way).

    Returns hashmap:
      terrain         "OPEN" | "CLOSE"
      soft / hard     fireteam cohesion leash (m): slow down beyond soft, stop beyond hard
      teamSepLimit    fireteam-to-fireteam distance before a section regroup is considered
      elemSoft/Hard   element leash during plays
      boundLen        bounding length (m), scaled by training coordination
      sectionSpacing  platoon: distance between sections (Battle Book: 50-100 m open,
                      5-25 m in file/close country)
*/
params [["_group", grpNull, [grpNull]]];
if (isNull _group) exitWith {createHashMap};

private _cached = _group getVariable ["ARTIC_moveProfile", []];
if (_cached isNotEqualTo [] && {time < (_cached select 0)}) exitWith {_cached select 1};

private _anchor = _group getVariable ["ARTIC_sectionReferencePos",[]];
if (_anchor isEqualTo []) then {
    private _g = _group getVariable ["ARTIC_guide",[]];
    _anchor = if (_g isNotEqualTo []) then {+(_g select 0)} else {getPosATL leader _group};
};
private _density = count (nearestTerrainObjects [_anchor, ["TREE","SMALL TREE","BUSH"], 35, false, true])
    + 3 * count (nearestObjects [_anchor, ["House"], 35]);
private _night = (sunOrMoon < 0.35);
private _close = _night || {_density > (missionNamespace getVariable ["ARTIC_closeCountryDensity", 22])};

([_group] call ARTIC_fnc_getProfile) params ["", "", "", "_training"];
private _coord = _training getOrDefault ["coordination", 0.55];

private _p = if (_close) then {
    createHashMapFromArray [
        ["terrain","CLOSE"], ["soft",14], ["hard",24], ["teamSepLimit",34],
        ["elemSoft",16], ["elemHard",26], ["boundLen", 15 + 10 * _coord], ["sectionSpacing", 22]
    ]
} else {
    createHashMapFromArray [
        ["terrain","OPEN"], ["soft",24], ["hard",38], ["teamSepLimit",60],
        ["elemSoft",26], ["elemHard",40], ["boundLen", 30 + 20 * _coord], ["sectionSpacing", 70]
    ]
};
_group setVariable ["ARTIC_moveProfile", [time + 10, _p], false];
_p
