# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swimmer Training Notes - A personal web app for swimmers to track daily training sessions, set focused goals, and get AI-powered suggestions. Features interactive technique trees (Mermaid flowcharts) for each stroke with LLM-generated coaching tips.

## Commands

```bash
npm run dev      # Start development server (localhost:3001 if 3000 occupied)
npm run build    # Build for production
npm run lint     # Run ESLint
```

## Tech Stack

- Next.js 16 with App Router, TypeScript, Tailwind CSS 4
- Local JSON file storage in `data/` directory
- LLM integration via configurable provider (Anthropic/OpenAI/DashScope)
- Mermaid.js for technique tree visualization

## Architecture

### Data Layer (`src/lib/data/`)
- `notes.ts` - Training note CRUD operations, stored as `data/notes/YYYY-MM-DD.json`
- `goals.ts` - Active goals management in `data/goals/active.json`
- `config.ts` - Stroke/technique definitions from `data/config/`
- `trees.ts` - Technique tree CRUD, stored in `data/config/technique_trees/{stroke}.json`

### LLM Layer (`src/lib/llm/`)
- `config.ts` - Provider configuration from environment (handles model name formats like `openai/model-name`)
- `anthropic.ts` / `openai.ts` - Provider implementations
- `suggestions.ts` - Goal suggestions and feedback generation
- `coaching.ts` - Coaching tips generation for technique nodes

### API Routes (`src/app/api/`)
- `/api/notes` - List all notes or create new
- `/api/notes/[date]` - GET/POST/PUT/DELETE specific day's note
- `/api/suggestions` - POST to get LLM-generated goal suggestions
- `/api/coaching` - POST to get coaching tips for a technique node
- `/api/trees/[stroke]` - GET technique tree, POST to save customized tree
- `/api/trees/expand` - POST to expand a node into sub-nodes using LLM

### Pages (`src/app/`)
- `/` - Dashboard with today's note and stroke cards linking to technique trees
- `/history` - Browse past notes
- `/notes/[date]` - View/edit specific note
- `/trees/[stroke]` - Interactive technique tree (Mermaid flowchart) with node selection

### Key Components (`src/components/`)
- `TechniqueFlowchart.tsx` - Interactive tree page with goal selection, node expansion, and custom node creation
- `NodeDetailPanel.tsx` - Side panel showing node details with coaching tips
- `StrokeCard.tsx` - Cards linking to stroke-specific technique trees

## Environment Variables

Configure LLM in `.env`:
```
LLM_PROVIDER=openai  # or anthropic
OPENAI_API_KEY=...
OPENAI_API_BASE=...  # Optional, for DashScope or other OpenAI-compatible APIs
MODEL_NAME=...       # Optional, can include provider prefix like "openai/qwen3.6-plus"
LLM_TIMEOUT=600      # Request timeout in seconds
LLM_MAX_RETRIES=3    # Max retry attempts
```

## Data Storage

Notes stored as JSON in `data/notes/YYYY-MM-DD.json`:
- strokeFocus: Array of stroke IDs
- techniqueFocus: Array of technique IDs
- goals: Array with type, description, status, metrics, coachingTips, techniqueNodeId
- notes: Free-text observations

Technique trees in `data/config/technique_trees/{stroke}.json`:
- nodes: Array with id, techniqueId, level, name, description, revisit flag, prerequisites, children
- rootNodes: IDs of starting nodes
- customized: Boolean flag for user-modified trees

## Important Notes

- This is Next.js 16 with breaking changes from standard Next.js patterns. Check `node_modules/next/dist/docs/` for current API conventions if encountering unfamiliar errors.
- Goals from technique trees include `strokeId` field to track source stroke, enabling "one goal per stroke" focus limit.
- Coaching tips are cached client-side in NodeDetailPanel to avoid repeated LLM calls.