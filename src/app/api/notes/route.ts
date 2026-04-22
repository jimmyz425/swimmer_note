import { NextRequest, NextResponse } from 'next/server';
import { getAllNotes, getRecentNotes, createEmptyNote, saveNote } from '@/lib/data/notes';
import { TrainingNote } from '@/lib/types';

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const days = searchParams.get('days');

  if (days) {
    const notes = getRecentNotes(parseInt(days, 10));
    return NextResponse.json({ notes });
  }

  const notes = getAllNotes();
  return NextResponse.json({ notes });
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const noteData = body as Partial<TrainingNote>;

    if (!noteData.date) {
      noteData.date = new Date().toISOString().split('T')[0];
    }

    const note = createEmptyNote(noteData.date);
    const savedNote = saveNote({
      ...note,
      ...noteData,
      goals: noteData.goals || [],
      strokeFocus: noteData.strokeFocus || [],
      techniqueFocus: noteData.techniqueFocus || [],
      notes: noteData.notes || '',
    });

    return NextResponse.json({ note: savedNote });
  } catch (error) {
    console.error('Error creating note:', error);
    return NextResponse.json({ error: 'Failed to create note' }, { status: 500 });
  }
}