params [
    ["_commander",createHashMap,[createHashMap]],
    ["_mission","RECON",[""]],
    ["_position",[],[[]]]
];
if ((count _commander) isEqualTo 0) exitWith {[]};

private _roots = _commander getOrDefault ["orbat",[]];
private _groups = [];
{_groups append ([_x] call ARTIC_fnc_getFormationGroups);} forEach _roots;
_groups = _groups arrayIntersect _groups;

private _cmdLogic = _commander get "logic";
{
    private _asset = _y;
    private _logic = _asset getOrDefault ["logic",objNull];
    if (!isNull _logic && {_logic in (synchronizedObjects _cmdLogic)} && {(_asset getOrDefault ["role",""]) in ["RECON_UAS","FPV_AP","FPV_AT","UAS_MIXED"]}) then {
        {
            private _g = if (_x isKindOf "Man") then {group _x} else {group effectiveCommander _x};
            if (!isNull _g) then {_groups pushBackUnique _g;};
        } forEach (_asset getOrDefault ["assets",[]]);
    };
} forEach ARTIC_SupportAssets;

private _wanted = toUpper _mission;
private _candidates = [];
{
    private _g = _x;
    if (!isNull _g && {alive leader _g}) then {
        private _caps = [_g] call ARTIC_fnc_scanGroupCapabilities;
        private _roles = _caps getOrDefault ["roles",[]];
        private _entries = [];
        switch (_wanted) do {
            case "RECON": {
                _entries = +(_caps getOrDefault ["reconUAS",[]]);
                if (_entries isEqualTo [] && {"RECON_UAS" in _roles || {"UAS_MIXED" in _roles}}) then {_entries pushBack [leader _g,"",false,false];};
            };
            case "FPV_AP": {
                _entries = +(_caps getOrDefault ["fpvAPTI",[]]);
                _entries append (_caps getOrDefault ["fpvAP",[]]);
                if (_entries isEqualTo [] && {("FPV_AP" in _roles) || {"UAS_MIXED" in _roles}}) then {_entries pushBack [leader _g,"",false,false];};
            };
            case "FPV_AT": {
                _entries = +(_caps getOrDefault ["fpvATTI",[]]);
                _entries append (_caps getOrDefault ["fpvAT",[]]);
                if (_entries isEqualTo [] && {("FPV_AT" in _roles) || {"UAS_MIXED" in _roles}}) then {_entries pushBack [leader _g,"",false,false];};
            };
        };

        {
            private _entry = _x;
            private _operator = _entry select 0;
            if (!isNull _operator && {alive _operator} && {time >= (_operator getVariable ["ARTIC_uasBusyUntil",0])}) then {
                private _score = if (_position isEqualTo []) then {0} else {_operator distance2D _position};
                _candidates pushBack [_score,_g,_entry];
            };
        } forEach _entries;
    };
} forEach _groups;

if (_candidates isEqualTo []) exitWith {[]};
_candidates sort true;
private _best = _candidates select 0;
[_best select 1,_best select 2]
