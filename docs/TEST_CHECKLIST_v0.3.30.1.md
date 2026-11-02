# v0.3.30.1 Air Station Test Checklist

Keep the mission unchanged from the previous benchmark.

Watch for:

- the initial `FSM PLAN CREATED` line and section role assignment;
- each section task moving through explicit `TASK STATE` transitions;
- exactly one H-hour execution per manoeuvre task;
- failure causing `FAILED` / `ABORTED`, then quiet play termination;
- no old-plan movement after the replacement plan is created;
- any `TASK STATE REJECTED` lines;
- any `H-HOUR DUPLICATE IGNORED` lines;
- any `UNITCTRL CONFLICT ... cmd=ATTACK plan=LEADER PLANNED` lines;
- routes that still cross known enemy positions;
- sections sent unusually far from the current fight.

Please capture screenshots at:
1. initial plan;
2. first H-hour;
3. first plan failure/reassessment;
4. replacement plan deployment;
5. any strange route/straggler;
6. objective secured/end state.

Send the complete RPT after the run.
