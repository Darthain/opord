params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {0};
private _old = _group getVariable ["ARTIC_sectionFSM",0];
if (_old > 0 && {!completedFSM _old}) exitWith {_old};
private _h = [_group] execFSM "\\artic_ai_core\\fsm\\ARTIC_Section.fsm";
_group setVariable ["ARTIC_sectionFSM",_h,false];
_h
