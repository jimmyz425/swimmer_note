# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwimNote Native - A SwiftUI iOS/macOS app for swimmers to track training sessions, set technique goals, and explore stroke-specific technique trees with competitive tier targets.

## Commands

```bash
# Open in Xcode
open SwimNote.xcodeproj

# Build from CLI (optional)
xcodebuild -project SwimNote.xcodeproj -scheme SwimNote -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests from CLI (optional)
xcodebuild -project SwimNote.xcodeproj -scheme SwimNote -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Architecture

### Vendored Modules

Code is split into two vendored modules under `SwimNote/Vendored/`:

| Module | Purpose | Key Files |
|--------|---------|-----------|
| SwimNoteCore | Domain models, persistence, LLM client | `Models/SwimModels.swift`, `Persistence/*.swift`, `LLM/LLMService.swift` |
| SwimNoteApp | SwiftUI views, app model, design system | `SwimNoteAppModel.swift`, `RootView.swift`, `Features/**/*.swift` |

### Data Storage

JSON files in Application Support directory:
- Notes: `notes/{userId}/{YYYY-MM-DD}.json`
- Profiles: `config/profiles/{uuid}.json`
- Active profile: `config/active_profile.json`
- API keys: Keychain (service: `SwimNote.LLM`)

### Navigation

`RootView` conditionally renders: Welcome → UserSetup → UserSelection → TabView(4 tabs)
- Dashboard → NavigationStack → TechniqueTree → NodeDetail
- Sheets for modals: profile editing, tier selection, goal notes

### Planning LLM JSON

When editing prompts or `Codable` for weekly planning, keep the model’s JSON aligned with the app decoders. See **`SwimNote/Vendored/SwimNoteCore/docs/LLM_TRAINING_PLAN_JSON_SCHEMA.md`** (Phase 1 outline vs Phase 2 detail vs full `WeeklyTrainingPlan`, repair pipeline, `goalProgressPlan` vs `techniqueProgressPlan`).

### Key Patterns

- `@Observable` for app model (iOS 17+ Observation)
- Repository protocols with JSON file implementations (actors for thread safety)
- `.poolCard()` modifier for frosted glass card styling
- `SwipeToDeleteRow` for goal deletion

## Swift 6 Concurrency

This project uses Swift 6 strict concurrency mode. Key patterns to avoid actor isolation errors:

1. **Mark structs as `nonisolated`**: For structs used in actor contexts (repositories), mark the entire struct as `nonisolated` to prevent Swift from synthesizing main actor-isolated protocol conformances:
   ```swift
   public nonisolated struct TrainingPlan: Codable, Hashable, Sendable {
       // All methods are implicitly nonisolated
   }
   ```

2. **Explicit Codable implementation**: Even with `nonisolated struct`, provide explicit `init(from decoder:)` and `encode(to encoder:)` to avoid synthesized conformances that might still trigger warnings.

3. **Explicit Hashable/Equatable**: For structs used in tests, provide explicit implementations:
   ```swift
   public func hash(into hasher: inout Hasher) { ... }
   public static func == (lhs: Self, rhs: Self) -> Bool { ... }
   ```

4. **Enums with Codable**: For enums (like `ToolChoice`), mark the entire enum as `nonisolated`:
   ```swift
   public nonisolated enum ToolChoice: Codable, Sendable {
       case auto, none, required, specific(String)
   }
   ```

5. **@preconcurrency import**: Use `@preconcurrency import Foundation` for modules with Sendable warnings.

6. **Avoid `Any` in Sendable types**: Types containing `Any` cannot be fully Sendable. Use Codable structs instead (e.g., `ConversationMessage` instead of `[String: Any]`).

## Domain Models

- `Goal` - Has `goalKind`: keyPoint, mistake, competitiveMetric
- `TechniqueTree` - Nodes with `sourceFile` pointing to bundled markdown
- `UserProfile` - Skill level auto-calculated from personal bests
- `ParsedTechniqueContent` - Structured content from markdown (key points, mistakes, drills, competitive tiers)

## See Also

- `SwimNoteApp/CLAUDE.md` - Detailed architecture and patterns
- `SwimNoteApp/docs/USER_FLOW.md` - Complete user flow diagram