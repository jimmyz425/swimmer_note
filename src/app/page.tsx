import { TrainingNote } from '@/lib/types';
import { getNote, createEmptyNote } from '@/lib/data/notes';
import { getStrokes } from '@/lib/data/config';
import { DailyNoteFormWrapper } from './DailyNoteFormWrapper';
import { StrokeCard, MasterTreeCard } from '@/components/StrokeCard';

export default async function Home() {
  const today = new Date().toISOString().split('T')[0];
  const existingNote = getNote(today);
  const note: TrainingNote = existingNote || createEmptyNote(today);
  const strokes = getStrokes();

  // Create stroke lookup map for GoalList
  const strokeLookup = strokes.map(s => ({ id: s.id, name: s.name }));

  const formatDate = () => {
    const date = new Date();
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric'
    });
  };

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
      <main className="max-w-5xl mx-auto py-8 px-4 md:px-8">
        {/* Header - Starting Block */}
        <header className="mb-12">
          <div>
            <h1 className="title-impact text-pool-dark">
              TODAY&apos;S TRAINING
            </h1>
            <p className="text-base text-pool-mid font-medium mt-1 font-body">
              {formatDate()}
            </p>
          </div>

          {/* Lane divider under header */}
          <div className="lane-divider mt-6" />
        </header>

        {/* Stroke Selection */}
        <section className="mb-10">
          <h2 className="font-heading text-xl font-bold text-pool-dark mb-6">
            Select Your Stroke
          </h2>

          {/* Stroke cards in responsive grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4">
            {strokes.map((stroke) => (
              <StrokeCard
                key={stroke.id}
                {...stroke}
              />
            ))}
            <MasterTreeCard />
          </div>
        </section>

        {/* Goals Section */}
        <section className="glass-card rounded-2xl p-6 md:p-8">
          <h2 className="font-heading text-xl font-bold text-pool-dark mb-6">
            Today&apos;s Session
          </h2>

          <DailyNoteFormWrapper initialNote={note} strokes={strokeLookup} />
        </section>
      </main>

      {/* Lane divider at bottom */}
      <div className="lane-divider mt-8" />
    </div>
  );
}