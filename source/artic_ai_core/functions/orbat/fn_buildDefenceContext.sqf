/*
    ARTIC v0.3.15 - defensive battle context for DEFEND orders (server).

    The defensive counterpart of fn_buildBattleContext. Built once per objective, and
    rebuilt only if the objective moves or a threat direction becomes known.

      threat axis   toward the nearest known battlefield / contact report (within
                    1200 m), otherwise straight ahead along the direction the platoon
                    approached from (friendly centre -> objective)
      EA            engagement area: where the enemy is to be engaged, ~0.6 x sight
                    (60-350 m) out along the threat axis (fn_getBattleEnvelope)
      trigger line  60 m beyond the EA: when the enemy crosses it, the defence opens up
      BP            one primary battle position per section along a line across the axis
                    (~60 m apart open, ~30 m close), each chosen because it SEES the EA
                    (fn_battleSight, VIEW/FIRE LODs) and has cover
      ALT           alternate position 30-50 m back, also seeing the EA
      PDF           principal direction of fire: from the BP to the section's part of the EA
      FPL           final protective line for the section MG: grazing fire across the
                    front of the position (toward the platoon centre)
      OP            hidden observation post forward, past the EA (first section)

    Published per group: ARTIC_defenceBP, ARTIC_defenceAlt, ARTIC_defencePDF,
    ARTIC_defenceFPL, ARTIC_defenceEA, ARTIC_defenceTrigger, ARTIC_defenceOP,
    ARTIC_defenceThreatKnown. DEFEND orders use the BP; battle-position layouts face the PDF.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_commander",createHashMap,[createHashMap]],
    ["_groups",[],[[]]],
    ["_objective",[],[[]]]
];
if (!isServer || {_objective isEqualTo []}) exitWith {createHashMap};
_groups = _groups select {!isNull _x && {({alive _x} count units _x) > 0}};
if (_groups isEqualTo []) exitWith {createHashMap};
private _nodeId = _node getOrDefault ["id","FORMATION"];

// threat direction
private _threatPos = [];
private _bestD = 1200;
{
    private _bf = (missionNamespace getVariable ["ARTIC_Battlefields",createHashMap]) getOrDefault [_x,createHashMap];
    if ((count _bf) > 0) then {
        private _c = _bf getOrDefault ["centre",[]];
        if (_c isNotEqualTo [] && {(_c distance2D _objective) < _bestD}) then {_bestD = _c distance2D _objective; _threatPos = +_c;};
    };
} forEach (_commander getOrDefault ["battlefieldIds",[]]);
if (_threatPos isEqualTo []) then {
    {
        _x params ["_o","_p","_t"];
        if ((time - _t) < 600 && {(_p distance2D _objective) < _bestD}) then {_bestD = _p distance2D _objective; _threatPos = +_p;};
    } forEach (_commander getOrDefault ["contactReports",[]]);
};
private _threatKnown = _threatPos isNotEqualTo [];

private _ctx = _node getOrDefault ["defenceContext",createHashMap];
private _rebuild = (count _ctx) isEqualTo 0
    || {((_ctx getOrDefault ["objective",[0,0,0]]) distance2D _objective) > 35}
    || {_threatKnown && {!(_ctx getOrDefault ["threatKnown",false])}};

if (_rebuild) then {
    private _cx = 0; private _cy = 0;
    {private _p = getPosATL leader _x; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1);} forEach _groups;
    private _friendly = [_cx / count _groups,_cy / count _groups,0];
    private _axis = if (_threatKnown) then {_objective getDir _threatPos} else {
        if ((_friendly distance2D _objective) > 30) then {_friendly getDir _objective} else {getDir leader (_groups select 0)}
    };

    private _env = [_objective,false] call ARTIC_fnc_getBattleEnvelope;
    private _close = (_env get "terrain") in ["CLOSE","URBAN"];
    private _eaDepth = (((_env get "sight") * 0.6) max 60) min 350;
    if (_threatKnown) then {_eaDepth = _eaDepth min (((_objective distance2D _threatPos) - 30) max 50);};
    private _secFront = [60,30] select _close;
    private _n = count _groups;
    private _frontage = (_n * _secFront) max 60;

    private _ea = _objective getPos [_eaDepth,_axis];
    private _eaL = _ea getPos [_frontage * 0.5,_axis - 90];
    private _eaR = _ea getPos [_frontage * 0.5,_axis + 90];
    private _eaPts = [_ea,_eaL,_eaR,_ea getPos [40,_axis],_ea getPos [40,_axis + 180]];
    private _trigC = _objective getPos [_eaDepth + 60,_axis];
    private _trigger = [_trigC getPos [_frontage * 0.6,_axis - 90],_trigC getPos [_frontage * 0.6,_axis + 90]];

    // order sections left -> right by where they are now, so they don't cross over
    private _lateralOf = {
        params ["_g"];
        private _p = getPosATL leader _g;
        private _d = _objective distance2D _p;
        _d * sin ((_objective getDir _p) - _axis)
    };
    private _ordered = [_groups,[],{[_x] call _lateralOf},"ASCEND"] call BIS_fnc_sortBy;

    private _assign = [];
    {
        private _lat = (_forEachIndex - ((_n - 1) / 2)) * _secFront;
        private _ideal = _objective getPos [abs _lat,_axis + ([90,-90] select (_lat < 0))];
        private _bpRes = [_ideal,_ea,"FIRE",40,_axis + 180,0,_eaPts] call ARTIC_fnc_findBattleControlPoint;
        private _bp = _bpRes select 0;
        private _altIdeal = _bp getPos [40,_axis + 180 + ([30,-30] select (_lat < 0))];
        private _alt = ([_altIdeal,_ea,"FIRE",30,_axis + 180,0,_eaPts] call ARTIC_fnc_findBattleControlPoint) select 0;
        private _mySector = _ea getPos [abs (_lat * 0.8),_axis + ([90,-90] select (_lat < 0))];
        private _pdf = _bp getDir _mySector;
        // FPL: grazing across the front, toward the platoon centre (outer sections) or
        // across the right (centre section)
        private _fpl = if ((abs _lat) < 1) then {(_axis + 90) % 360} else {(_axis + ([90,-90] select (_lat > 0)) + 360) % 360};
        _assign pushBack [_x,_bp,_alt,_pdf,_fpl,_bpRes select 1];
    } forEach _ordered;

    private _op = ([_objective getPos [_eaDepth + 90,_axis],_ea,"HOLD",40,_axis + 180,0,[_objective]] call ARTIC_fnc_findBattleControlPoint) select 0;

    _ctx = createHashMapFromArray [
        ["objective",+_objective],["axis",_axis],["threatKnown",_threatKnown],["threatPos",_threatPos],
        ["ea",_ea],["eaDepth",_eaDepth],["trigger",_trigger],["op",_op],["assign",_assign],
        ["envelope",_env],["created",time]
    ];
    _node set ["defenceContext",_ctx];
    [format ["Defence context %1: threat %2 axis %3, EA %4m out (%5), %6 section BP(s), sight to EA %7",
        _nodeId,["assumed (approach direction)","known"] select _threatKnown,round _axis,round _eaDepth,_env get "terrain",_n,
        (_assign apply {format ["%1%%",round ((_x select 5) * 100)]}) joinString "/"],_nodeId] call ARTIC_fnc_debug;
};

// publish (every call: cheap, keeps late-joining / transferred groups informed)
{
    _x params ["_g","_bp","_alt","_pdf","_fpl"];
    if (!isNull _g) then {
        if ((_g getVariable ["ARTIC_defenceBP",[]]) isNotEqualTo _bp) then {
            _g setVariable ["ARTIC_defenceBP",_bp,true];
            _g setVariable ["ARTIC_defenceAlt",_alt,true];
            _g setVariable ["ARTIC_defencePDF",_pdf,true];
            _g setVariable ["ARTIC_defenceFPL",_fpl,true];
            _g setVariable ["ARTIC_defenceEA",_ctx get "ea",true];
            _g setVariable ["ARTIC_defenceTrigger",_ctx get "trigger",true];
            _g setVariable ["ARTIC_defenceThreatKnown",_ctx get "threatKnown",true];
            _g setVariable ["ARTIC_defenceOP",[[],_ctx get "op"] select (_forEachIndex isEqualTo 0),true];
        };
    };
} forEach (_ctx getOrDefault ["assign",[]]);
_ctx
