# LLM Training Plan Generation Inputs

This document summarizes all the data and context fed to the LLM when generating a weekly training plan in SwimNote.

---

## Overview

The training plan generation uses a **strategy-based architecture** with multiple inputs combined to create a comprehensive prompt for the LLM:

1. **PlanContext** - User profile, training history, and settings
2. **Strategy Prompts** - Type-specific rules and JSON output templates
3. **Tool Definitions** - Functions the LLM can call for additional data
4. **Guidance Files** - Coaching reference documents

---

## 1. PlanContext (Dynamic User Data)

### UserProfile

```swift
public struct UserProfile {
    var id: String
    var name: String
    var birthday: String         // → calculates age
    var sex: Sex                 // male, female, other
    var skillLevel: SkillLevel   // beginner, intermediate, advanced, competitive, elite
    var weeklySessionTarget: Int // sessions per week (3-6)
    var preferredStrokes: [StrokeID]
    var mainStroke: StrokeID?    // Primary focus
    var distancePreference: DistancePreference // short, mid, long, na
    var preferredDistanceUnit: DistanceUnit    // meters, yards
    var personalBests: PersonalBests           // 50m/50yd times for each stroke
    var cssHistory: CSSHistory?                // Critical Swim Speed test results
    var trainingGoals: [String]
    var limitations: [String]?
}
```

**Fed to LLM as:**
```
SWIMMER: Alex, Age 8, Level intermediate
TARGET: 3 sessions/week
STROKES: freestyle, backstroke
PBs: Free 38.5s, Back 42.0s
CSS: 1:45/100m (tested 2026-04-15, freestyle)
CSS TREND: improving
```

### Training History

- Past training notes (last 7-30 days)
- Stroke focus from previous sessions
- Goals attempted and their status
- Observations and coaching tips

**Derived metrics:**
- `StrokeBalanceInfo` - Percentage of sessions per stroke (last 14 days)
- `GoalProgressInfo` - Categorized as achieved, struggling, or inProgress

**Fed to LLM as:**
```
STROKE BALANCE (last 14 days):
- freestyle: 5 sessions (60%)
- backstroke: 2 sessions (24%)
- breaststroke: 0 sessions (0%) - NEGLECTED
- butterfly: 1 session (12%)

ACHIEVED: freestyle: body position → next level
STRUGGLING: freestyle: flip turn timing → easier prerequisite
```

### Settings

- `poolType`: shortCourse (25m), longCourse (50m), both
- `sessionsPerWeek`: 3-6
- `includeDryLand`: true/false

---

## 2. Strategy Prompts (Plan Type Specific)

### Available Strategies

| PlanType | Description | Key Rules |
|----------|-------------|-----------|
| `mixed` | Balanced club training | 30% Zone 1-2, 40% Zone 3-4, 20% Zone 5, 10% Zone 0 |
| `recovery` | Active recovery week | 50% normal distance, 2x rest intervals, NO sprint |
| `endurance` | Distance building | 60%+ main sets, threshold pace, age-based volume limits |
| `technique` | Technique mastery | 40% drills (vs 20%), LOW intensity, multiple technique refs |
| `dryLandOnly` | No pool sessions | Core 30%, Rotation 20%, Shoulder 25%, Flexibility 25% |
| `racePrep` | Competition readiness | 20% volume reduction, start/turn practice, race simulation |
| `speed` | Sprint & pace work | 1:4 work:rest ratio, overspeed drills, power dry-land |

### Core Prompt Structure (Mixed Training)

```
MANDATORY FIRST STEPS (call these tools BEFORE generating the plan):

1. Call get_css_info() to get CSS test results
2. Call read_interval_research(section: "zones") for zone definitions
3. Call read_interval_research(section: "levels") for swimmer adjustments

STEP 1: DETERMINE SESSION ZONES AND VOLUMES
- Use CSS zone paces for interval targets
- Match volumes to skill level
- Zone distribution: 30% Z1-2, 40% Z3-4, 20% Z5, 10% Z0

STEP 2: BUILD THE PLAN
[base prompt with swimmer context]

RULES:
- ACHIEVED goals → next technique OR revisit fundamentals
- STRUGGLING → easier prerequisite
- FUNDAMENTALS (1-3): include in 30%+ of sessions
- NEGLECTED strokes: at least 1 session each
```

### Weekly Distance Targets

| Skill Level | Weekly Total (3 sessions) | Per Session |
|-------------|--------------------------|-------------|
| Beginner | 1,500m | 500m |
| Intermediate | 2,200m | ~733m |
| Advanced | 3,500m | ~1,167m |
| Competitive | 5,000m | ~1,667m |
| Elite | 8,000m | ~2,667m |

*Adjusted for pool type (long course = 2x) and sessions per week*

---

## 3. Tool Definitions (LLM Function Calling)

### Available Tools

| Tool | Purpose | Returns |
|------|---------|---------|
| `get_user_profile` | Swimmer profile | age, level, PBs, goals |
| `get_training_history` | Past notes | dates, stroke focus, goals |
| `get_active_goals` | Current goals | pending/active goals |
| `get_training_calendar` | Session frequency | calendar view of sessions |
| `get_css_info` | CSS test results | pace per 100m, zone offsets |
| `read_interval_research` | Training science | zones, intervals, periodization |
| `read_technique_file` | Technique wiki | drills, tiered targets |
| `list_technique_files` | File listing | available technique files |
| `search_content` | Keyword search | matching files |
| `get_related_techniques` | Navigation | prev/next technique links |

### CSS Zone Offsets

```
Zone 0: Recovery     → CSS +20-30s/100m
Zone 1: Aerobic Base → CSS +10-15s/100m
Zone 2: Aerobic End  → CSS +5-10s/100m
Zone 3: Tempo        → CSS +0-5s/100m
Zone 4: Threshold    → CSS to -2s/100m
Zone 5: VO2max       → CSS -3-6s/100m
Zone 6: Sprint       → Race pace
```

### Rest Intervals by Zone

| Zone | Rest Seconds | Rest Ratio |
|------|-------------|------------|
| 0 | 60-120s | 50-100% of work |
| 1 | 12-20s | 15-25% of work |
| 2 | 8-16s | 10-20% of work |
| 3 | 8-12s | 10-15% of work |
| 4 | 4-12s | 5-15% of work |
| 5 | 24-40s | 30-50% of work |
| 6 | 180-300s | 3-5 minutes |

---

## 4. Guidance Files (Reference Documents)

### coach_prompt.md

Contains:
- Swimmer level assessment (Beginner → Elite tier mapping)
- Weekly plan structure (warmup 15%, drills 20-30%, main 40-50%, cooldown 10%)
- Drill selection rules (Specific Drills vs Competitive Drills)
- Dry-land integration by age group
- Session distance guidelines by level/age
- Output format template
- Quality checks checklist

### swimming-interval-training-research.md

Contains:
- Training zone definitions (Zones 0-6)
- Interval calculation methods (CSS-based, HR-based, send-off times)
- Volume recommendations by skill level
- Sample sets for each zone
- Periodization guidance
- Event-specific considerations (sprint vs distance)
- Swimmer level adjustments

### Technique Files Structure

```
Main stroke files:
- freestyle.md → technique table (1-9 difficulty ranking)
- backstroke.md, breaststroke.md, butterfly.md

Sub-technique files:
- freestyle-01-body-position.md → Beginner tier targets
- freestyle-08-catch-evf.md → Advanced/Elite tier targets

Each file contains:
- Overview and difficulty level
- Key points
- Common mistakes
- Specific drills
- Competitive drills with tiered targets (Beginner → Elite)
```

### Dry-Land Training Files

```
- freestyle-dry-land-training.md
- backstroke-dry-land-training.md
- breaststroke-dry-land-training.md
- butterfly-dry-land-training.md

Categories:
- Core (planks, bridges, stability)
- Rotation (medicine ball, cable rotations)
- Shoulder/Arm (bands, swim-specific movements)
- Flexibility (dynamic stretches, yoga)
```

---

## 5. JSON Output Schema

### WeeklyTrainingPlan

```json
{
  "overview": {
    "weekFocus": "string",
    "swimmerSummary": "computed from profile",
    "pastMonthAnalysis": "computed from history",
    "technicalObjective": "string",
    "physicalObjective": "string",
    "sessionCount": "from settings",
    "totalDistance": "computed from sessions"
  },
  "schedule": [{
    "id": "sched-1",
    "sessionNumber": 1,
    "poolSession": "Freestyle Sprint Focus",
    "duration": "60 min",
    "focus": "Sprint technique",
    "dryLand": "Core workout",
    "sessionType": "sprint"
  }],
  "detailedSessions": [{
    "id": "session-1",
    "sessionNumber": 1,
    "focus": "Freestyle Sprint Technique",
    "warmUp": {
      "sets": [
        {"repeatCount": 4, "distancePerRep": 50, "swimSeconds": 55, "item": "easy freestyle", "zone": 1, "restSeconds": 15}
      ],
      "zone": 1
    },
    "drillSet": { "sets": [...], "zone": 2 },
    "mainSet": { "sets": [...], "zone": 4 },
    "secondarySet": { "sets": [...], "zone": 2 },  // optional
    "coolDown": { "sets": [...], "zone": 0 },
    "techniqueFocus": "High elbow catch",
    "techniqueFileRef": "freestyle-08-catch-evf",
    "addressesGoal": "Reduce stroke count",
    "sessionType": "sprint",
    "progressionRationale": "string",
    "sessionNotes": "string"
  }],
  "dryLandProgram": [{
    "id": "dryland-1",
    "exercise": "Plank holds",
    "setsReps": "3x30 seconds",
    "focus": "Core",
    "techniqueSupport": "Body position stability"
  }],
  "techniqueProgressPlan": {
    "continueGoals": ["array"],
    "achievedGoalsNextLevel": ["array"],
    "revisitGoals": ["array"],
    "newGoals": ["array"],
    "fundamentalRevisitGoals": ["array"]
  },
  "notes": "string"
}
```

### SetItem (Critical for Distance Calculation)

```json
{
  "repeatCount": 6,        // Int - number of repetitions
  "distancePerRep": 50,    // Int - meters per rep (nil for timed sets)
  "swimSeconds": 55,       // Int - swim time per rep (from CSS zone pace)
  "restSeconds": 15,       // Int - rest between reps (from zone)
  "item": "freestyle swim",// String - description
  "notes": "smooth tempo", // String - additional notes
  "zone": 4                // Int - training zone 0-6
}
```

**Distance computed programmatically:** `total = repeatCount × distancePerRep`

---

## 6. Self-Review Checklist (LLM Must Verify)

Before outputting, the LLM must verify:

1. **Distance Math**: Sum of (repeatCount × distancePerRep) matches stated totals
2. **Session Totals**: Each session ~weeklyTarget/sessionsCount
3. **Zone Fields**: Every set AND segment has zone (Int 0-6)
4. **Swim Seconds**: If CSS available, swimSeconds = distance × zone pace
5. **Rest Seconds**: Appropriate for zone (Z0: 60-120s, Z4: 4-12s, etc.)
6. **JSON Validity**: All Int fields are numbers, not strings
7. **Complete Sessions**: Exactly sessionsPerWeek sessions generated
8. **Fundamentals**: 30%+ sessions include fundamental revisit

---

## 7. Example Full Prompt Assembly

```
System Role: expert_swimming_coach

User Prompt:
Generate a weekly training plan.

SWIMMER: Alex, Age 8, Level intermediate
TARGET: 3 sessions/week
STROKES: freestyle, backstroke
PBs: Free 38.5s, Back 42.0s
CSS: NOT TESTED - recommend CSS test

WEEKLY TOTAL DISTANCE: 2200m
Each session should be roughly 733m

TECHNIQUE LEVELS (1-9):
FREE: 1-BodyPos | 2-Kick | 3-Breath | ...
BACK: 1-BodyPos | 2-Head | 3-Kick | ...

STROKE BALANCE (last 14 days):
- freestyle: 5 sessions (60%)
- backstroke: 2 sessions (24%)
- breaststroke: 0 sessions - NEGLECTED

ACHIEVED: freestyle: body position → next level
STRUGGLING: freestyle: flip turn timing → easier prerequisite

SETTINGS: Pool 25m, 3 sessions, DryLand Yes

[Strategy-specific rules and JSON template]

SELF-REVIEW: Verify distance math, zone fields, rest seconds...

Generate 3 sessions. Include fundamentals in 30%+ sessions.
OUTPUT ONLY JSON (after self-review passes).
```

---

## Summary

The LLM receives approximately:

- **~500-800 tokens** of user context (profile, history, goals)
- **~1,500-2,000 tokens** of strategy rules and JSON template
- **~3,000-5,000 tokens** from guidance files (via tool calls)
- **~200-300 tokens** of self-review checklist

Total input: **~5,000-8,000 tokens** before tool calls, potentially **10,000-15,000 tokens** after reading CSS info, interval research, and technique files.