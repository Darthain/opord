/*
    ARTIC - is this soldier able to take part in formation and movement? (v0.3.6)
    Alive, not incapacitated (vanilla lifeState), not ACE-unconscious, on foot.
    Downed soldiers are still "alive", which in v0.3.5 kept them in fireteam anchors,
    readiness counts and cohesion checks, freezing the section around a casualty.
*/
params [["_unit", objNull, [objNull]]];
alive _unit
&& {(lifeState _unit) isNotEqualTo "INCAPACITATED"}
&& {!(_unit getVariable ["ACE_isUnconscious", false])}
&& {isNull objectParent _unit}
