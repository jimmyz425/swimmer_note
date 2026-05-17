# Swimming Coach Reference — Coaching Styles by Swimmer Tier

> Role-play reference for LLM acting as swim coach
> Compiled: 2026-05-15
> Cross-references: [[swimming-drills-evidence-based-review|Drills Evidence Review]], [[swimming-interval-training-research|Interval Training Research]], [[swimming-coaching-styles|Full Coaching Styles Detail]]

---

## How to Use This Document

When coaching a swimmer:
1. Identify their **tier** (below)
2. Choose a **coaching style** from the options for that tier
3. Apply the recommended **tricks/sets**, **focus areas**, and **avoid** the listed pitfalls
4. Adjust intensity using CSS zones from [[swimming-interval-training-research|Interval Training Research]]
5. Supplement with evidence-based drills from [[swimming-strokes/stroke-evidence-based-drills|Stroke Evidence-Based Drills]]

---

## Swimmer Tier Definitions

| Tier | Code | Description | Typical CSS | Training Age |
|---|---|---|---|---|
| **Youth Beginner** | YB | Ages 5-9, learning to swim, water familiarization | N/A | 0-1 years |
| **Youth Developing** | YD | Ages 9-12, knows all 4 strokes, learning technique | N/A | 1-3 years |
| **Novice Adult** | NA | Adult beginner or returning swimmer, can swim 200m+ but technique inconsistent | CSS > 2:00/100m | 0-2 years |
| **Intermediate** | INT | Can swim all 4 strokes with reasonable form, training 2-3x/week | CSS 1:30-2:00/100m | 2-5 years |
| **Advanced** | ADV | Competitive club/masters swimmer, training 4-5x/week, racing | CSS 1:10-1:30/100m | 5-10 years |
| **Elite** | ELT | Collegiate, national-level, or former competitive swimmer | CSS < 1:10/100m | 10+ years |
| **Sprint-Focused** | SPT | Any tier but focused on 50-100m events | Varies | Varies |
| **Distance-Focused** | DST | Any tier but focused on 400m+ events | Varies | Varies |

---

## Profile ↔ Coach Tier Mapping (SwimNote app)

SwimNote stores **USA Swimming club groups** on the profile (`TrainingTier` + `SubTier` + age + `SkillLevel` + `DistancePreference`). Coach styles in this document use **coach tiers** (YB, YD, NA, …). They are not the same labels — use the table below (implemented in app code as `CoachTierProfileMapping`).

### Age bands

| Band | Ages | Used for |
|---|---|---|
| `under_9` | &lt; 9 | YB / early YD |
| `9_12` | 9–12 | YD |
| `13_17` | 13–17 | YD, NA, or INT by club group |
| `18_plus` | 18+ | NA / INT / ADV / ELT by skill + group |

### Club group → primary coach tier

| Profile `TrainingTier` | Sub-tier | Age band | Primary coach tier(s) | Also consider | Notes |
|---|---|---|---|---|---|
| Pre-Competitive | any | under_9 | **YB** | — | Water comfort |
| Pre-Competitive | any | 9_12 | **YD** | — | FUNdamentals |
| Pre-Competitive | any | 13_17 | **YD** | NA | Late team entry |
| Pre-Competitive | any | 18_plus | **NA** | — | Adult developmental |
| Bronze | 1–3 | 9_12 | **YD** | INT (Bronze 3) | Youth competitive |
| Bronze | 1 | 13_17 | **NA** | YD | Teen new to team |
| Bronze | 2 | 13_17 | **NA** | — | Teen bronze |
| Bronze | 3 | 13_17 | **INT** | NA | → Silver transition |
| Bronze | any | 18_plus | **NA** | INT | Masters beginner default |
| Silver | 1 | 9_12 | **YD** | INT | Young silver |
| Silver | 1 | 13_17 | **INT** | — | Early silver teen |
| Silver | 2 | any | **INT** | — | Aerobic + technique |
| Silver | 3 | any | **INT** | **ADV** | → Gold |
| Silver | any | 18_plus | **INT** | — | Masters age-group |
| Gold | any | 13_17 | **ADV** | INT | Senior age-group |
| Gold | any | 18_plus | **ADV** | — | Masters gold |
| Senior | any | any | **ADV** | **ELT** | Championship; ELT if national-level skill |
| National | any | any | **ELT** | — | Elite qualifier group |

### Adults (18+) skill override

When age band is `18_plus`, a matching row may also require `SkillLevel`:

| Skill level | Typical coach tier |
|---|---|
| beginner | **NA** |
| intermediate | **INT** |
| advanced | **ADV** |
| competitive | **ADV**, **ELT** |
| elite | **ELT** |

### Event focus (additive)

| Profile `DistancePreference` | Adds coach tier |
|---|---|
| short (50–100m) | **SPT** |
| long (800m+) | **DST** |
| mid / general | — |

**UI style picker:** options from **primary** coach tier(s) only, plus **SPT** or **DST** when distance preference is short/long (~4–5 choices per section). `alsoConsider` tiers (e.g. ADV when primary is INT) are for LLM context only, not shown in the picker.

**LLM planning:** may use primary + also-consider + event-focus tiers via `CoachTierProfileMapping.resolve`.

---

## Tier → Coaching Style Mapping

Each tier lists **multiple style options**. Choose based on the swimmer's personality and goals.

---

### Tier: Youth Beginner (Ages 5-9)

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Playful Learning | Papadimitriou et al. (2021) | Default for all beginners this age |
| B | Differential Learning | Soleimani et al. (2025) | When the child has basic water comfort and is ready for variety |
| C | LTAD FUNdamentals | Balyi framework | When a structured progression is needed (e.g., club setting) |
| D | Sakamoto (adapted) | Soichi Sakamoto | When resources are limited; use creativity over facilities |

**Focus:**
- Water comfort and safety
- Basic movement patterns (kick, arm action, breathing)
- Fun and positive association with the pool
- Games, relays, exploration — NOT laps and drills

**Use:**
- Games: Shark and Minnows, Treasure Dive, Follow the Leader
- Animal strokes: "swim like a dolphin/frog/crocodile"
- Story-based swimming: narrative scenarios that require swimming
- "Choose Your Challenge" circuit: rotate stations every 25m
- Short bursts (12.5m-25m) with rest and play between
- Mixed-ability relays for inclusion

**Avoid:**
- Lap counting or distance targets
- Stroke correction mid-activity (let them explore first)
- Pressure, competition, or "winning" focus
- Long sets (> 500m total)
- Adversity training (Bowman) or discipline-heavy approaches (Sweetenham)
- Pace clocks or timing

**Key Principle:** Low cortisol = better learning. A stressed child doesn't learn. Playful methods produce **100% skill success vs. 63%** with traditional instruction (Papadimitriou et al., 2021).

---

### Tier: Youth Developing (Ages 9-12)

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Differential Learning | Soleimani et al. (2025) | Default — builds robust motor patterns during golden age of learning |
| B | McKeever (empowerment) | Teri McKeever | When the swimmer is self-motivated and ready for ownership |
| C | LTAD Learn to Train | Balyi framework | When structuring technique refinement across all 4 strokes |
| D | Reese (adapted) | Eddie Reese | For steady, relationship-based progression |
| E | Touretski (light) | Gennadi Touretski | When the swimmer shows exceptional technical aptitude |

**Focus:**
- Refining technique across all 4 strokes (no specialization yet)
- Building motor variety — explore many movement patterns
- Introduction to structured sets (short, simple)
- Self-awareness: teach them to feel their stroke
- Team belonging and positive peer interaction

**Use:**
- "Mystery Length" — coach calls surprise challenges each length
- "Animal Strokes" — different animals = different movement patterns
- Post-race self-analysis: "3 things you did well, 1 to work on"
- Peer coaching: swimmers pair up to observe and give feedback
- Stroke counting (Touretski): consistent strokes per length, not necessarily fewer
- Swimmer's choice sets (McKeever): let them design one set per week
- Short structured sets: 4-8 × 25m with clear focus

**Avoid:**
- Early specialization (picking one stroke or event)
- Training to win — competition is for learning
- Adult-style aerobic sets (long slow distance)
- High-volume yardage (> 2,000m per session)
- Adversity training or pressure-based methods
- Perfectionism — "good enough" is fine at this age

**Key Principle:** Ages 9-12 are the "golden age of motor learning." Maximize variety. The nervous system is most receptive to learning new patterns now.

---

### Tier: Novice Adult

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Reese (consistency) | Eddie Reese | Default — steady, patient, relationship-focused |
| B | McKeever (empowerment) | Teri McKeever | When the swimmer is self-directed and wants ownership |
| C | Counsilman (light) | Doc Counsilman | When the swimmer is analytical/data-curious |
| D | Touretski (light) | Gennadi Touretski | When the swimmer wants to focus on technique quality |

**Focus:**
- Building consistent technique across all strokes
- Establishing a regular training routine (2-3x/week)
- CSS testing to establish baseline zones
- Confidence building in the water
- Understanding the "why" behind technique cues

**Use:**
- Video analysis (film from pool deck, review together)
- CSS testing to establish training zones
- Fist drill, tennis ball drill (Counsilman) for feel development
- Stroke counting per length (Touretski) — focus on consistency
- "Perfect 25" — one technically flawless rep before hard sets
- "Swim through your hands" cue (Reese) — feel water on forearm
- Swimmer's choice sets (McKeever) — build ownership
- Simple structured sets: 4-8 × 50m with clear focus and adequate rest

**Avoid:**
- Overloading with volume too quickly
- Comparing to competitive swimmers
- Complex sets with multiple constraints
- Adversity training — build confidence first
- Lactate work or VO2max sets until aerobic base is established
- Perfectionism — progress, not perfection

**Key Principle:** Adults learn differently from kids — they need the "why" behind instructions. But they also carry more self-consciousness. Build confidence before adding pressure.

---

### Tier: Intermediate

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Salo (data-informed) | David Salo | When the swimmer responds to numbers and measurement |
| B | Bowman (light) | Bob Bowman | When preparing for competition; build mental toughness |
| C | Touretski (technique) | Gennadi Touretski | When technique refinement is the priority |
| D | Reese (consistency) | Eddie Reese | When steady progression over seasons is the goal |
| E | McKeever (empowerment) | Teri McKeever | When the swimmer needs ownership and self-coaching skills |

**Focus:**
- Stroke rate vs. distance per stroke optimization
- Race-pace exposure (know what goal pace feels like)
- Building aerobic base (Z1-Z2 work)
- Introduction to lactate threshold work (Z4)
- Technical refinement under fatigue

**Use:**
- CSS testing and zone-based training (Z0-Z6)
- Stroke rate calibration sets (Salo): 4 × 25m at different rates, same split
- Negative-split sets (Bowman): second half faster than first
- "Texas 100" style sets (Reese): 6-10 × 100m at target pace
- Contrast sets (Touretski): hard → easy with tech focus → hard
- Tempo Ladder drills (from evidence-based drills file)
- Build & Hold sets: build SR, hold max rate for final segment
- Video-delay feedback if available

**Avoid:**
- Neglecting any stroke — all 4 should still be practiced
- Racing every week — use competition as training, not the goal
- Over-reliance on equipment (paddles, pull buoys) — develop feel without gear
- Max VO2max work (Z5) more than once per week
- Ignoring starts and turns

**Key Principle:** This is the stage where swimmers either progress to advanced or plateau. The differentiator is consistency + targeted intensity, not more volume.

---

### Tier: Advanced

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Bowman (adversity) | Bob Bowman | When preparing for championship competition |
| B | Salo (biomechanics) | David Salo | When fine-tuning technique with data |
| C | Sweetenham (discipline) | Bill Sweetenham | When the swimmer needs higher standards and accountability |
| D | Touretski (precision) | Gennadi Touretski | When marginal gains in technique are the priority |
| E | Skinner (sprint) | Jonty Skinner | For 50-200m event specialists |

**Focus:**
- Race-specific preparation (event selection, pacing strategy)
- Lactate threshold development (Z4-Z5)
- Technical precision under race conditions
- Mental preparation and visualization
- Starts, turns, and finishes

**Use:**
- Broken swims (Reese/Skinner): race distance in segments with brief rest, faster than race pace
- Worst-case scenario training (Bowman): uncomfortable conditions, broken equipment
- 100m IM conditioning sets (Bowman): 8-10 × 100 IM on tight intervals
- "Quality or quit" (Sweetenham): pull from set if standard not met
- Resistance band starts, 15m wars (Skinner)
- Stroke profile analysis (Salo): personalized optimal rate, DPS, breathing pattern
- Performance contracts (Sweetenham): written commitments to standards
- Differential Practice sets (from evidence-based drills) — maintain variety even at this level
- Video-based debriefs after every competition

**Avoid:**
- More volume — the focus should be on quality and specificity
- Neglecting recovery and lifestyle (sleep, nutrition)
- Racing too frequently — quality over quantity
- Ignoring weaker strokes entirely — maintain competence
- Copying another swimmer's training program — individualize

**Key Principle:** At this level, the gains are marginal. Focus on specificity, mental preparation, and holding standards. The swimmer who executes their race plan wins, not necessarily the fastest swimmer.

---

### Tier: Elite

**Recommended Styles (choose one or blend):**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Bowman (full) | Bob Bowman | Championship preparation, mental edge |
| B | Touretski (full) | Gennadi Touretski | Technical perfection, drag minimization |
| C | Salo (full) | David Salo | Biomechanical optimization, individualized profiles |
| D | Sweetenham (full) | Bill Sweetenham | Championship-level standards and accountability |

**Focus:**
- Peaking for specific competitions (periodization)
- Marginal gains in every area: starts, turns, underwater, stroke efficiency
- Mental rehearsal and race visualization
- Recovery optimization
- Race strategy and tactical preparation

**Use:**
- Detailed mental movie rehearsal (Bowman): visualize every stroke, turn, breath
- Long-term periodization (Bowman): 4-year or seasonal cycles with specific themes
- "Ideal stroke profile" (Salo): biomechanical analysis of optimal parameters
- Parachute at sprint pace (Touretski): maintain technique under load
- Instant video review (Skinner): feedback loop in seconds
- Taper simulation: full race-pace efforts on full rest even in heavy training
- Negative-split pyramid sets (Sweetenham): 100/200/300/400/300/200/100
- Video-based race debriefs with written correction lists

**Avoid:**
- Radical changes close to competition
- Overtraining — elite swimmers break from too much, not too little
- Comparing to other swimmers — focus on own race plan
- Neglecting the basics — even elite swimmers drift on fundamentals

**Key Principle:** At the elite level, the physical differences between swimmers are small. The winner is the one who executes their race plan under pressure. Mental preparation is as important as physical preparation.

---

### Tier: Sprint-Focused (Any Level)

**Recommended Styles:**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Skinner (sprint) | Jonty Skinner | Default for 50-100m specialists |
| B | Touretski (technique) | Gennadi Touretski | For technical precision at speed |

**Focus:**
- Starts, breakout, and first 15m underwater (highest ROI)
- Neuromuscular speed — short, explosive efforts with full recovery
- Maintaining technique at maximum velocity
- Minimal slow aerobic work

**Use:**
- Resistance band starts, hyper-gravity starts (Skinner)
- Broken 50s: 15m all-out / rest 5s / 15m / rest 5s / 20m all-out
- 15-meter wars: gamified start racing (Skinner)
- Parachute at sprint pace (Touretski)
- Taper simulation: race-pace 50m on full rest during heavy training
- Instant video review of starts and turns

**Avoid:**
- Long aerobic sets (> 200m continuous at slow pace)
- High-volume yardage without speed work
- Neglecting starts and turns in favor of swimming laps

---

### Tier: Distance-Focused (Any Level)

**Recommended Styles:**

| Option | Style | Source | When to Use |
|---|---|---|---|
| A | Bowman (endurance) | Bob Bowman | For mental toughness in long events |
| B | Reese (consistency) | Eddie Reese | For steady aerobic base building |
| C | Sweetenham (discipline) | Bill Sweetenham | For holding standards over long sets |

**Focus:**
- Aerobic base development (Z1-Z2)
- Negative-split pacing
- Mental endurance — holding focus over long distances
- Efficient stroke mechanics (minimize energy waste)

**Use:**
- Negative-split everything (Bowman): second half faster
- 100m IM conditioning sets (Bowman)
- Negative-split pyramid sets (Sweetenham)
- CSS-based aerobic sets (Z1-Z2): 10-20 × 100m on steady intervals
- Stroke efficiency focus: minimize drag, maximize DPS

**Avoid:**
- Only training slow — race-pace exposure is still needed
- Neglecting starts and turns (they matter in distance events too)
- Mindless yardage — every set should have a purpose

---

## Quick Lookup: Style → Swimmer Tier Compatibility

| Coaching Style | YB (5-9) | YD (9-12) | NA | INT | ADV | ELT | Sprint | Distance |
|---|---|---|---|---|---|---|---|---|
| **Playful Learning** | ✅ Default | ⚠️ Partial | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Differential Learning** | ⚠️ Partial | ✅ Default | ⚠️ Partial | ⚠️ Partial | ❌ | ❌ | ❌ | ❌ |
| **LTAD Framework** | ✅ Default | ✅ Default | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Sakamoto (adapted)** | ⚠️ Partial | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **McKeever** | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Reese** | ❌ | ✅ | ✅ Default | ✅ | ✅ | ⚠️ Partial | ⚠️ Partial | ✅ |
| **Counsilman (light)** | ❌ | ❌ | ⚠️ Partial | ✅ | ⚠️ Partial | ⚠️ Partial | ❌ | ❌ |
| **Touretski** | ❌ | ⚠️ Light | ⚠️ Light | ✅ | ✅ | ✅ Default | ✅ | ⚠️ Partial |
| **Salo** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ⚠️ Partial | ✅ |
| **Bowman** | ❌ | ❌ | ❌ | ⚠️ Light | ✅ | ✅ Default | ❌ | ✅ |
| **Sweetenham** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| **Skinner** | ❌ | ❌ | ❌ | ❌ | ⚠️ Partial | ⚠️ Partial | ✅ Default | ❌ |

Legend: ✅ = Good fit | ⚠️ = Adapted/light version | ❌ = Not appropriate

---

## Style Selection Decision Tree

When unsure which style to use, follow this logic:

```
What is the swimmer's age?
├── Under 9
│   └── → Playful Learning (Papadimitriou) + LTAD FUNdamentals
├── 9-12
│   └── → Differential Learning + McKeever (empowerment) + LTAD Learn to Train
├── 13+
│   │
│   What is their training age?
│   ├── 0-2 years (novice)
│   │   └── → Reese (consistency) + McKeever (empowerment)
│   ├── 2-5 years (intermediate)
│   │   └── → Salo (data) OR Touretski (technique) OR Reese (consistency)
│   ├── 5-10 years (advanced)
│   │   └── → Bowman (mental) OR Sweetenham (standards) OR Skinner (sprint)
│   └── 10+ years (elite)
│       └── → Bowman + Touretski + Salo (combine as needed)
│
What is their event focus?
├── Sprint (50-100m)
│   └── → Add Skinner to any style above
└── Distance (400m+)
    └── → Add Bowman or Reese to any style above
```

---

## Signature Sets by Coaching Style (Quick Reference)

| Style | Signature Set | Purpose | Best Tier |
|---|---|---|---|
| **Playful Learning** | Shark and Minnows, Treasure Dive | Water comfort, fun | YB |
| **Differential Learning** | Mystery Length, Animal Strokes, Choose Your Challenge | Motor variety | YD, NA |
| **Reese** | Texas 100 (6-10 × 100m at race pace), Broken swims | Race-pace feel, consistency | NA, INT, ADV |
| **McKeever** | Swimmer's Choice sets, Peer coaching, Talk test | Ownership, self-regulation | YD, NA, INT |
| **Counsilman** | Hypoventilation ladder, Tennis ball drill, Pace clock precision | CO₂ tolerance, catch feel, pacing | NA, INT, ADV |
| **Touretski** | Stroke counting, Perfect 25, Contrast sets | Technique precision, feel | INT, ADV, ELT |
| **Salo** | Stroke rate calibration, Video-delay feedback, Ideal stroke profile | Data-informed optimization | INT, ADV, ELT |
| **Bowman** | Broken goggles, 100m IM conditioning, Negative-split everything, Bonus set | Mental toughness, race prep | INT, ADV, ELT |
| **Sweetenham** | Red plate drill, Negative-split pyramid, Quality or quit, Performance contracts | Standards, discipline, accountability | ADV, ELT |
| **Skinner** | Resistance band starts, 15-meter wars, Broken 50s, Instant video review | Sprint speed, starts/turns | SPT, ADV, ELT |

---

## Evidence-Based Drill Mapping by Tier

These drills from [[swimming-strokes/stroke-evidence-based-drills|Stroke Evidence-Based Drills]] map to tiers:

| Drill Code | Drill Name | Best Tier | Style Alignment |
|---|---|---|---|
| F1, B1, BR1, FL1 | Tempo Ladder (progressive SR build) | INT, ADV, ELT | Franken et al. (2023), Bowman, Salo |
| F2, B2 | Roll Explorer (rotation angle variations) | INT, ADV, ELT | Psycharakis & Sanders, Touretski |
| F3, B3, BR2, FL2 | Differential Practice (variable practice) | YD, NA, INT, ADV | Soleimani et al. (2025), Differential Learning |
| F4, B4, BR3, FL3 | Build & Hold (race finish simulation) | INT, ADV, ELT | Bowman (race prep), Skinner |
| F5, B5, BR4, FL4 | Constraints Circuit | NA, INT, ADV | Brackley et al. (2020), Touretski |
| BR5 | Timing Explorer (phase isolation) | NA, INT, ADV | Touretski (technique focus) |
| FL5 | Rhythm Explorer (two-kick timing) | NA, INT, ADV | Touretski (technique feel) |

---

## What to NEVER Do (Across All Tiers)

| Mistake | Why It's Bad | Applies To |
|---|---|---|
| Early specialization (before age 12) | Limits motor development, causes burnout | All youth tiers |
| Training to win in FUNdamentals stage | Competition focus prevents skill exploration | YB, YD |
| Adversity training for kids | Pressure damages young learners, increases cortisol | YB, YD, NA |
| High-volume aerobic sets for pre-pubescent swimmers | Physiologically inappropriate, injury risk | YB, YD |
| Ignoring the "why" for adults | Adults need understanding to commit | NA, INT |
| Mindless repetition without variety | Research shows differential learning outperforms repetition | All tiers |
| Copying another swimmer's program | Individual differences make generic programs suboptimal | All tiers |
| Neglecting recovery and lifestyle | Sleep, nutrition, and mental health affect performance more than most coaches think | All tiers |
| Over-reliance on equipment (paddles, buoys) | Swimmers develop dependency instead of natural feel | All tiers |

---

## Cross-References

- **Intensity zones:** See [[swimming-interval-training-research|Interval Training Research]] for CSS-based Z0-Z6 definitions
- **Actionable drills:** See [[swimming-strokes/stroke-evidence-based-drills|Stroke Evidence-Based Drills]] for table-parsable drill sets
- **Full coach profiles:** See [[swimming-coaching-styles|Swimming Coaching Styles]] for detailed biographical context and extended methodology
- **Stroke technique:** See [[areas/swimming-strokes|Swimming Strokes Research]] for freestyle, backstroke, breaststroke, and butterfly technique guides
