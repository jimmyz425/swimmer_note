'use client';

import { TrainingNote } from '@/lib/types';
import Link from 'next/link';

interface NoteHistoryListProps {
  notes: TrainingNote[];
}

export function NoteHistoryList({ notes }: NoteHistoryListProps) {
  if (notes.length === 0) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-500">No training notes yet.</p>
        <Link href="/" className="text-blue-600 hover:underline mt-2 inline-block">
          Start your first note
        </Link>
      </div>
    );
  }

  const formatDate = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const goalStats = (note: TrainingNote): string => {
    const completed = note.goals.filter(g => g.status === 'completed').length;
    const total = note.goals.length;
    if (total === 0) return 'No goals';
    return `${completed}/${total} goals completed`;
  };

  return (
    <div className="space-y-3">
      {notes.map((note) => (
        <Link
          key={note.date}
          href={`/notes/${note.date}`}
          className="block p-4 bg-white rounded-lg border border-gray-200 hover:border-blue-300 hover:shadow-sm transition"
        >
          <div className="flex justify-between items-start">
            <div>
              <h3 className="font-medium text-gray-900">{formatDate(note.date)}</h3>
              {note.strokeFocus.length > 0 && (
                <p className="text-sm text-gray-500 mt-1">
                  Strokes: {note.strokeFocus.join(', ')}
                </p>
              )}
              {note.techniqueFocus.length > 0 && (
                <p className="text-sm text-gray-500">
                  Techniques: {note.techniqueFocus.join(', ')}
                </p>
              )}
            </div>
            <span className="text-xs text-gray-400">{goalStats(note)}</span>
          </div>
          {note.notes && (
            <p className="text-sm text-gray-600 mt-2 line-clamp-2">{note.notes}</p>
          )}
        </Link>
      ))}
    </div>
  );
}