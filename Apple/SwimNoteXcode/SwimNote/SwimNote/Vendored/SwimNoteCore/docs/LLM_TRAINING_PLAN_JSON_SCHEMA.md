# LLM training plan JSON contracts

When you change **prompts**, **repair heuristics**, or **Codable** types for planning, cross-check this file against the Swift source of truth.

## Source of truth (code)

| Concern | File |
|--------|------|
| Types, `CodingKeys`, tolerant decoding | `SwimNoteCore/Models/TrainingPlanOutput.swift` |
| Phase 1 outline decode path + repair order | `SwimNoteApp/Features/Planning/PlanningView+JSONParsingAndConversion.swift` (`parseOutlineJSON`) |
| Phase 2 detail decode | Same file (`parseDetailedSessionJSON`) |
| Phase 3 dry land extraction | Same file (`parseDryLandFromJSON`) |
| Pre-decode string fixes | `SwimNoteApp/Features/Planning/PlanningJSONRepair.swift` |
| Default prompt JSON examples | `SwimNoteCore/LLM/PlanDefaultPromptBuilders.swift` |

---

## Shared: loose string fields

`KeyedDecodingContainer.decodeLLMStringIfPresent` (in `TrainingPlanOutput.swift`) is used for **`techniqueFileRef`** on:

- `SessionOutline`
- `DetailedSession`

The model may emit a **number or bool**; those are coerced to a string when possible. **Objects/arrays** for that key are dropped (decode as `nil`) so the rest of the payload can still decode.

Prompts should still ask for a **quoted JSON string** slug (e.g. `"freestyle-05-arm-entry"`) to avoid silent loss of refs.

---

## Phase 1: `WeeklyPlanOutline` (outline generation)

Decoded with `JSONDecoder()` (default strategies). **Extra root keys are ignored** (e.g. `tierGuidance` from prompts).

### Root object (decoded keys)

| JSON key | Type | Required | Notes |
|----------|------|----------|--------|
| `overview` | object | **yes** | `PlanOverview` |
| `schedule` | array | **yes** | `[SessionOutline]` |
| `techniqueProgressPlan` | object | no | `TechniqueProgressPlan` |
| `twoWeekSummary` | object | no | `TwoWeekTrainingSummary` |
| `pastTrainingSummary` | string | no | |
| `planConnectionRationale` | string | no | |
| `notes` | string | no | defaults to `""` if omitted |
| `weekStartingDate` | date | no | Uses default `JSONDecoder` date decoding if present |
| `poolTypeRaw` | string | no | |
| `dryLandExercises` | array | no | `[MinimalDryLandExercise]` (often filled after Phase 3) |

### `goalProgressPlan` vs `techniqueProgressPlan` (critical)

- **`WeeklyPlanOutline`** reads the key **`techniqueProgressPlan`** only (no alias).
- **`WeeklyTrainingPlan`** (full persisted plan) maps **`goalProgressPlan`** → `techniqueProgressPlan` for backwards compatibility.

If an outline JSON uses **`goalProgressPlan`**, the outline decoder will **not** populate `techniqueProgressPlan`. Align prompts and strategy-specific examples with the correct target type.

### `overview` (`PlanOverview`)

| JSON key | Type | Required |
|----------|------|----------|
| `weekFocus` | string | effectively yes (defaults to `""`) |
| `pastMonthAnalysis`, `technicalObjective`, `physicalObjective`, `strokeRotationPlan`, `fundamentalRevisitPlan` | string | no |
| `raceEvent`, `sprintTarget`, `technicalObjectiveDetail` | string | no (strategy-specific) |

Keys like `swimmerSummary`, `sessionCount`, `poolType`, `totalDistance` are app-filled; the decoder accepts them if the model sends them.

### `twoWeekSummary` (`TwoWeekTrainingSummary`)

| JSON key | Type | Notes |
|----------|------|--------|
| `totalSessions` | int | defaults `0` |
| `strokeDistribution` | object | `freestyle`, `backstroke`, `breaststroke`, `butterfly` ints; default `0` each |
| `neglectedStrokes` | [string] | |
| `goalProgress` | string | field name is `goalProgress`, not `goalProgressPlan` |
| `keyTrends`, `techniqueProgression`, `coveredTechniques` | string | |

### `schedule[]` (`SessionOutline`)

| JSON key | Type | Required / default |
|----------|------|---------------------|
| `id` | string | optional (UUID generated) |
| `sessionNumber` | int | optional, default `1` |
| `dayOfWeek` | string | optional |
| `poolSession`, `focus` | string | optional in decode → default `""` |
| `sessionType`, `techniqueFocus`, `techniqueFileRef`, `addressesGoal`, `estimatedDuration`, `estimatedDistance` | string | optional; `techniqueFileRef` uses loose string decode |
| `isDetailsGenerated` | bool | optional, default `false` |
| `detailedSession` | object | optional (usually absent in Phase 1) |

### `techniqueProgressPlan` (`TechniqueProgressPlan`)

| JSON key | Type | Default if omitted |
|----------|------|--------------------|
| `continueGoals`, `achievedGoalsNextLevel`, `revisitGoals`, `newGoals` | [string] | `[]` |
| `fundamentalRevisitGoals` | [string] | `nil` |

---

## Phase 2: `DetailedSession` (per-session detail)

`parseDetailedSessionJSON` runs **`PlanningJSONRepair.repairLLMJSON`** in **default** mode (`.fullTrainingPlan`): renames like `sessions` → `detailedSessions`, injects root `notes` if missing, etc. Keep that in mind if outline-shaped JSON ever goes through this path.

### Root (`DetailedSession`)

| JSON key | Type | Required |
|----------|------|----------|
| `sessionNumber` | int | **yes** |
| `focus` | string | **yes** |
| `warmUp`, `drillSet`, `mainSet`, `coolDown` | object | **yes** (`SessionSegment`) |
| `techniqueFocus` | string | **yes** |
| `secondarySet` | object | no |
| `techniqueFileRef` | string (loose) | no |
| `addressesGoal`, `sessionType`, `progressionRationale`, `sessionNotes` | string | no |
| `id`, `scheduledDate`, `timeOfDay` (`morning` / `afternoon` / `evening`), `isCompleted`, `isAssigned` | | optional |

### `SessionSegment` (`warmUp`, `drillSet`, `mainSet`, `secondarySet`, `coolDown`)

| JSON key | Type | Default |
|----------|------|---------|
| `distance`, `description` | string | `""` |
| `drills` | [string] | optional |
| `sets` | [SetItem] | optional |
| `zone` | int | optional |

### `SetItem` (inside `sets`)

| JSON key | Type | Default |
|----------|------|---------|
| `repeatCount` | int | `1` |
| `distancePerRep`, `swimSeconds`, `restSeconds`, `zone` | int | optional |
| `item` | string | `""` |
| `equipment`, `notes` | string | optional |
| `id` | string | generated if omitted |

---

## Phase 3: dry land payload (merged into outline)

Parsed manually from a JSON object root (not full `WeeklyPlanOutline`).

| JSON key | Type | Notes |
|----------|------|--------|
| `dryLandExercises` | array | **Production path** expects this camelCase key. |
| `weeklyRationale` | string | Optional narrative; not part of `MinimalDryLandExercise` array parsing. |

Each element of `dryLandExercises` decodes as **`MinimalDryLandExercise`**:

| JSON key | Type | Notes |
|----------|------|--------|
| `stroke` | string | defaults to `"freestyle"` if omitted |
| `exerciseId` | string | **required** |
| `setsReps` | string | **required** |

`dry_land_exercises` (snake_case) is only used as a fallback in **`#if DEBUG`** inside `parseDryLandFromJSON`; **Release builds do not** try that key.

---

## Full weekly plan: `WeeklyTrainingPlan` (persistence / legacy)

Used when decoding a **complete** saved plan, not the Phase 1 outline-only shape.

| JSON key | Type | Notes |
|----------|------|--------|
| `overview` | object | **yes** |
| `schedule` | array | **yes** — `[DaySchedule]` (not `SessionOutline`) |
| `detailedSessions` | array | **yes** |
| `dryLandProgram` | array | optional; repair may rename `exercisePlan` / `dryLand` → `dryLandProgram` |
| `weeklyGoals` | array | optional; repair may rename `goals` → `weeklyGoals` |
| `goalProgressPlan` | object | **JSON key** for `TechniqueProgressPlan` (Swift property `techniqueProgressPlan`) |
| `notes` | string | defaults `""`; repair may inject empty `notes` at root |
| `weekStartingDate`, `poolTypeRaw` | | optional |

### `DaySchedule` (entries in `schedule` for full plan)

| JSON key | Type | Required |
|----------|------|----------|
| `sessionNumber` | int | **yes** (strict `decode`, not optional) |
| `poolSession`, `focus` | string | **yes** |
| `id`, `duration`, `dryLand`, `sessionType` | | optional |

---

## Outline decode pipeline (order)

`parseOutlineJSON` tries, in order:

1. Raw string as UTF-8 JSON  
2. `PlanningJSONRepair.repairLLMJSON(..., mode: .weeklyPlanOutline)`  
3. `PlanningJSONRepair.repairLLMJSON(..., mode: .fullTrainingPlan)`  

Full-plan repair last can rescue truncated legacy blobs but may **break** some outline-only shapes; prefer valid JSON + outline-safe repair.

---

## Checklist when updating LLM output

1. Identify which payload you affect: **outline** (`WeeklyPlanOutline`), **detail** (`DetailedSession`), **dry land** fragment, or **full plan** (`WeeklyTrainingPlan`).
2. Match **JSON keys** to `CodingKeys` in `TrainingPlanOutput.swift` (watch **`goalProgressPlan`** vs **`techniqueProgressPlan`**).
3. Update **`PlanDefaultPromptBuilders`** (or strategy-specific builders) so the example JSON matches the decoder.
4. Run **`PlanningJSONRepair`** mentally: will `.fullTrainingPlan` rewrites corrupt this payload?
5. Prefer **correct types** in prompts (ints vs strings, quoted `techniqueFileRef`) even when the decoder is tolerant.

---

_Last aligned with `TrainingPlanOutput.swift` and planning parsers in the SwimNote Xcode tree; update this doc when those types change._
