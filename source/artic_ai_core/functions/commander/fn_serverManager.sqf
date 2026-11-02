["Server commander manager started", "SERVER"] call ARTIC_fnc_debug;

while {true} do {
    {
        private _commander = _y;
        [_commander] call ARTIC_fnc_commanderStep;
    } forEach ARTIC_Commanders;

    call ARTIC_fnc_refreshSiteControl;
    call ARTIC_fnc_processSupportRequests;
    call ARTIC_fnc_processUASRequests;
    sleep 5;
};
