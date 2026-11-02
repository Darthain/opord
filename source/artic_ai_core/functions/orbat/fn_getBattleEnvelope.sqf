/*
    ARTIC v0.3.15 - battle distances derived from terrain, visibility and weapons, instead
    of the fixed 320-380 m HOLD / 185-220 m fire position used up to 0.3.14.

      terrain   OPEN / MIXED / CLOSE / URBAN from vegetation and buildings around the focus
      sight     min(view distance reduced by fog, terrain cap, night cap)
                caps: OPEN 500, MIXED 300, CLOSE 140, URBAN 160, night 220 m
      fire      support-by-fire distance ~0.6 x sight (70-300 m); MG-heavy forces may
                stand a little further off (x1.15)
      hold      fire + 0.4 x sight (70-160 m further back)
      assault   last covered position: 0.35 x fire (35-85 m)
      search    radius searched around each ideal point, grows with the distances

    Returns hashmap.
*/
params [["_focus",[],[[]]],["_mgHeavy",false,[true]]];
private _trees = count (nearestTerrainObjects [_focus,["TREE","SMALL TREE","BUSH"],100,false,true]);
private _houses = count (nearestObjects [_focus,["House"],100]);
private _terrain = switch (true) do {
    case (_houses >= 8): {"URBAN"};
    case (_trees >= 90): {"CLOSE"};
    case (_trees >= 25): {"MIXED"};
    default {"OPEN"};
};
private _night = sunOrMoon < 0.35;
private _vis = viewDistance * (1 - 0.85 * fog);
private _cap = switch (_terrain) do {case "URBAN": {160}; case "CLOSE": {140}; case "MIXED": {300}; default {500}};
if (_night) then {_cap = _cap min 220;};
private _sight = (_vis min _cap) max 60;

private _fire = ((_sight * 0.6 * ([1,1.15] select _mgHeavy)) max 70) min 300;
private _hold = _fire + (((_sight * 0.4) max 70) min 160);
private _assault = ((_fire * 0.35) max 35) min 85;
createHashMapFromArray [
    ["terrain",_terrain],["night",_night],["sight",_sight],
    ["fireDepth",_fire],["holdDepth",_hold],["assaultDepth",_assault],
    ["searchFire",((_fire * 0.4) max 40) min 110],
    ["searchHold",((_hold * 0.2) max 45) min 90]
]
