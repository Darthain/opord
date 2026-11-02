params [["_commander",createHashMap,[createHashMap]]];
if !(missionNamespace getVariable ["ARTIC_debugMarkers",false]) exitWith {};
if ((count _commander) isEqualTo 0) exitWith {};

private _logic = _commander get "logic";
private _id = _commander get "id";

// AO marker
private _aoModules = (synchronizedObjects _logic) select {_x isKindOf "ARTIC_Module_AO"};
if (_aoModules isNotEqualTo []) then {
    private _ao = _aoModules select 0;
    private _name = format ["ARTIC_DBG_AO_%1",_id];
    if (markerType _name isEqualTo "") then {createMarker [_name,getPosATL _ao];};
    _name setMarkerShape "ELLIPSE";
    _name setMarkerBrush "Border";
    private _r = _ao getVariable ["Radius",3000];
    _name setMarkerSize [_r,_r];
};

// Initial/reference frontline marker
private _fronts = (synchronizedObjects _logic) select {_x isKindOf "ARTIC_Module_Frontline"};
if (_fronts isNotEqualTo []) then {
    private _f = _fronts select 0;
    private _nameF = format ["ARTIC_DBG_FRONT_%1",_id];
    if (markerType _nameF isEqualTo "") then {createMarker [_nameF,getPosATL _f];};
    _nameF setMarkerShape "RECTANGLE";
    _nameF setMarkerBrush "Border";
    _nameF setMarkerDir (_f getVariable ["Direction",0]);
    _nameF setMarkerSize [(_f getVariable ["Width",2000]) / 2,10];
};

// Classified battlefields.
{
    private _bf = ARTIC_Battlefields getOrDefault [_x,createHashMap];
    if ((count _bf) > 0 && {(_bf getOrDefault ["commanderId",""]) isEqualTo _id}) then {
        private _centre = _bf getOrDefault ["centre",[0,0,0]];
        private _r = _bf getOrDefault ["radius",100];
        private _name = format ["ARTIC_DBG_BF_%1",_x];
        if (markerType _name isEqualTo "") then {createMarker [_name,_centre];};
        _name setMarkerPos _centre;
        _name setMarkerShape "ELLIPSE";
        _name setMarkerBrush "Border";
        _name setMarkerColor "ColorRed";
        _name setMarkerSize [_r,_r];
        _name setMarkerText format ["%1 %2",_bf getOrDefault ["enemySize","?"],_bf getOrDefault ["contactCount",0]];
    };
} forEach (_commander getOrDefault ["battlefieldIds",[]]);

private _lineMarker = {
    params ["_name","_line","_color","_text",["_width",2.5,[0]]];
    if ((count _line) isNotEqualTo 2) exitWith {};
    private _a = _line select 0; private _b = _line select 1;
    private _mid = ((_a vectorAdd _b) vectorMultiply 0.5);
    if (markerType _name isEqualTo "") then {createMarker [_name,_mid];};
    _name setMarkerPos _mid;
    _name setMarkerShape "RECTANGLE";
    _name setMarkerBrush "SolidBorder";
    _name setMarkerColor _color;
    // Arma's long rectangle axis is perpendicular to markerDir when size[0] is
    // the dominant dimension; +90 makes the visual line match the endpoints.
    _name setMarkerDir ((_a getDir _b) + 90);
    _name setMarkerSize [(_a distance2D _b) / 2,_width];
    _name setMarkerText _text;
};

private _drawRoute = {
    params ["_prefix","_points","_color",["_label","",[""]]];
    if ((count _points) < 2) exitWith {};
    for "_i" from 0 to ((count _points) - 2) do {
        private _text = if (_i isEqualTo 0) then {_label} else {""};
        [format ["%1_%2",_prefix,_i],[_points select _i,_points select (_i + 1)],_color,_text,1.25] call _lineMarker;
    };
};

private _pointMarker = {
    params ["_name","_pos","_color","_text"];
    if (_pos isEqualTo []) exitWith {};
    if (markerType _name isEqualTo "") then {createMarker [_name,_pos];};
    _name setMarkerPos _pos;
    _name setMarkerShape "ELLIPSE";
    _name setMarkerBrush "Border";
    _name setMarkerColor _color;
    _name setMarkerSize [10,10];
    _name setMarkerText _text;
};

private _drawNode = {
    params ["_node","_self"];
    private _ctx = _node getOrDefault ["battleContext",createHashMap];
    if ((count _ctx) > 0) then {
        private _nid = _node getOrDefault ["id","FORM"];
        [format ["ARTIC_DBG_HOLD_%1_%2",_id,_nid],_ctx getOrDefault ["holdLine",[]],"ColorYellow","HOLD / ATTACK POS"] call _lineMarker;
        [format ["ARTIC_DBG_PLD_%1_%2",_id,_nid],_ctx getOrDefault ["probableLineOfDeployment",[]],"ColorWhite","PLD",1.5] call _lineMarker;
        private _fixValid = _ctx getOrDefault ["fixValid",false];
        private _fireMarker = format ["ARTIC_DBG_FIRE_%1_%2",_id,_nid];
        if (_fixValid) then {
            [_fireMarker,_ctx getOrDefault ["fireLine",[]],"ColorOrange","SBF / FIRE"] call _lineMarker;
        } else {
            if (markerType _fireMarker isNotEqualTo "") then {deleteMarker _fireMarker;};
        };
        private _assessment = _ctx getOrDefault ["assessment",createHashMap];
        private _assaultAllowed = _assessment getOrDefault ["assaultAllowed",false];
        private _assaultMarker = format ["ARTIC_DBG_ASSAULT_%1_%2",_id,_nid];
        private _fclMarker = format ["ARTIC_DBG_FCL_%1_%2",_id,_nid];
        private _loaMarker = format ["ARTIC_DBG_LOA_%1_%2",_id,_nid];
        if (_assaultAllowed) then {
            [_assaultMarker,_ctx getOrDefault ["assaultLine",[]],"ColorGreen","ASSAULT POS"] call _lineMarker;
            [_fclMarker,_ctx getOrDefault ["finalCoordinationLine",[]],"ColorGreen","FCL",1.4] call _lineMarker;
            [_loaMarker,_ctx getOrDefault ["limitOfAdvance",[]],"ColorRed","LOA"] call _lineMarker;
        } else {
            {if (markerType _x isNotEqualTo "") then {deleteMarker _x;};} forEach [_assaultMarker,_fclMarker,_loaMarker];
        };
        [format ["ARTIC_DBG_LBOUND_%1_%2",_id,_nid],_ctx getOrDefault ["leftBoundary",[]],"ColorBlack","L BOUNDARY",1] call _lineMarker;
        [format ["ARTIC_DBG_RBOUND_%1_%2",_id,_nid],_ctx getOrDefault ["rightBoundary",[]],"ColorBlack","R BOUNDARY",1] call _lineMarker;
        [format ["ARTIC_DBG_RELEASE_%1_%2",_id,_nid],_ctx getOrDefault ["releasePoint",[]],"ColorWhite","RELEASE"] call _pointMarker;
        [format ["ARTIC_DBG_RESERVE_%1_%2",_id,_nid],_ctx getOrDefault ["reservePos",[]],"ColorCIV","RESERVE"] call _pointMarker;
        [format ["ARTIC_DBG_RALLY_%1_%2",_id,_nid],_ctx getOrDefault ["rallyPos",[]],"ColorWhite","RALLY"] call _pointMarker;
        // SBF is only drawn as an active fire position when terrain/intelligence validates it.
        private _sbfSight = _ctx getOrDefault ["fixSight",-1];
        [format ["ARTIC_DBG_FIXPOS_%1_%2",_id,_nid],_ctx getOrDefault ["fixPos",[]],if (_fixValid) then {"ColorOrange"} else {"ColorRed"},
            if (_fixValid) then {format ["SBF (%1, sees %2%%)",_ctx getOrDefault ["shape","?"],round (_sbfSight * 100)]} else {format ["NO VALID SBF (%1%%)",if (_sbfSight < 0) then {-1} else {round (_sbfSight * 100)}]}] call _pointMarker;
        private _kp = _ctx getOrDefault ["keypoint",[]];
        if (_kp isNotEqualTo []) then {
            [format ["ARTIC_DBG_KEYPOINT_%1_%2",_id,_nid],_kp,"ColorRed","KEYPOINT"] call _pointMarker;
        };

        // Section-specific approach and battlefield routes. This is intentionally drawn
        // from the exact arrays the movement code uses so map debugging shows the plan,
        // not a decorative approximation of it.
        {
            private _g = _x;
            if (!isNull _g) then {
                private _role = _g getVariable ["ARTIC_schemeRole",""];
                private _col = switch (_role) do {case "MANOEUVRE_LEFT": {"ColorBlue"}; case "MANOEUVRE_RIGHT": {"ColorCIV"}; case "FIX": {"ColorOrange"}; default {"ColorWhite"};};
                private _route = _g getVariable ["ARTIC_battleApproachRoute",[]];
                private _start = _g getVariable ["ARTIC_sectionReferencePos",[]];
                if (_start isNotEqualTo [] && {_route isNotEqualTo []}) then {
                    [format ["ARTIC_DBG_ROUTE_%1_%2_%3",_id,_nid,groupId _g],[_start] + _route,_col,format ["%1 PLAN %2",groupId _g,_role]] call _drawRoute;
                };
                private _corrName = format ["ARTIC_DBG_CORR_%1_%2_%3",_id,_nid,groupId _g];
                private _corr = _g getVariable ["ARTIC_battleCorridor",[]];
                if (_assaultAllowed && {(count _corr) >= 2}) then {
                    [_corrName,_corr,_col,format ["%1 COMBAT",_role]] call _drawRoute;
                } else {
                    // _drawRoute creates numbered line markers. Clear the first reasonable
                    // range so an old authorised corridor cannot remain visible after a
                    // terrain/intel refresh vetoes the assault.
                    for "_ci" from 0 to 12 do {
                        private _mn = format ["%1_%2",_corrName,_ci];
                        if (markerType _mn isNotEqualTo "") then {deleteMarker _mn;};
                    };
                };
                // v0.3.16: show the LIVE movement hierarchy, not just the planned route.
                // If a section diverges we can immediately tell whether the guide, a
                // fireteam guide, or individual slot execution is at fault.
                private _guide = _g getVariable ["ARTIC_guide",[]];
                if (_guide isNotEqualTo []) then {
                    [format ["ARTIC_DBG_GUIDE_%1_%2_%3",_id,_nid,groupId _g],_guide select 0,_col,format ["%1 GUIDE [%2]",groupId _g,_g getVariable ["ARTIC_movementOwner","?"]]] call _pointMarker;

                    // v0.3.27: show the actual calculatePath result followed by the guide.
                    // The coloured PLAN line is tactical intent; the white NAV line is what
                    // the virtual section guide is physically following right now.
                    private _nav = _g getVariable ["ARTIC_guidePathDebug",[]];
                    private _navPrefix = format ["ARTIC_DBG_NAV_%1_%2_%3",_id,_nid,groupId _g];
                    if (_nav isNotEqualTo []) then {
                        [_navPrefix,[+(_guide select 0)] + _nav,"ColorWhite",format ["%1 LIVE NAV",groupId _g]] call _drawRoute;
                    };
                    private _navTarget = _g getVariable ["ARTIC_debugSectionDestination",[]];
                    if (_navTarget isNotEqualTo []) then {
                        [format ["ARTIC_DBG_NAVTARGET_%1_%2_%3",_id,_nid,groupId _g],_navTarget,"ColorWhite","NAV TARGET"] call _pointMarker;
                    };
                };
                private _fta = _g getVariable ["ARTIC_fireteamGuideA",[]];
                private _ftb = _g getVariable ["ARTIC_fireteamGuideB",[]];
                if (_fta isNotEqualTo []) then {[format ["ARTIC_DBG_FTA_%1_%2_%3",_id,_nid,groupId _g],_fta,_col,"FT-A"] call _pointMarker;};
                if (_ftb isNotEqualTo []) then {[format ["ARTIC_DBG_FTB_%1_%2_%3",_id,_nid,groupId _g],_ftb,_col,"FT-B"] call _pointMarker;};
            };
        } forEach (_node getOrDefault ["groups",[]]);
    };
    // v0.3.15: defence context
    private _dctx = _node getOrDefault ["defenceContext",createHashMap];
    if ((count _dctx) > 0) then {
        private _nid = _node getOrDefault ["id","FORM"];
        [format ["ARTIC_DBG_EA_%1_%2",_id,_nid],_dctx getOrDefault ["ea",[]],"ColorRed",format ["ENGAGEMENT AREA (%1)",["threat assumed","threat known"] select (_dctx getOrDefault ["threatKnown",false])]] call _pointMarker;
        [format ["ARTIC_DBG_TRIG_%1_%2",_id,_nid],_dctx getOrDefault ["trigger",[]],"ColorRed","TRIGGER LINE",1.5] call _lineMarker;
        [format ["ARTIC_DBG_OP_%1_%2",_id,_nid],_dctx getOrDefault ["op",[]],"ColorWhite","OP"] call _pointMarker;
        {
            _x params ["_g","_bp","_alt","_pdf","_fpl","_sight"];
            if (!isNull _g) then {
                [format ["ARTIC_DBG_BP_%1_%2_%3",_id,_nid,groupId _g],_bp,"ColorBlue",format ["%1 BP (sees EA %2%%)",groupId _g,round (_sight * 100)]] call _pointMarker;
                [format ["ARTIC_DBG_ALT_%1_%2_%3",_id,_nid,groupId _g],_alt,"ColorBlue",format ["%1 ALT",groupId _g]] call _pointMarker;
                [format ["ARTIC_DBG_PDF_%1_%2_%3",_id,_nid,groupId _g],[_bp,_bp getPos [120,_pdf]],"ColorBlue","PDF",1] call _lineMarker;
                [format ["ARTIC_DBG_FPL_%1_%2_%3",_id,_nid,groupId _g],[_bp,_bp getPos [80,_fpl]],"ColorRed","FPL",1] call _lineMarker;
            };
        } forEach (_dctx getOrDefault ["assign",[]]);
    };
    {[_x,_self] call _self;} forEach (_node getOrDefault ["children",[]]);
};
{[_x,_drawNode] call _drawNode;} forEach (_commander getOrDefault ["orbat",[]]);
