# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swimmer Training Notes - A personal web app for swimmers to track daily training sessions, set focused goals, and get AI-powered suggestions.

## Commands

```bash
npm run dev      # Start development server (localhost:3001 if 3000 occupied)
npm run build    # Build for production
npm run lint     # Run ESLint
```

## Tech Stack

- Next.js 16 with App Router, TypeScript, Tailwind CSS
- Local JSON file storage in `data/` directory
- LLM integration via configurable provider (Anthropic/OpenAI/DashScope)

## Architecture

### Data Layer (`src/lib/data/`)
- `notes.ts` - Training note CRUD operations
- `goals.ts` - Active goals management
- `config.ts` - Stroke/technique definitions

### LLM Layer (`src/lib/llm/`)
- `config.ts` - Provider configuration from environment
- `anthropic.ts` / `openai.ts` - Provider implementations
- `suggestions.ts` - Goal suggestions and feedback generation

### API Routes (`src/app/api/`)
- `/api/notes` - List all notes or create new
- `/api/notes/[date]` - GET/POST/PUT/DELETE specific day's note
- `/api/suggestions` - POST to get LLM-generated goal suggestions

### Pages (`src/app/`)
- `/` - Dashboard with today's note
- `/history` - Browse past notes
- `/notes/[date]` - View/edit specific note

## Environment Variables

Configure LLM in `.env`:
```
LLM_PROVIDER=openai  # or anthropic
OPENAI_API_KEY=...
OPENAI_API_BASE=...  # Optional, for DashScope or other OpenAI-compatible APIs
MODEL_NAME=...       # Optional, overrides default model
```

## Data Storage

Notes stored as JSON in `data/notes/YYYY-MM-DD.json`:
- strokeFocus: Array of stroke IDs
- techniqueFocus: Array of technique IDs
- goals: Array with type, description, status
- notes: Free-text observations