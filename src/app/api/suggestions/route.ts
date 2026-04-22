import { NextResponse } from 'next/server';
import { generateGoalSuggestions, generateFeedback } from '@/lib/llm/suggestions';
import { getRecentNotes, getNote } from '@/lib/data/notes';
import { getStrokes, getTechniques } from '@/lib/data/config';
import { isLLMConfigured } from '@/lib/llm/config';

export async function POST(request: Request) {
  if (!isLLMConfigured()) {
    return NextResponse.json({
      error: 'LLM not configured. Set LLM_PROVIDER and API key in environment.',
      suggestions: null
    });
  }

  try {
    const body = await request.json();
    const { type, date } = body;

    if (type === 'feedback' && date) {
      const note = getNote(date);
      if (!note) {
        return NextResponse.json({ error: 'Note not found' }, { status: 404 });
      }
      const feedback = await generateFeedback(note);
      return NextResponse.json({ feedback });
    }

    // Default: goal suggestions
    const recentNotes = getRecentNotes(14);
    const strokes = getStrokes();
    const techniques = getTechniques();
    const suggestions = await generateGoalSuggestions(recentNotes, strokes, techniques);

    return NextResponse.json({ suggestions });
  } catch (error) {
    console.error('Error generating suggestions:', error);
    return NextResponse.json({
      error: 'Failed to generate suggestions',
      suggestions: null
    }, { status: 500 });
  }
}