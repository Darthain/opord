# ARTIC Battlefield Context (v0.3.13-alpha)

v0.3.12 introduced a persistent battlefield layer between commander intent and section-level tactical execution.

## Why it exists

A commander objective such as `ATTACK 043038` is not enough context for a platoon. Once intelligence locates the enemy, ARTIC now builds a stable spatial model of the fight so every layer works from the same picture.

```text
COMMANDER OBJECTIVE / UAS INTELLIGENCE
                 ↓
          BATTLEFIELD CONTEXT
                 ↓
  HOLD / FIRE / ASSAULT / LIMIT LINES
                 ↓
 FIX / LEFT / RIGHT / RESERVE assignments
                 ↓
 SECTION + FIRETEAM + INDIVIDUAL execution
```

## Battlefield classification

A recon/UAS report with multiple hostile contacts can classify an area as a battlefield before the infantry makes direct contact.

The commander records:
- battlefield centre and radius;
- source and confidence;
- estimated enemy size (TEAM / SECTION / PLATOON / COMPANY+);
- infantry / vehicle / armour / static-weapon / air counts;
- freshness of the intelligence.

Ground reports can refresh the field later without erasing a fresher high-confidence UAS classification.

## Friendly force assessment

The tactical formation sent to the battlefield is assessed for:
- total fit strength;
- machine guns;
- grenadiers;
- AT / AA;
- medics / engineers;
- vehicles;
- recon UAS;
- AP / AT FPV capability;
- linked commander fire support.

ARTIC compares this against the known enemy estimate and creates a rough force ratio and attack plan such as:
- `FIX_LEFT_RIGHT`;
- `TWO_AXIS_WITH_RESERVE`;
- `FIX_SINGLE_FLANK`;
- `HOLD_FOR_SUPPORT`;
- `HOLD_FOR_ANTI_ARMOUR`.

This is an estimate based on known contacts, not omniscient knowledge.

## Persistent battle geometry

Once created, the geometry remains stable for the life of that battlefield unless the battle is explicitly replanned.

ARTIC generates:
- **HOLD line** — platoon staging line before the tactical action;
- **FIRE line / FIX position** — base-of-fire reference;
- **ASSAULT line** — last coordinated position before the final assault;
- **Limit of Advance** — forward control boundary;
- **LEFT and RIGHT manoeuvre corridors**;
- **reserve / rally positions**;
- **left and right battlefield boundaries**;
- **assigned fire sectors**.

A target moving 20 metres does not cause the whole plan to switch sides.

## Coordinated approach

If UAS detects the enemy early, the platoon continues moving as a platoon toward the battlefield HOLD line rather than treating radio/UAS knowledge as direct contact.

The platoon controller now tracks section guide positions, not the physical squad leaders. Leaders and medics remain protected members inside the section formation and no longer represent the entire section's position.

Once the HOLD line is occupied, the tactical scheme takes over:
- FIX moves to the fire line;
- LEFT and RIGHT enter their assigned corridors;
- sections synchronize through phase gates;
- assault occurs from the persistent assault line if the force assessment permits it.

## Fire sectors

Each section receives a battlefield fire sector. FIX receives the full enemy frontage; LEFT and RIGHT prefer contacts in their respective halves. Target scoring now rewards contacts inside the assigned sector and penalizes contacts outside it.

## Individual combat integration

Battlefield context is also available to soldiers through their group:
- battle axis;
- friendly rear;
- assigned corridor;
- known enemy focus;
- section fire sector;
- assault/hold geometry.

v0.3.12 also upgrades danger reactions to count multiple hostile LOS threats and recent active shooters. Cover searches score positions by how many hostile sight lines they actually break, rather than only generic cover quality.


## v0.3.13 doctrine-informed control measures
The battlefield now adds a PLD and final coordination line (FCL), terrain-scored section approach routes, and role-specific route ownership. HOLD functions as the attack/staging area, FIRE/SBF is the fixing position, ASSAULT is the last covered assault position, FCL controls final formation/fire shift, and LOA prevents overrun.


## v0.3.15
- **Sight:** fire positions are chosen on how much of the known enemy they can actually see
  (VIEW/FIRE LODs, prone and kneeling), hold/approach/assault positions on being hidden.
- **Distances** come from terrain, visibility and weapons (`fn_getBattleEnvelope`).
- **Shapes:** FIX_LEFT_RIGHT, TWO_AXIS_RESERVE, SINGLE_FLANK, DOUBLE_ENVELOPMENT, BREAK_IN,
  HOLD - each generates its own control points; plays read them through the same group
  variables as before.
- **Sectors:** platoons on the same battlefield take adjacent sectors.
- **Defence:** DEFEND orders build an engagement area, trigger line, battle positions (with
  alternates), PDF / FPL and an OP (`fn_buildDefenceContext`). Static weapon deployment
  (see TACTICS_LIBRARY.md) will use these positions.


## v0.3.24 — plan lock, fire line, contact coordination
- The plan is locked during execution; new COAs need a clear margin.
- The SBF is occupied as a fire line of individual firing points.
- Sections send contact calls; the platoon shares them, shifts FIX fire / assigns support
  by fire during an attack, or launches a hasty attack before release. If FIX fails, the
  manoeuvre section with the best sight takes over as base of fire.
