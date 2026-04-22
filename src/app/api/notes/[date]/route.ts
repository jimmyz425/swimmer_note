import { NextRequest, NextResponse } from 'next/server';
import { getNote, saveNote, deleteNote, createEmptyNote } from '@/lib/data/notes';
import { TrainingNote } from '@/lib/types';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ date: string }> }
) {
  const { date } = await params;
  const note = getNote(date);

  if (!note) {
    return NextResponse.json({ error: 'Note not found' }, { status: 404 });
  }

  return NextResponse.json({ note });
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ date: string }> }
) {
  const { date } = await params;

  try {
    const body = await request.json();
    const noteData = body as Partial<TrainingNote>;

    const note = createEmptyNote(date);
    const savedNote = saveNote({
      ...note,
      ...noteData,
      date,
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

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ date: string }> }
) {
  const { date } = await params;
  const existingNote = getNote(date);

  if (!existingNote) {
    return NextResponse.json({ error: 'Note not found' }, { status: 404 });
  }

  try {
    const body = await request.json();
    const noteData = body as Partial<TrainingNote>;

    const savedNote = saveNote({
      ...existingNote,
      ...noteData,
      date, // Ensure date stays the same
    });

    return NextResponse.json({ note: savedNote });
  } catch (error) {
    console.error('Error updating note:', error);
    return NextResponse.json({ error: 'Failed to update note' }, { status: 500 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ date: string }> }
) {
  const { date } = await params;
  const deleted = deleteNote(date);

  if (!deleted) {
    return NextResponse.json({ error: 'Note not found or could not be deleted' }, { status: 404 });
  }

  return NextResponse.json({ success: true });
}