/*
    ARTIC v0.3.17 - persistent fireteam membership only.

    This replaces the v0.3.5 majority-cluster anchor system. It assigns stable A/B
    fireteam membership and team slot indices, but does NOT create spatial anchors.
    All moving spatial references come from ARTIC section/fireteam guides.
*/
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {false};

private _members = (units _group) select {[_x] call ARTIC_fnc_isFit};
if (_members isEqualTo []) exitWith {false};

private _a = [];
private _b = [];
{
    private _ft = _x getVariable ["ARTIC_teamId",""];
    if (_ft isEqualTo "A") then {_a pushBack _x;};
    if (_ft isEqualTo "B") then {_b pushBack _x;};
} forEach _members;

private _unassigned = _members select {(_x getVariable ["ARTIC_teamId",""]) isEqualTo ""};
{
    private _ft = if ((count _members) <= 4) then {"A"} else {if ((count _a) <= (count _b)) then {"A"} else {"B"}};
    _x setVariable ["ARTIC_teamId",_ft,true];
    if (_ft isEqualTo "A") then {_a pushBack _x;} else {_b pushBack _x;};
} forEach _unassigned;

// Stable indices within each fireteam. We intentionally do not derive any anchor
// from live soldier positions here.
{
    private _teamMembers = _x;
    private _used = [];
    {
        private _member = _x;
        private _idx = _member getVariable ["ARTIC_teamSlot",-1];
        if (_idx < 0 || {_idx in _used}) then {
            private _candidate = 0;
            while {_candidate in _used} do {_candidate = _candidate + 1;};
            _idx = _candidate;
            _member setVariable ["ARTIC_teamSlot",_idx,true];
        };
        _used pushBackUnique _idx;
    } forEach _teamMembers;
} forEach [_a,_b];

private _base = _group getVariable ["ARTIC_baseFireteam",""];
if !(_base in ["A","B"]) then {
    private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
    private _mgs = _caps getOrDefault ["mg",[]];
    private _grens = _caps getOrDefault ["grenadier",[]];
    private _scoreA = ({_x in _a} count _mgs) * 3 + ({_x in _a} count _grens);
    private _scoreB = ({_x in _b} count _mgs) * 3 + ({_x in _b} count _grens);
    _base = if (_scoreB > _scoreA) then {"B"} else {"A"};
    _group setVariable ["ARTIC_baseFireteam",_base,true];
};

_group setVariable ["ARTIC_fireteamMembersA",_a,false];
_group setVariable ["ARTIC_fireteamMembersB",_b,false];
true
