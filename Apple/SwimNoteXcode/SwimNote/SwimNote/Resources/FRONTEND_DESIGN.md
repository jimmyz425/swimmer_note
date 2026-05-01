# SwimNote Frontend Design System

## Color Palette (PoolTheme)

| 角色 | 名称 | HEX | RGB | 说明 |
|------|------|------|-----|------|
| **surface** | 云上舞白 | #F0F4F8 | 240, 244, 248 | Pantone 2026年度色，轻盈洁净，模拟水面反光感 |
| **light** | 冰川蓝 | #A3D9E8 | 163, 217, 232 | 模拟清澈泳池的底层水色，用于渐变背景、卡片底色 |
| **mid** | 深青绿 | #006D6F | 0, 109, 111 | 主强调色，象征水体深度与呼吸节奏，用于按钮、进度条、图标 |
| **deep** | 石墨灰 | #2D3748 | 45, 55, 72 | 高可读性深灰，替代纯黑，保护夜间浏览舒适度 |
| **smoke** | 烟灰色 | #718096 | 113, 128, 150 | 次要文字色，用于提示语、标签、辅助信息 |
| **gold** | 金色 | #FFB42D | 255, 180, 45 | 高亮色，用于 revisit 指示器、成就徽章 |

## Page Structure

Every page should follow this pattern:

```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Content sections
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
    .navigationTitle("Page Title")
}
```

## Typography

| Element | Font |
|---------|------|
| **Page Header** | `.system(size: 34, weight: .black, design: .rounded)` with PoolTheme.deep |
| **Section Title** | `.title3.bold()` or `.headline` |
| **Body Text** | `.body` with `.primary` |
| **Secondary Text** | `.subheadline` or `.caption` with PoolTheme.smoke |
| **Date/Subtitle** | `.headline` with PoolTheme.mid |

## Card Component (.poolCard())

Use for grouped content sections:
```swift
VStack { ... }
    .poolCard()
```

- Background: `.regularMaterial`
- Corner radius: 18 (continuous)
- Border: PoolTheme.light.opacity(0.45), 1pt
- Padding: default 16pt

## Buttons

| Type | Style |
|------|-------|
| **Primary Action** | `.borderedProminent` (uses PoolTheme.mid as tint) |
| **Secondary Action** | `.bordered` |
| **Navigation Cards** | `.plain` with VStack inside |

## Tab Bar

- Tint color: `PoolTheme.mid`
- Each tab has Label with title + icon

## Contrast Guidelines

- **Primary text**: Use `.primary` or PoolTheme.deep
- **Secondary text**: Use PoolTheme.smoke (NOT `.secondary`)
- Headers use solid white/light backgrounds, not PoolTheme.surface
- Card content uses PoolTheme.deep for headlines, PoolTheme.smoke for subtitles

## Empty States

Use `ContentUnavailableView` with:
- Clear title
- Descriptive subtitle in description parameter
- Relevant systemImage icon

## Loading States

```swift
.overlay {
    if isLoading {
        ProgressView("Loading...")
    }
}
```

## Message Feedback

Show inline with PoolTheme.deep for visibility:
```swift
Text(message)
    .foregroundStyle(PoolTheme.deep)
```

## Components Status

### ✅ Dashboard
- Follows all patterns

### ✅ HistoryView
- Pool gradient background, card-based notes grid

### ✅ VideoToolsView
- Pool gradient background, poolCard sections

### ✅ SettingsView
- Pool gradient background, poolCard sections

### ✅ TechniqueTreeViews
- NavigationSplitView for sidebar
- poolCard for content sections
- PoolTheme.deep for headlines, PoolTheme.smoke muted tabs

### ✅ Dashboard Goals
- Dropdown status picker with PoolTheme.mid icons
- Per-goal notes TextField
- PoolTheme.smoke for stroke labels