# ARTIC AI — Individual soldier layer (design)

Goal: ARTIC ships its own individual behaviour so the unit runs one AI mod. LAMBS Danger
DEV is the reference for *what* a good individual layer does and *which engine hooks* it
uses. This document maps that structure onto ARTIC.

## 0. Licence decision (make this first)

LAMBS is GPLv2 (its readme also mentions two licence amendments in its documentation,
which were not in the files reviewed). Two clean options:

| Option | What it means |
|---|---|
| **A. Clean-room** (current ARTIC approach) | Study LAMBS for behaviours, priorities and engine hooks; write ARTIC's own code. No LAMBS code or close line-by-line translations in ARTIC. ARTIC keeps whatever licence the unit chooses. |
| **B. GPL ARTIC** | ARTIC is released under GPLv2 (source available, attribution kept). LAMBS code may then be reused where it fits, subject to the amendments. |

Everything below is written for option A. (Not legal advice.)

## 1. How the engine delivers danger (the one hard constraint)

Individual combat reactions start in the engine's **danger FSM**, set per unit class in
config (`fsmDanger` on `CAManBase` and similar). The engine calls it with a *danger
cause*, a position and the causing entity:

| Cause | Meaning | LAMBS bucket |
|---|---|---|
| 0 EnemyDetected | new enemy seen | engage |
| 1 Fire | enemy fired nearby | immediate |
| 2 Hit | unit was hit | immediate |
| 3 EnemyNear | enemy very close | engage (+ callout, share info) |
| 4 Explosion | explosion nearby | immediate |
| 5 DeadBodyGroup | dead friendly from own group | hide |
| 6 DeadBody | dead body found | hide |
| 7 Scream | wounded screaming | hide |
| 8 CanFire | can engage enemy | engage |
| 9 BulletClose | bullet passed close | immediate |
| (10 Assess) | no queued danger | assess |

**Only one `fsmDanger` can win per unit class.** ARTIC therefore treats LAMBS/DCO and other
AI packages as clean-room reference implementations only. ARTIC v0.3.17 has no runtime
compatibility variables or calls into those packages. Benchmark them in separate runs rather
than loading two movement/individual AI owners on the same groups.

Other hooks available without an FSM: unit event handlers `Suppressed`, `FiredNear`,
`Hit`, `Killed`, group event handler `EnemyDetected`, `getSuppression`, `targets`,
`knowsAbout`. These are enough for a prototype before writing the FSM.

## 2. Architecture

```
engine danger FSM (ARTIC, minimal)      unit EHs (Suppressed/FiredNear/Hit)
            \                                /
             +--> ARTIC_fnc_dangerQueue  (per-unit queue: cause, pos, until, source)
                          |
                  ARTIC_fnc_unitBrain     (pick most urgent cause by priority table)
                          |
     +-----------+--------+---------+-------------+
  IMMEDIATE    ENGAGE     HIDE      ASSESS     (+ FORCED: group/plan overrides)
  react        engage     hide      assess
```

Rules:
- The FSM stays tiny: it only feeds the queue and calls the brain on a timer. All logic
  lives in SQF functions (testable, hot-reloadable with `allowFunctionsRecompile`).
- **Group plan wins.** If a unit is `ARTIC_moveLocked`, `ARTIC_tasked` (CASEVAC etc.) or in
  a plan element, the brain only does things that don't move the unit (turn, go prone,
  return fire). This is LAMBS' "forced" concept and is what keeps the group layer in charge.
- Priorities, reaction chances and timings come from **training** (and some from doctrine),
  so POOR and ELITE soldiers react visibly differently.
- Local units only; throttle the brain (e.g. every 1–3 s per unit, staggered).

## 3. Behaviour modules (build order)

| # | Module | Behaviour | Training effect |
|---|---|---|---|
| 1 | React (immediate) | Hit/bullet/explosion: drop or crouch, turn to threat, return fire; short dash to cover if exposed | Reaction delay; POOR freezes more often |
| 2 | Cover | Find cover relative to the threat (ARTIC already has a clean cover finder in the tactical prototype) and move there | Search radius, quality threshold |
| 3 | Suppress | Suppressive fire at last known enemy position when no clear shot | Burst discipline, ammo awareness |
| 4 | Engage | Enemy near: assault if very close, flank if blocked, hold if outgunned | Aggression by doctrine |
| 5 | Hide | Dead body/scream/panic: seek concealment, look toward threat | POOR panics more |
| 6 | Grenades & UGL | Throw frag at close enemy behind cover; UGL at groups; smoke to break line of sight | Accuracy/decision quality |
| 7 | Buildings/CQB | Clear adjacent rooms, grenade before entry (Battle Book: explosive first) | ELITE only for full sequence |
| 8 | Callouts & info share | Contact callouts, reveal to nearby friendlies, report to group leader | Radio-limited range (ACRE) |
| 9 | Morale | Suppression + casualties + leader loss → pinned, fall back, flee, surrender | Doctrine × training |
| 10 | Vehicles | Crew reactions, dismount under fire, smoke launchers | later |

Start with 1–3 on the event-handler prototype; they give most of the visible improvement.

## 4. What LAMBS shows is worth copying *as a design idea*

- A single **priority table** per danger cause, applied to a per-unit queue, rather than
  reacting to every event immediately.
- Clear split between **immediate / engage / hide / assess** reactions.
- **Forced** state so group tactics are never overridden by individual reactions.
- Information sharing on "enemy near" (callout + reveal to friendlies in range).
- Individual actions as small reusable functions (take cover, suppress, throw, assault a
  position) that group tactics can also call.

## 5. Test plan

1. Prototype on event handlers only (no FSM) with LAMBS unloaded; compare against vanilla.
2. Add the minimal FSM; confirm each cause reaches the queue (debug overlay per unit).
3. Performance run: 150+ AI across server + HC, watch server FPS and scheduler load.
4. A/B the same mission with LAMBS vs ARTIC individual layer before switching the unit over.

## Current implementation note

ARTIC currently provides threat-relative `SEEK_COVER`, `RELOAD_COVER`, and `PINNED` reactions. v0.3.17 consolidates moving spatial ownership under persistent section and fireteam guides; the retired majority-centroid regroup code has been removed. DCO remains a clean-room study target for the deeper v0.4 individual combat brain.
