# LLM Tool Calling Architecture

This document describes the tool calling system used for LLM integration in SwimNote.

## Overview

The LLM tool calling system allows the AI model to request information from the app during conversation. This enables the model to:
- Access technique content from bundled markdown files
- Read user profiles and training history
- Navigate the technique wiki structure

## Components

### 1. ToolDefinitions.swift

Defines the OpenAI Function Calling schema for all available tools.

**Types:**
- `Tool` - Container with `type` and `function` fields
- `ToolFunction` - Name, description, and JSON schema parameters
- `JSONSchema` - OpenAPI-style schema object
- `JSONSchemaProperty` - Individual property with type, description, enum values
- `ToolCall` - A tool call request from the LLM
- `ToolCallFunction` - The function name and arguments (JSON string)
- `ToolChoice` - Controls tool calling behavior (auto, none, required, specific)

**Tool Categories:**

#### ResourcesNavigationTools (4 tools)

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `read_technique_file` | Read a technique markdown file | `filename` |
| `list_technique_files` | List available technique files | None (optional: `stroke`) |
| `search_content` | Search keywords across files | `query` (optional: `stroke`) |
| `get_related_techniques` | Get related files and navigation | `filename` |

#### UserDataTools (4 tools)

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `get_user_profile` | Get swimmer's profile data | None |
| `get_training_history` | Get past training notes | None (optional: `days`, `include_goals`) |
| `get_active_goals` | Get active/pending goals | None |
| `get_training_calendar` | Get session calendar view | None (optional: `weeks`) |

### 2. ToolExecutor.swift

Executes tool calls for technique content navigation.

**Dependencies:**
- `BundleContentLoader` - Loads markdown files from bundle
- `TechniqueMarkdownParser` - Parses markdown into structured content

**Methods:**
- `execute(_ toolCall)` - Execute any tool call, returns JSON string result
- `listTechniqueFiles(stroke:)` - List files, optionally filtered by stroke
- `readTechniqueFile(filename:)` - Read and parse a specific file
- `searchContent(query:, stroke:)` - Search across files
- `getRelatedTechniques(filename:)` - Get navigation links

**Returns:** JSON-encoded strings with structured data

### 3. CombinedToolExecutor.swift

Extended executor that includes user data tools.

**Additional Dependencies:**
- `UserProfile` - Current user's profile
- `[TrainingNote]` - Training history

**Additional Methods:**
- `getUserProfile()` - Return user profile as JSON
- `getTrainingHistory(days:, includeGoals:)` - Return training history
- `getActiveGoals()` - Return active goals from notes
- `getTrainingCalendar(weeks:)` - Return calendar view

### 4. LLMService.swift

LLM client implementations for different providers.

**Providers:**
- `openAI` - OpenAI GPT models
- `anthropic` - Claude models
- `openRouter` - OpenRouter proxy
- `openAICompatible` - Any OpenAI-compatible endpoint (e.g., DashScope)

**Clients:**
- `OpenAIClient` - OpenAI/OpenRouter/compatible endpoints
- `AnthropicClient` - Anthropic Claude API

**Key Types:**
- `LLMConfiguration` - Provider, API key reference, base URL, model name, timeout
- `LLMRequest` - System role, prompt, temperature, tools, tool choice, messages
- `LLMResponse` - Content string and/or tool calls array
- `LLMServiceError` - Error types (invalidResponse, httpError, apiError, maxIterationsReached)

**Credential Storage:**
- `KeychainCredentialStore` - Secure storage using iOS Keychain
- `InMemoryCredentialStore` - Testing mock

### 5. ToolCallingConversation.swift

Manages multi-turn tool calling conversations.

**Flow:**
1. Start with system + user messages
2. Call LLM with tools available
3. If response has content (no tool calls) → return content
4. If response has tool calls → execute each, add results to conversation
5. Repeat until max iterations or content response

**Message Types (ConversationMessage):**
- `.system(String)` - System instructions
- `.user(String)` - User prompt
- `.assistant(String)` - Text response
- `.assistantToolCall(ToolCall)` - Tool call request
- `.toolResult(toolCallId, result)` - Tool execution result

## Tool Call Flow Diagram

```
User Prompt
    │
    ▼
┌─────────────────────┐
│ Build Initial       │
│ Messages            │
│ (system + user)     │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ Call LLM API        │
│ with Tools          │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ Check Response      │
└─────────────────────┘
    │
    ├────────────────────┐
    │                    │
    │ Has Content?       │ Has Tool Calls?
    │                    │
    ▼                    ▼
┌──────────┐      ┌─────────────────┐
│ Return   │      │ Execute Tools   │
│ Content  │      │ Add Results to  │
│          │      │ Conversation    │
└──────────┘      └─────────────────┘
                       │
                       ▼
                   ┌─────────────────────┐
                   │ Call LLM Again      │
                   │ with Updated        │
                   │ Messages            │
                   └─────────────────────┘
                       │
                       ▼
                   (Repeat until content
                    or max iterations)
```

## Testing Strategy

### Unit Tests

1. **ToolDefinitionsTests** - Verify tool schemas are valid JSON
2. **ToolExecutorTests** - Test each tool execution with mock content loader
3. **CombinedToolExecutorTests** - Test user data tools with mock data
4. **LLMServiceTests** - Test request building and response parsing
5. **ToolCallingConversationTests** - Test conversation flow

### Integration Tests

1. End-to-end tool calling with mock LLM server
2. Provider compatibility tests (OpenAI format vs Anthropic format)

## Error Handling

**ToolError Types:**
- `unknownTool(String)` - Tool name not recognized
- `missingParameter(String)` - Required parameter not provided
- `invalidParameter(String, String)` - Parameter validation failed
- `executionError(String)` - Runtime execution failure

**LLMServiceError Types:**
- `invalidResponse` - Response parsing failed
- `httpError(Int)` - HTTP status code error
- `apiError(String)` - API-specific error message
- `maxIterationsReached` - Tool calling loop exceeded limit

## JSON Response Formats

### read_technique_file

```json
{
  "filename": "freestyle-02-flutter-kick.md",
  "title": "Flutter Kick",
  "difficulty": "Easy",
  "overview": "...",
  "key_points": ["...", "..."],
  "drills": [
    {"name": "...", "type": "specific", "description": "..."},
    {"name": "...", "type": "competitive", "targets": {...}}
  ],
  "related_files": ["..."],
  "prev_file": "...",
  "next_file": "..."
}
```

### get_user_profile

```json
{
  "name": "Swimmer Name",
  "age": 25,
  "level": "intermediate",
  "weekly_target": 3,
  "strokes": ["freestyle", "backstroke"],
  "pb_50m_free": "28.5",
  "pb_50m_back": "32.0"
}
```

### get_training_history

```json
{
  "days_returned": 7,
  "sessions": [
    "2026-04-28 | Strokes: freestyle,backstroke | Goals: 2 active, 1 achieved | Note: ...",
    "..."
  ],
  "summary": {
    "total_sessions": 7,
    "strokes_practiced": ["freestyle", "backstroke"]
  }
}
```

## Best Practices

1. **Limit tool call iterations** - Default max is 10 iterations
2. **Concise responses** - Tool results are trimmed to reduce context bloat
3. **Error as tool result** - Execution errors are returned to LLM for handling
4. **Provider-specific formats** - OpenAI vs Anthropic tool schemas differ
5. **Secure API keys** - Always use Keychain for credential storage