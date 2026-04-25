'use client';

import { TrainingNote } from '@/lib/types';
import Link from 'next/link';
import { Waves, CheckCircle2, Target } from 'lucide-react';

interface NoteHistoryListProps {
  notes: TrainingNote[];
}

export function NoteHistoryList({ notes }: NoteHistoryListProps) {
  if (notes.length === 0) {
    return (
      <div className="text-center py-16">
        <div className="lane-badge w-16 h-16 flex items-center justify-center mx-auto mb-4">
          <Target className="w-8 h-8 text-white" />
        </div>
        <p className="font-heading font-bold text-pool-dark text-xl uppercase mb-2">
          NO TRAINING YET
        </p>
        <Link href="/" className="btn-lane inline-block mt-4">
          Start Training
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
    });
  };

  const goalStats = (note: TrainingNote): { achieved: number; total: number } => {
    const achieved = note.goals.filter(g => g.status === 'achieved').length;
    const total = note.goals.length;
    return { achieved, total };
  };

  return (
    <div className="relative">
      {/* Timeline line */}
      <div className="absolute left-4 top-0 bottom-0 w-1 bg-gradient-to-b from-pool-mid to-pool-light rounded-full" />

      {/* Timeline items */}
      <div className="space-y-4">
        {notes.map((note, index) => {
          const stats = goalStats(note);
          const completionRate = stats.total > 0 ? (stats.achieved / stats.total) * 100 : 0;

          return (
            <Link
              key={note.date}
              href={`/notes/${note.date}`}
              className="relative flex items-start gap-4 pl-12 group"
            >
              {/* Timeline marker */}
              <div className={`absolute left-4 w-4 h-4 rounded-full -translate-x-1/2 transition-all duration-200
                ${stats.achieved === stats.total && stats.total > 0
                  ? 'bg-gold shadow-md shadow-gold/30'
                  : stats.achieved > 0
                    ? 'bg-lane-yellow'
                    : 'bg-pool-mid'
                }
                group-hover:scale-125 group-active:scale-110
              `} />

              {/* Content card */}
              <div className="lane-card flex-1 p-4 group-hover:shadow-md transition-shadow">
                {/* Header row */}
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <h3 className="font-heading font-bold text-pool-dark uppercase tracking-wide">
                      {formatDate(note.date)}
                    </h3>
                    {note.strokeFocus.length > 0 && (
                      <span className="text-xs font-heading text-pool-mid bg-pool-surface px-2 py-1 rounded flex items-center gap-1">
                        <Waves className="w-3 h-3" />
                        {note.strokeFocus.join(', ').toUpperCase()}
                      </span>
                    )}
                  </div>

                  {/* Achievement indicator */}
                  <div className="flex items-center gap-2">
                    {stats.achieved === stats.total && stats.total > 0 && (
                      <CheckCircle2 className="w-5 h-5 text-gold" />
                    )}
                    <span className="text-xs font-heading font-bold px-2 py-1 rounded"
                      style={{
                        background: completionRate >= 100 ? 'linear-gradient(135deg, #ffd700 0%, #ffab00 100%)' : '#f5f5f5',
                        color: completionRate >= 100 ? '#5d4e0c' : '#757575',
                      }}
                    >
                      {stats.achieved}/{stats.total}
                    </span>
                  </div>
                </div>

                {/* Notes preview */}
                {note.notes && (
                  <p className="text-sm text-pool-mid font-body line-clamp-2 mt-2">
                    {note.notes}
                  </p>
                )}

                {/* Progress bar */}
                <div className="mt-3 h-2 bg-pool-surface rounded-full overflow-hidden">
                  <div
                    className="h-full transition-all duration-500 rounded-full"
                    style={{
                      width: `${completionRate}%`,
                      background: completionRate >= 100
                        ? 'linear-gradient(90deg, #ffd700 0%, #ffab00 100%)'
                        : 'linear-gradient(90deg, var(--lane-yellow) 0%, var(--lane-red) 100%)',
                    }}
                  />
                </div>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}