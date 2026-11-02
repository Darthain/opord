[] spawn {
    waitUntil { time > 0 };

    if (isServer) then {
        ["ARTIC_UAS_REQUEST", {ARTIC_UASRequests pushBack _this;}] call CBA_fnc_addEventHandler;
        call ARTIC_fnc_registerFSMEvents;
        if (missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]) then {
            call ARTIC_fnc_startPlatoonCBAStateMachine;
        };
        [] spawn ARTIC_fnc_serverManager;
    };

    // Runs on server, every HC, and clients. It only acts on groups local to
    // that machine, which keeps locality migration safe.
    [] spawn ARTIC_fnc_localPlanner;
};
