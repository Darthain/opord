# ARTIC AI — Battle Book drills as ARTIC state machines

Source: ANZAC Red Force Battle Book, Part 3: OPFOR TTPs (DATE, ver 1.0, 10/11/2023).
Page references are to that document. Descriptions below are paraphrased design notes for
ARTIC, not reproductions; go to the Battle Book for the doctrine itself.

Status key: **S** = section-level (one Arma group), **P** = platoon-level (several groups,
needs the commander/ORBAT layer), **V** = vehicle drill (later).

---

## 0. Principles that should shape every drill (p.1-1)

These are cross-cutting behaviour rules, not individual plays:

| Principle | ARTIC rule |
|---|---|
| Overwhelm with concurrent threats from several directions | Prefer plays with 2+ fire/manoeuvre directions; multi-group plays converge. |
| Commander central, moves to the main effort / assault force | Group leader goes with the assault element in assault plays, central otherwise. |
| Sections built around launcher and MG groups | Organise sections into Scout / Launcher / MG teams (see §1). |
| Immediate response to contact is aggression | Very close = immediate assault; otherwise immediate HE/UGL + smoke. |
| Envelopment always favoured, double especially | Doctrine weight bonus for enveloping variants; fratricide risk accepted. |
| Hug supporting fire in the assault | Support element keeps firing until the assault element is very close, then shifts. |

Doctrine mapping: these fit CONVENTIONAL / AGGRESSIVE / SPECIAL_FORCES directly. MILITIA gets the
aggression but not the coordination. RECON keeps the organisation but avoids decisive engagement.

---

## 1. Section organisation: three teams (p.5-14, p.3-6)

The dismounted section is three teams, which is a better element model than generic
support / manoeuvre / reserve:

| Team | Composition | Default job |
|---|---|---|
| **Scout** | 2 riflemen, one with a flame/smoke launcher | Short bound ahead; first contact; right-angle final assault |
| **Launcher** | launcher operator (HE/TB or smoke) + riflemen | Shock/explosive fire; keypoint strike; ambush initiation |
| **MG** | MG + riflemen | Base of fire; flanking fire |
| Commander (+ WPN/UAS operator) | leader, drone operator | Central; moves to the main effort |

ARTIC capability mapping:
- Launcher team = unit with a launcher, else grenadier (UGL), plus nearest riflemen.
- MG team = MG / autorifle capability, plus nearest riflemen.
- Scout team = remaining riflemen, preferring the one carrying smoke/UGL smoke.
- UAS operator stays with the leader (fits your UAS layer).

Training: POOR = teams assigned loosely (random riflemen); ELITE = exact assignment and
teams rebuilt after casualties.

Arma limit: one group has one formation and engine spacing. True 10–20 m inter-team
spacing needs either team-level doMove positioning (expensive, per tick) or splitting a
section into three linked groups. Recommend: keep one group, and apply team spacing
only during drills (doMove offsets), not while travelling.

---

## 2. Formations (p.2-2)

| Formation | Use | Team spacing (section) |
|---|---|---|
| Wedge | General purpose, all-round security | 10–20 m |
| Echelon L/R | Guard against a threat from that flank | 10–20 m |
| Vee | Wider axis of advance | 10–20 m |
| Line | The assault | 10–20 m |
| File / single file | Close country; street/track sides in urban | 3–10 m |

Commander sits centrally with the WPN+UAS operator. In close country the senior commander
may move behind the lead soldiers to navigate.

ARTIC: matches the OPEN/CLOSE/THREAT formation table. Add: switch to LINE only for the final
assault phase of an attack play; urban/track = FILE with teams on alternate sides (doMove
offsets left/right of the road).

The formation at the moment of contact selects the quick-attack variant (§4, §5).

---

## 3. Immediate Action — contact in close country (p.2-3, p.5-14)  **S** (and **P**)

Trigger: sudden contact / ambush at close range in close country.

1. **Very close enemy** → Scout team assaults, firing (no drill).
2. **Otherwise – "spin":**
   - Point/Scout team fires smoke + HE and breaks clear of the killing area to the side of
     the axis *away* from the contact.
   - Launcher fires one explosive round immediately.
   - Commander leads the Launcher/weapon team forward on the *contact* side and fires HE.
   (Push forward on one side, pull back on the other = the "spin".)
3. **Build base of fire:** the following team (MG, brought up by the 2IC) closes up on the
   outside of the commander and fires; the point adds crossing fire.
4. **Decision – Assault or Break:**
   - *Assault:* the third team closes behind the base of fire and the commander leads it
     round to outflank.
   - *Break:* point team bounds to the rear first, then the second bounds past the third
     (same caterpillar as ARTIC's PEEL, but starting from the spin geometry).

ARTIC implementation:
- New contact drill `IA_CLOSE_COUNTRY`, implemented as an ARTIC-native contact drill when
  terrain density = CLOSE and doctrine ∈ {CONVENTIONAL, SPECIAL_FORCES, RECON}.
- "Very close" threshold ≈ 25–30 m.
- Assault/Break decision = the existing selector (pressure, doctrine) but only between
  `ASSAULT_FLANK` and `PEEL`. RECON almost always breaks.
- Training: POOR skips the spin (everyone goes to ground, then simple ARTIC reactions);
  REGULAR does spin + base of fire; VETERAN+ adds the crossing fire and a fast decision.

---

## 4. Quick attack from Wedge (p.2-4)  **S**

Selected when contact occurs while in WEDGE.

**Variant A – flanking attack (contact on point):**
1. Point team, in contact, fixes.
2. Commander leads the remaining teams on a flanking attack.
3. Weapons team deploys on the *open* flank: flank security + converging fire on the enemy.

**Variant B – attack with enveloping fire support (enemy toward one flank) — favoured:**
1. Lead team and one flank team push forward onto *both* sides of the enemy position,
   enveloping it with fire from two directions.
2. Commander leads the remaining team to assault *between* the two fire teams.

ARTIC: Variant B is the signature North Torbian quick attack (simple and fast).
- Fire element 1 = MG team, fire element 2 = Launcher team, assault = Scout team + leader.
- Fire positions: ±50–70° either side of the enemy bearing at ~60–100 m from the enemy.
- Assault axis: straight between them; fire teams shift fire when the assault is inside
  ~40 m (the "hug" rule).
- Doctrine: CONVENTIONAL, AGGRESSIVE, SPECIAL_FORCES high; MILITIA low (can't coordinate).
- Training gate: B requires coordination ≥ REGULAR; POOR falls back to A or a frontal rush.

---

## 5. Quick attack from Vee (p.2-5)  **S**

Selected when contact occurs while in VEE.

**Variant A – enemy forward and centre (enveloping fire support):**
1. Commander pushes teams forward on either side until both can fire.
2. Commander leads the remaining team into the assault between them, pushing the weapons
   element forward as well for shock effect and as the visible signal that the assault is on.

**Variant B – enemy in front of one flank (flanking attack):**
1. Commander leads the remaining teams on a flanking assault.
2. Weapons element deploys on the outside flank for flank security and converging fire.

ARTIC: same state machine as §4 with different starting geometry; the "weapons element moves
forward as the assault signal" is the trigger for the fire teams to lift/shift.

---

## 6. Section break-in drill (p.3-6)  **S** — attacking a prepared position

Uses an **ultimate assault line (UAL)**: the closest point the assault can reach without being
hit by its own explosive fire.

1. Section advances in extended line (LINE) to the UAL, silently or by fire and movement.
2. **Neutralise & screen the keypoint:** Launcher team hits the keypoint (HE/thermobaric);
   smoke is placed *behind* the keypoint to isolate it; Scout and MG teams dash forward on
   one flank.
3. **Outflank:** MG team suppresses the keypoint from the flank; Scout team covers depth
   threats so the Launcher team can dash forward.
4. **Unlock:** Scout team dashes in, swinging wide away from the MG's fire to arrive at right
   angles to it; grenades/charges before entering; clearing continues with explosives.

ARTIC:
- Play `BREAK_IN` for DEFEND/fortified targets (enemy indoor/fortified = true).
- Keypoint = the enemy position with most known enemies or the MG.
- UAL ≈ 60–80 m (outside own HE splash).
- Right-angle rule: Scout approach vector ≥ 70° off the MG's line of fire (prevents fratricide
  and is a nice visible behaviour).
- Grenades before entry: an ARTIC-native grenade/throw decision before the clearing element enters.
- Doctrine: CONVENTIONAL, SPECIAL_FORCES high; AGGRESSIVE medium (prefers shock attack).

---

## 7. Section immediate "mouth" ambush (p.5-15)  **S**

Trigger: enemy seen *before* it sees the section (enemy knowsAbout of us low, ours high).

1. Scout team halts in cover on one side of the axis.
2. On the leader's signal: Launcher team closes up and moves off the axis on the Scouts' side;
   MG team moves off on the *opposite* side. (Two weapons teams = the mouth, scouts = tongue.)
3. Launcher initiates with an explosive round; everyone engages together.
4. Leader does not stay static: either push the two weapons teams forward alternately to
   envelop the site (accepting fire toward own teams), or withdraw rapidly.

ARTIC:
- Play `HASTY_AMBUSH`. Check every tick while not in contact: target known, target's
  knowsAbout of our leader < 1, distance 60–250 m, enemy moving toward us.
- Wait for the enemy to close to ~40–80 m (training: POOR springs early).
- After initiation: selector chooses `ENVELOP` (alternating team bounds) or `PEEL`.
- Doctrine: INSURGENT, SPECIAL_FORCES, RECON high; DEFENSIVE medium.
- Anti-armour variant: teams move further out for minimum arming distance.

---

## 8. Platoon drills  **P** (need the commander/ORBAT layer)

**Unlock from flank (p.3-7):** platoon reaches the UAL and fires; one flank section pushes
forward to clear a keypoint; the foothold then fires across the rest of the position; the
platoon commander goes with (and reinforces) the unlocking section.

**Unlock from centre (p.3-8):** same, but the centre section seizes a central keypoint, then
the flank sections clear to their fronts in turn (right, then left).

**'Y' harbour / deliberate ambush (p.5-16, 5-17):** platoon in single file forms a Y at the
halt; sections sited soldier by soldier with the MG group at the tips. For a deliberate
ambush the MG teams go out first as cut-off/security groups, then the two forward sections
are sited as the ambush group, the rear section stays as reserve.

ARTIC: these become commander-level plays that task 3 section groups with the section plays
above (BREAK_IN for the unlocking section, SUPPORT_BY_FIRE for the others). The Y harbour is a
good default *halt* layout for any platoon in close country.

---

## 9. Defence (ch.6, ch.9)  — fits your engineering layer

**Simple Battle Position (SBP)** – astride the enemy axis; fight from it, then abandon.
- Action section in team fighting positions covering the fire pocket; MGs and GLs from the
  other sections are pooled with it.
- Remaining sections in pairs positions for security of the action element.

**Complex Battle Position (CBP)** – off the enemy axis, concealment first, survive, then emerge
to ambush/counter-attack or exfiltrate; arcs of fire point toward *neighbouring* sections
(inward-sited); willing to call indirect fire onto own protected positions.

**Pairs / team fighting positions** – ground-level, T-shaped, heavily camouflaged; team
positions have one protected key firing point.

**Functional elements (ch.9):** disruption, main defence, reserve, support, deception.

ARTIC mapping for `PREPARE_BATTLE_POSITION`:
- Layout choice: SBP (DEFENSIVE/CONVENTIONAL on an axis) vs CBP (INSURGENT/SPECIAL_FORCES/RECON
  or when outmatched).
- Pairs position ≈ 2× short envelope in a T; team position ≈ long envelope + short envelope;
  camo net over each (Pook). Concealment before cover: VETERAN+ builds nets first.
- Disruption element: 2–4 men forward on the approach, withdraw on contact (reuse PEEL).
- Deception element: dummy positions (empty envelopes + nets) — "Dummy/deception positions"
  in your matrix.
- CBP rule: don't fight a protracted small-arms battle; break at pressure > threshold.
- IEDs/obstacles on approaches: IEDD adapter (see §11).

---

## 10. Urban (ch.8)

Useful now:
- **Obscured manoeuvre:** smoke along the axis and flanks to create a transit corridor
  → extend the smokescreen function to lay a corridor, not just a wall.
- **Explosive-first clearing (Trishula, 3-man team):** a human should not be the first thing
  into a room — grenade/charge first, then enter. → Section CQB play: the Scout team becomes
  the clearing team; the individual CQB primitives remain an ARTIC-native future implementation.
- **Urban delay:** concealed OP + demolition + remote/directional weapon on the kill area +
  off-route mines + loitering munitions to cover the OP's withdrawal.
  → maps directly onto your UAS (Crocus FPV) and IED layers.

Later (vehicles): continuous/bounding urban advance, shock attack, drop-and-support,
3D defilade, blindfire.

---

## 11. Irregular tactics (ch.9)

**Ambush types** – choose by purpose:

| Type | Behaviour | ARTIC |
|---|---|---|
| Annihilation | Stay until the kill zone is combat ineffective, then secure/search; withdraw ambush → support → security | INSURGENT/SF deliberate ambush; needs IED/obstacles to hold the enemy |
| Harassment | Longer range (max effective range), never accept decisive engagement, IEDs/mines to delay pursuit | Default INSURGENT/MILITIA ambush; always ends in PEEL |
| Containment | Security task within a larger action; blocks an approach | Commander-level: task a group to cover a QRF route |

Elements for ambush, assault and raid: **ambush/assault/raiding**, **security**, **support**;
commander usually with the support element.

Other plays: **Raid** (hit a stationary target, planned withdrawal, security blocks the QRF
route), **Reconnaissance attack** (recon elements find and fix, action elements strike on
their reports) — the second fits your UAS contact-report loop well.

Notable behaviours worth modelling: repeat ambushes at a previously successful location;
secondary ambushes on responding forces; targeting casualty-evacuation efforts.

---

## Suggested build order

1. Team-based section organisation (§1) — every drill below depends on it.
2. `IA_CLOSE_COUNTRY` contact drill (§3) + formation-aware quick attacks (§4, §5).
3. `HASTY_AMBUSH` (mouth ambush, §7) and harassment ambush (§11).
4. `BREAK_IN` (§6) for fortified targets.
5. SBP/CBP layouts, disruption and deception elements (§9).
6. Platoon unlocks and Y harbour (§8) on the commander layer.
