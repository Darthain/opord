# ARTIC AI — Section formations (v0.3.9)

## Who controls a soldier (arbiter)

At any moment exactly one system gives a soldier orders, in this priority:

1. **Reaction** (danger, reload in cover, pinned) — short, then hands back.
2. **Play task** (MOVE / HOLD / SUPPRESS / ASSAULT from a flank, fix, withdrawal, bound...).
3. **STATIC** idle hold (DEFEND / SUPPORT groups).
4. **FORMATION** idle movement — the section formation controller.

The v0.3.5-0.3.8 cohesion governor no longer runs for FORMATION movement, and the engine
formation (`doFollow`) is only used when `ARTIC_formationSystem = false`.

## Why ARTIC owns formations

In Arma's engine formation the group leader is always the reference point: the tip of
the wedge / front of the column. To put the section commander in a protected central
position the formation must be ARTIC's own. Soldiers follow a **guide point**, not each
other: the guide travels a real route (`calculatePath`) at the formation's pace and waits
for the section when soldiers fall behind their slots.

## Role placement

| Role | Who | Where |
|---|---|---|
| CMD | group leader | inside/behind the body of the formation, central |
| MEDIC | medic | beside/behind the commander, central |
| SECOND | highest-ranked other soldier | rear (tail of the column, rear corner) |
| SCOUT | a rifleman | point |
| MG / GREN / AT | specialists | arms, flanks and corners |
| RIFLE | everyone else | remaining slots |

Training: `specialistAssignment` controls how often soldiers end up out of their proper
slot; low `coordination` sometimes puts the commander at the point.

## Formations and when they are chosen

| Formation | Chosen when |
|---|---|
| LINE (facing the enemy) | first contact: develop fire for decisionDelay + 2 s (max 14 s), then plays take over |
| DIAMOND (<8) / BOX (8+) | halted: all-round security |
| DIAMOND / BOX_DIAMOND (8+) | known threats spread > 120° around the section |
| VEE (AGGRESSIVE / SF / CONVENTIONAL) or WEDGE | contact expected (< 450 m) ahead |
| ECHELON_LEFT / ECHELON_RIGHT | contact expected on that flank |
| DIAMOND | contact expected behind |
| WEDGE (open) / COLUMN (close country) | contact possible (< 900 m) |
| COLUMN | safe and > 300 m to go (speed), close country, or the platoon moves in file |
| WEDGE | safe, short move in the open |

Doctrine: MILITIA / INSURGENT don't use BOX / BOX_DIAMOND / DIAMOND / ECHELON / VEE;
RECON prefers COLUMN.

Spacing: COLUMN 6 m, DIAMOND/BOX 6 m, others 5 m per template unit; x0.65 in close
country; x(0.7 + 0.3 x coordination), so poorly trained sections bunch.

A new formation must persist 3 s (ELITE) to ~12 s (POOR) before the section changes; the
contact LINE is immediate.

BOX_DIAMOND is interpreted as two fireteam diamonds side by side with the commander and
medic between them.


## v0.3.14 additions
- CROWS_FOOT: two front pairs wide toward the likely contact (MG + rifleman), CMD + MEDIC
  middle, 2IC + one rear; extras reinforce the front. Replaces VEE for forward threats
  (`ARTIC_useCrowsFoot`).
- Minimum soldier separation by training (open POOR 5 / REGULAR 7 / VETERAN 9 / ELITE 10 m,
  x0.5 in close country or at night), following the ~10 m doctrinal interval.
- Heavy left / heavy right: formation mirrored so the MG side faces the likely contact.

## v0.3.16 movement consolidation
Formation template offsets are now authored in **real metres** and then only lightly scaled for terrain/training. The previous closest-pair global scaling is retired because it could turn narrow formations into very long command/medical tails.

The active spatial hierarchy is now intended to be:

`PLATOON -> SECTION GUIDE -> desired FT-A / FT-B guides -> soldier slots`

The old live majority-cluster `ARTIC_sectionAnchor` / `ARTIC_fireteamAnchor*` values remain only for legacy compatibility and are no longer updated as the primary moving reference.

Protected roles (CMD / MEDIC / 2IC) are protected through slot placement, not through permission to trail. Their catch-up behaviour uses the same own-slot rule as everyone else.
