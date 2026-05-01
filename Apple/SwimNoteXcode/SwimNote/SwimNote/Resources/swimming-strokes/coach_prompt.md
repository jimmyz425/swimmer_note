# Swimming Coach Weekly Training Plan Prompt

> Part of [[areas/swimming-strokes|Swimming Strokes Research]] · Agent: [[.claude/agents/swimming-coach|Swimming Coach Agent]]

---

## How to Use

Pass this prompt to the swimming coach agent along with the swimmer's profile:

```
Generate a weekly training plan for:
- Age: [age]
- Level: [beginner / intermediate / advanced / elite]
- Primary stroke(s): [freestyle / backstroke / breaststroke / butterfly / IM]
- Pool access: [short course / long course / both]
- Sessions per week: [3 / 4 / 5 / 6]
- Focus area: [technique / speed / endurance / race prep]
- Dry land time available: [0 / 15 / 30 / 45 minutes per day]
- Injuries or limitations: [none / describe]
```

The agent will generate a plan below.

---

## Agent Instructions (for the Swimming Coach)

You are generating a weekly training plan based on the technique documentation in `resources/swimming-strokes/`. Use the following rules:

### 1. Swimmer Profile Assessment

Map the swimmer's level to your knowledge of the tiered targets in each technique file:

| Level | Typical Profile |
|-------|----------------|
| **Beginner** | Age-group (under 12) or adult learner. Focus: body position, basic stroke mechanics, comfort in water. Use "Beginner" tier targets from technique files. |
| **Intermediate** | High school / club swimmer. Consistent technique at moderate pace. Use "Intermediate" tier targets. Introduce competitive drills. |
| **Advanced** | Collegiate / national-level. Refined technique at race pace. Use "Advanced" tier targets. Heavy emphasis on starts, turns, race strategy. |
| **Elite** | Olympic / world championship level. Use "Elite" tier targets. Focus on fine-tuning, race-specific pacing, recovery management. |

### 2. Weekly Plan Structure

Generate a table-based plan with these columns:

| Day | Pool Session (duration) | Focus | Dry Land |
|-----|------------------------|-------|----------|

Each pool session should include:
- **Warm-up** (10-15% of session distance)
- **Drill set** (20-30% of session distance) — reference specific drills from technique files
- **Main set** (40-50% of session distance) — pace work, intervals, or race-specific
- **Cool-down** (10% of session distance)

### 3. Drill Selection Rules

- Reference drills by name from the technique files (e.g., `[[resources/swimming-strokes/freestyle-02-flutter-kick]]` — Vertical Kicking)
- Select drills that match the swimmer's **focus area** and **level**
- Use **Specific Drills** for beginners/intermediate, **Competitive Drills** for advanced/elite
- Rotate strokes in IM training; prioritize primary stroke(s) for specialists
- Include at least one drill from the swimmer's focus technique per relevant session

### 4. Dry Land Integration

Reference dry-land exercises from the appropriate dry-land training file (e.g., `[[resources/swimming-strokes/freestyle-dry-land-training]]`). Rules:

- **Beginners:** Core & flexibility only. No heavy resistance. Focus on body awareness.
- **Intermediate:** Add light resistance bands. 2-3 exercise categories per week.
- **Advanced:** Full dry-land program. Include strength, power, and flexibility. 3-4 categories per week.
- **Elite:** Periodized dry-land. Match gym work to swim phase. Include plyometrics and sport-specific power.

Age considerations:
- **Under 12:** Bodyweight only. No weights. Focus on movement quality, fun, and coordination.
- **12-15:** Light resistance bands. Introduce basic strength exercises. No heavy lifting.
- **16-18:** Progressive resistance. Can introduce light free weights with proper form.
- **Adult masters:** Emphasize flexibility, joint health, and injury prevention over power.

### 5. Session Distance Guidelines

Base total weekly distance on age and level:

| Level | Ages | Total Weekly Distance (per week) | Per Session (avg) |
|-------|------|-----------------------------------|-------------------|
| Beginner | 6-10 | 3,000-5,000m | 600-1,200m |
| Beginner | 11-14 | 5,000-8,000m | 1,000-1,600m |
| Beginner | 15+ | 6,000-10,000m | 1,200-2,000m |
| Intermediate | 11-14 | 8,000-15,000m | 1,600-3,000m |
| Intermediate | 15-18 | 15,000-25,000m | 3,000-5,000m |
| Intermediate | 18+ (masters) | 10,000-20,000m | 2,000-4,000m |
| Advanced | 15-18 | 25,000-40,000m | 5,000-8,000m |
| Advanced | 18+ | 20,000-35,000m | 4,000-7,000m |
| Elite | 16+ | 40,000-60,000m+ | 7,000-10,000m+ |

> [!note] These are coaching guidelines, not absolutes
> Distances vary based on swimmer recovery capacity, taper periods, race schedule, and individual physiology. Reduce by 20-30% during recovery weeks (every 4th week).

### 6. Output Format

Generate the plan in this exact structure:

```markdown
# Weekly Training Plan — [Level] Swimmer, Age [X]

**Profile:** [summarize inputs]
**Week focus:** [primary technical + physical objective]
**Total distance:** ~[X]m across [Y] sessions

---

## Training Schedule

| Day | Pool Session | Focus | Dry Land |
|-----|-------------|-------|----------|
| Mon | [details] | [focus] | [exercises or Rest] |
| Tue | [details] | [focus] | [exercises or Rest] |
| Wed | [details] | [focus] | [exercises or Rest] |
| Thu | [details] | [focus] | [exercises or Rest] |
| Fri | [details] | [focus] | [exercises or Rest] |
| Sat | [details] | [focus] | [exercises or Rest] |
| Sun | [Rest or Light] | Recovery | [Stretching or Rest] |

---

## Detailed Sessions

### [Day] — [Focus]

**Warm-up:** [X]m — [drill description]
**Drill set:** [X]m — [specific drill from technique file]
**Main set:** [X]m — [pace/intervals]
**Cool-down:** [X]m — [description]

**Technique focus:** [which technique file this targets, e.g., [[resources/swimming-strokes/freestyle-03-breathing-technique|Breathing Technique]]]

### [Day] — ...

---

## Dry Land Program

| Exercise | Sets x Reps | Focus |
|----------|-------------|-------|
| [from dry-land file] | [details] | [which technique it supports] |

---

## Weekly Goals

| Metric | Target | How to measure |
|--------|--------|---------------|
| [e.g., stroke count per 25m] | [target from tiered targets] | [count/video] |
| ... | ... | ... |

---

## Notes

- Week [X] of [training cycle]
- [Recovery notes, taper info, race prep notes if applicable]
- [Technique reminders from lesson files]
```

### 7. Quality Checks Before Output

- [ ] All drill references link to actual technique files
- [ ] All dry-land exercises link to the appropriate dry-land training file
- [ ] Session distances match the level/age guidelines in the table above
- [ ] Tiered target benchmarks match the swimmer's level (Beginner uses Beginner targets, etc.)
- [ ] At least one rest day is included
- [ ] Dry-land volume matches the "Dry land time available" input
- [ ] Age-appropriate restrictions applied (no weights for under 12, etc.)
- [ ] Focus area is represented in at least 2 sessions per week
