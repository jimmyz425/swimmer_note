# SwimNote User Flow

```mermaid
flowchart TB
    subgraph AppLaunch["App Launch"]
        Start([App Opens]) --> LoadProfiles[Load Profiles from Core Data]
        LoadProfiles --> IsInitialized{Is Initialized?}
        IsInitialized -->|No| LoadingState[Show Loading...]
        LoadingState --> HasProfile
        IsInitialized -->|Yes| HasProfile{Has Active Profile?}
        HasProfile -->|Yes| MainTabs
        HasProfile -->|No| NeedsSetup{First Time?}
        NeedsSetup -->|Yes| WelcomeView[Welcome Screen]
        NeedsSetup -->|No| UserSelectionView[User Selection]
        WelcomeView -->|Get Started| UserSetupView[Create Profile]
        UserSetupView --> MainTabs
        UserSelectionView -->|Select Profile| MainTabs
        UserSelectionView -->|Add New| UserSetupView
    end

    subgraph MainTabs["Main Tabs (TabView)"]
        TabDashboard[Dashboard - Today]
        TabCalendar[Calendar]
        TabTools[Tools]
        TabPlan[Planning]
        TabSettings[Settings]
    end

    subgraph Dashboard["Dashboard Flow"]
        TabDashboard --> LoadTodayNote[Load Today's Note]
        LoadTodayNote --> Header[Header: Profile Menu]
        Header -->|Switch User| UserSelectionView
        Header -->|Edit Profile| PersonalBestsEditor[Edit Profile]
        
        LoadTodayNote --> SessionNotesCard[Session Notes Card]
        SessionNotesCard --> StrokeTabs[4 Stroke Tabs + General]
        StrokeTabs --> FreeTab[Freestyle]
        StrokeTabs --> BackTab[Backstroke]
        StrokeTabs --> BreastTab[Breaststroke]
        StrokeTabs --> FlyTab[Butterfly]
        StrokeTabs --> GeneralTab[General]
        
        StrokeTabs -->|Tap +| NavigateToTree[Navigate to Technique Tree]
        NavigateToTree --> TechniqueTree
        
        SessionNotesCard --> FocusAreas[Focus Areas List]
        FocusAreas -->|Empty| EmptyFocusPrompt["No focus areas - Tap + to browse technique tree"]
        FocusAreas -->|Swipe Left| DeleteGoal[Delete Goal]
        FocusAreas -->|Tap Status| StatusMenu[Change Status Menu]
        FocusAreas -->|Tap Expand| GoalDetails[Show Goal Details]
        FocusAreas -->|Tap Notes Icon| GoalNotesSheet[Add Goal Notes]
        
        SessionNotesCard --> SessionNotesField[Session Notes Field]
        SessionNotesField -->|Tap| SessionNotesSheet[Edit Session Notes Sheet]
        
        LoadTodayNote --> TrainingSection[Today's Training Section]
        TrainingSection --> TodaySession[Today's Session Card]
        TodaySession -->|Tap| SessionDetailSheet[Session Detail Sheet]
        TodaySession -->|Swipe Complete| ToggleCompletion[Toggle Session Completion]
        
        TrainingSection --> DryLandSection[Dry Land Training]
        DryLandSection --> DryLandRows[Dry Land Exercise Rows]
        DryLandRows -->|Swipe Complete| ToggleDryLand[Toggle Dry Land Completion]
        
        TrainingSection -->|No Plan| NoPlanCard["No training plan - Generate in Plan tab"]
        NoPlanCard -->|Tap| SwitchToPlan[Switch to Plan Tab]
    end

    subgraph CalendarFlow["Calendar Flow"]
        TabCalendar --> MonthNavigation[Month Navigation]
        MonthNavigation -->|Previous/Next| UpdateMonth[Update Month View]
        
        TabCalendar --> CalendarGrid[Full Month Calendar Grid]
        CalendarGrid --> DayCell[Day Cell]
        DayCell -->|Teal Indicator| HasPoolSession[Pool Session]
        DayCell -->|Orange Indicator| HasDryLand[Dry Land Exercise]
        DayCell -->|Gray Indicator| HasGoals[Has Goals]
        
        CalendarGrid -->|Tap Day| SelectedDaySection[Selected Day Section]
        SelectedDaySection --> DaySessionCard[Session Card]
        DaySessionCard -->|Tap| SessionDetailView[Session Detail Sheet]
        
        SelectedDaySection --> DayDryLandSection[Dry Land Exercises]
        SelectedDaySection --> DayGoalsSection[Goals for Day]
        
        SelectedDaySection -->|No Plan| NoPlanPrompt["No plan - Generate in Plan tab"]
    end

    subgraph ToolsFlow["Tools Flow"]
        TabTools --> VideoSection[Video Review Section]
        VideoSection --> ImportButton[Import Video Button]
        ImportButton --> FilePicker[File Picker]
        FilePicker -->|Select Video| VideoPlayer[Video Player]
        VideoSection --> SavedAnalysis[Saved Video Analysis Records]
        
        TabTools --> PBTrackerSection[Personal Bests Section]
        PBTrackerSection -->|NavigationLink| PBTrackerView[PB Tracker View]
        PBTrackerView --> AddPBResult[Add Meet Result]
        PBTrackerView --> PBHistoryList[PB History List]
        PBTrackerSection -->|NavigationLink| PBProgressionChart[PB Progression Chart]
        
        TabTools --> CSSSection[CSS Tools Section]
        CSSSection -->|NavigationLink| CSSProgressionChart[CSS Progression Chart]
        CSSSection -->|Button| IntervalCalculator[Interval Calculator Sheet]
        IntervalCalculator -->|Uses CSS| CalculateIntervals[Calculate Training Intervals]
        CSSSection -->|Button| RecordCSSTest[Record New CSS Test Sheet]
        RecordCSSTest --> TwoTrialTest[2-Trial CSS Test]
        RecordCSSTest --> ThreeTrialTest[3-Trial CSS Test]
        
        TabTools --> ProfileMenu2[Profile Menu]
        ProfileMenu2 -->|Switch User| UserSelectionView
        ProfileMenu2 -->|Edit Profile| PersonalBestsEditor
    end

    subgraph TechniqueFlow["Technique Tree Flow"]
        TechniqueTree[Technique Tree View] --> NodeList[Sorted Node List]
        NodeList -->|Tap Node| NodeDetail[Node Detail View]
        
        NodeDetail --> TabPicker[Tab Picker - 5 Tabs]
        TabPicker --> OverviewTab[Overview]
        TabPicker --> KeyPointsTab[Key Points]
        TabPicker --> MistakesTab[Mistakes]
        TabPicker --> DrillsTab[Drills]
        TabPicker --> CompetitiveTab[Competitive]
        
        KeyPointsTab -->|Add +| AddKeyPointGoal[Add Key Point Goal]
        MistakesTab -->|Add +| AddMistakeGoal[Add Mistake Goal]
        CompetitiveTab -->|Add as Goal| TierSelection[Tier Selection Sheet]
        TierSelection --> AddCompetitiveGoal[Add Competitive Metric Goal]
        
        AddKeyPointGoal --> SaveToToday[Save to Today's Note]
        AddMistakeGoal --> SaveToToday
        AddCompetitiveGoal --> SaveToToday
        
        OverviewTab --> RelatedTechniques[Related Techniques]
        RelatedTechniques -->|Tap Link| NodeDetail
    end

    subgraph PlanningFlow["Planning Flow"]
        TabPlan --> HeaderSection[Header: AI Training Planner]
        HeaderSection --> HistoryButton[Plan History Button]
        HistoryButton --> PlanHistorySheet[Plan History Sheet]
        PlanHistorySheet -->|Select Plan| LoadSavedPlan[Load Saved Plan]
        
        TabPlan --> SettingsCard[Collapsible Settings Card]
        SettingsCard --> PoolTypePicker[Pool Type: 25m/25yd/50m/50yd]
        SettingsCard --> SessionsPicker[Sessions per Week: 2-6]
        SettingsCard --> PlanTypeMenu[Plan Type Menu]
        PlanTypeMenu --> SprintPlan[Sprint Focus]
        PlanTypeMenu --> EndurancePlan[Endurance Focus]
        PlanTypeMenu --> TechniquePlan[Technique Focus]
        PlanTypeMenu --> MixedPlan[Mixed Balanced]
        SettingsCard --> DryLandToggle[Include Dry Land Toggle]
        SettingsCard --> WeekDatePicker[Week Starting Date]
        SettingsCard --> GenerateButton[Generate Training Plan]
        SettingsCard --> LoadSampleButton[Load Sample Plan - Debug]
        
        GenerateButton --> LLMGeneration[LLM Plan Generation]
        LLMGeneration --> ToolCalls[Tool Calls: read_technique_file, get_user_profile, get_stroke_balance, get_goal_progress]
        ToolCalls --> ParseJSON[Parse JSON Response]
        ParseJSON --> GeneratedPlan[Generated Weekly Plan]
        
        GeneratedPlan --> SummaryStats[Summary Stats Bar]
        GeneratedPlan --> OverviewCard[Overview Hero Card]
        OverviewCard --> WeekFocus[Week Focus Banner]
        OverviewCard --> ObjectivesRow[Technical + Physical Objectives]
        
        GeneratedPlan --> TechniqueProgress[Technique Progress Plan - Collapsible]
        TechniqueProgress --> ContinueGoals[Continuing Goals]
        TechniqueProgress --> AchievedGoals[Achieved → Next Level]
        TechniqueProgress --> RevisitGoals[Revisit Goals]
        TechniqueProgress --> NewGoals[New Goals]
        
        GeneratedPlan --> SessionsGrid[Training Sessions Grid]
        SessionsGrid --> SessionCards[Session Cards]
        SessionCards -->|Expand| SessionSegments[Warm-up/Drill/Main/Cool-down]
        SessionCards -->|Date Picker| AssignSessionDate[Assign Session Date]
        
        GeneratedPlan --> DryLandCard[Dry Land Program Card]
        DryLandCard --> DryLandTiles[Dry Land Exercise Tiles]
        DryLandTiles -->|Auto Assign| AssignToRestDays[Assign to Rest Days]
        DryLandTiles -->|Date Picker| ManualDateSelection[Select Specific Dates]
        
        GeneratedPlan --> SaveButton[Save Plan Button]
        SaveButton --> SaveToCoreData[Save to Core Data]
        SaveToCoreData --> CalendarRefresh[Calendar Tab Refreshes]
    end

    subgraph SettingsFlow["Settings Flow"]
        TabSettings --> LLMSection[LLM Provider Section]
        LLMSection --> ProviderPicker[Provider Picker: OpenAI/Anthropic/OpenAI-Compatible]
        ProviderPicker --> ModelField[Model Name Input]
        ModelField --> APIKeyField[API Key Input]
        APIKeyField --> SaveButtonSettings[Save Configuration]
        SaveButtonSettings --> KeychainStore[Store in Keychain]
        
        TabSettings --> ProfileSection[Profile Section]
        ProfileSection --> ActiveProfileDisplay[Active Profile Info]
        ProfileSection --> SwitchProfileButton[Switch Profile]
        SwitchProfileButton --> UserSelectionView
        ProfileSection --> EditProfileButton[Edit Profile]
        EditProfileButton --> PersonalBestsEditor
    end

    subgraph ProfileManagement["Profile Management"]
        PersonalBestsEditor --> EditPBs[Edit Personal Bests by Event]
        PersonalBestsEditor --> EditCSSHistory[View/Edit CSS History]
        PersonalBestsEditor --> EditTrainingTier[Training Tier Selection]
        
        UserSetupView --> NameField[Name Input]
        UserSetupView --> BirthdayPicker[Birthday Picker]
        UserSetupView --> SexPicker[Sex Selection]
        UserSetupView --> TierPicker[Training Tier: Recreational/Club/Competitive/Elite]
        UserSetupView --> SubTierPicker[Sub-Tier Options]
        UserSetupView --> PBsOptional[Personal Bests - Optional]
        UserSetupView --> ProfileIconPicker[Profile Icon Picker: Letter/Emoji/Photo]
        
        UserSelectionView -->|Swipe Edit| PersonalBestsEditor
        UserSelectionView -->|Swipe Delete| DeleteConfirm[Delete Confirmation]
    end
end
```

## Key User Flows

### 1. App Launch → Setup/Selection
- First-time users: Welcome Screen → Create Profile → Dashboard
- Returning users (no active profile): User Selection → Dashboard
- Returning users (active profile): Direct to Dashboard
- Loading state shown while Core Data initializes

### 2. Dashboard (Primary Tab)
- View today's training session and goals
- **Session Notes Card** with 4 stroke tabs + General tab:
  - Each stroke tab shows goals for that stroke
  - General tab shows non-stroke-specific goals
  - Tap + to navigate to technique tree for adding goals
- **Focus Areas Management**:
  - Change status (Planned → In Progress → Achieved/Unable)
  - Add notes via notes icon
  - Delete via leftward swipe
  - Expand/collapse for details
- **Today's Training Section**:
  - Session card with swipe-to-complete
  - Dry land exercises with swipe-to-complete
- Empty state prompts navigation to Plan tab

### 3. Calendar Tab
- **Month-based navigation** (not week-based)
- Full month calendar grid with indicators:
  - Teal indicators for pool sessions
  - Orange indicators for dry land exercises
  - Gray indicators for goals
- Selected day section shows:
  - Session card (tap for full detail sheet)
  - Dry land exercises with sets/reps
  - Goals for that day
- No plan card links to Plan tab

### 4. Tools Tab (NEW - replaces "Video Analysis")
- **Video Review**: Import and play swim footage
- **Saved Video Analysis**: View past analysis records
- **Personal Bests Section**:
  - PB Tracker: Enter meet results, view history
  - PB Progression Chart: Visualize improvement over time
- **CSS Tools Section**:
  - CSS Progression Chart: Track Critical Swim Speed
  - Interval Calculator: Calculate training paces from CSS
  - Record New CSS Test: 2-trial or 3-trial test input

### 5. Planning Tab
- **Collapsible Settings Card**:
  - Pool type selection (25m/25yd/50m/50yd)
  - Sessions per week (2-6)
  - Plan type (Sprint/Endurance/Technique/Mixed)
  - Dry land toggle
  - Week starting date picker
- **AI Generation**: Uses LLM with tool calls to:
  - Read technique files
  - Get user profile and personal bests
  - Analyze stroke balance from recent notes
  - Analyze goal progress
- **Generated Plan Display**:
  - Summary stats bar
  - Overview hero card with week focus
  - Technique progress plan (collapsible)
  - Session cards grid with date pickers
  - Dry land program (auto-assigned to rest days)
- **Save to Core Data**: Sessions appear in Calendar on scheduled dates
- **Plan History**: Browse and load previously saved plans

### 6. Technique Tree → Node Detail
- Navigate from Dashboard stroke tab (+ button)
- Browse technique nodes organized by stroke
- View detailed content across 5 tabs:
  - **Overview**: Description, difficulty, related techniques
  - **Key Points**: Checklist items → Add as goal
  - **Mistakes**: Common errors → Add as "Avoid" goal
  - **Drills**: Practice drills with descriptions
  - **Competitive**: Tiered targets (Beginner → Elite) → Add as goal with tier selection
- Navigate between related techniques

### 7. Settings
- Configure LLM provider (OpenAI, Anthropic, OpenAI-Compatible)
- Set model name and API key (stored in Keychain)
- View/edit active profile
- Switch profile via User Selection

### 8. Profile Management
- **User Selection**: Switch profiles, edit, or delete
- **Create Profile**: Name, birthday, sex, training tier, personal bests (optional), profile icon
- **Edit Profile**: Update personal bests, view CSS history

## Screen Hierarchy

| Screen | Parent | Navigation Type |
|--------|--------|-----------------|
| WelcomeView | RootView | Conditional render |
| UserSetupView | RootView/UserSelectionView | Sheet |
| UserSelectionView | RootView/Dashboard/Calendar/Tools | Sheet |
| DashboardView | TabView | Tab |
| TechniqueTreeView | DashboardView | NavigationLink (from stroke tab +) |
| NodeDetailView | TechniqueTreeView | NavigationLink |
| CalendarView | TabView | Tab |
| SessionDetailView | CalendarView | Sheet |
| DayDetailSection | CalendarView | Inline (selected day) |
| ToolsView | TabView | Tab |
| PBTrackerView | ToolsView | NavigationLink |
| PBProgressionChartView | ToolsView | NavigationLink |
| CSSProgressionChartView | ToolsView | NavigationLink |
| IntervalCalculatorView | ToolsView | Sheet |
| CSSTestInputView | ToolsView | Sheet |
| PlanningView | TabView | Tab |
| PlanHistoryView | PlanningView | Sheet |
| PlanDetailView | PlanHistoryView | Sheet |
| SessionCard | PlanningView/DashboardView/CalendarView | Inline/Sheet |
| DryLandCard | PlanningView | Inline |
| SettingsView | TabView | Tab |
| PersonalBestsEditor | Various | Sheet |
| TierSelectionSheet | NodeDetailView | Sheet |
| GoalNotesSheet | DashboardView | Sheet |
| SessionNotesSheet | DashboardView | Sheet |

## Component Architecture

Extracted components for maintainability:

| Component | File | Used In |
|-----------|------|---------|
| SessionCard | `Features/Planning/Components/SessionCard.swift` | PlanningView, DashboardView, CalendarView |
| DryLandExerciseRow | `Components/DryLandExerciseRow.swift` | DashboardView, CalendarView |
| DryLandSection | `Features/Planning/Components/DryLandSection.swift` | PlanningView |
| PlanHistoryView | `Features/Planning/Components/PlanHistoryViews.swift` | PlanningView |
| DayCell | `Features/Calendar/Components/DayCell.swift` | CalendarView |
| GoalStatusBadge | `Components/GoalStatusBadge.swift` | DashboardView, CalendarView |
| CollapsibleGoalRow | `Features/Dashboard/Components/CollapsibleGoalRow.swift` | DashboardView |
| SwipeToDeleteRow | `Components/SwipeActionRows.swift` | DashboardView |
| SwipeToToggleCompleteRow | `Components/SwipeActionRows.swift` | DashboardView |
| ProfileIconView | `Features/Profile/ProfileIconView.swift` | DashboardView, CalendarView, ToolsView |
| CollapsibleSettingsCard | `Features/Planning/PlanningView.swift` (inline) | PlanningView |

## Data Flow

### Core Data Persistence
- Profiles: `CoreDataUserProfileRepository`
- Notes: `CoreDataTrainingNoteRepository`
- Weekly Plans: `CoreDataWeeklyPlanRepository`
- Training Plans (legacy): `JSONTrainingPlanRepository`

### Session Date Caching
- `sessionsByDate`: O(1) lookup for sessions by date string
- `dryLandByDate`: O(1) lookup for dry land exercises by date

### Content Loading
- Technique trees: Loaded from bundled JSON files
- Technique content: Parsed from bundled markdown files
- Cached in memory for performance