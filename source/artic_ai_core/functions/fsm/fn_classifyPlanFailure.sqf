/*
    ARTIC v0.3.30 - failure class for a platoon plan failure reason.

      TIMING   - the plan was sound but an element was not in place in time
                 (BLOCK_NOT_READY, FIX_NOT_READY, MANOEUVRE_NOT_READY, MANOEUVRE_SYNC_FAILED).
                 The first TIMING failure of a scheme retries the same scheme.
      CONTACT  - the enemy invalidated the plan before H-hour (CONTACT_ON_DEPLOYMENT).
                 Replanning is contact-aware: the engaged section fixes in place.
      TACTICAL - everything else (no LOS, route failed, suppression not achieved, ...).
                 Reassessment changes the scheme as in v0.3.27.
*/
params [["_reason","",[""]]];
private _r = toUpper _reason;
switch (true) do {
    case (_r in ["BLOCK_NOT_READY","FIX_NOT_READY","MANOEUVRE_NOT_READY","READY_TIMEOUT","MANOEUVRE_SYNC_FAILED"]): {"TIMING"};
    case ((_r find "CONTACT_") isEqualTo 0): {"CONTACT"};
    default {"TACTICAL"};
}
