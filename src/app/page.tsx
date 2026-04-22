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
    <div className="flex-1 min-h-screen relative">
      <main className="max-w-5xl mx-auto py-8 px-4 md:px-8">
        {/* Header */}
        <header className="mb-10">
          <div className="flex items-center gap-5 mb-3">
            {/* Water droplet logo */}
            <div className="relative">
              <div className="w-16 h-16 water-drop bg-gradient-to-b from-pool-light to-pool-deep flex items-center justify-center shadow-lg shadow-pool-mid/30">
                <svg className="w-8 h-8 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12C22 18 18 22 12 22C6 22 2 18 2 12Z" strokeLinecap="round"/>
                  <path d="M8 12C8 10 10 8 12 8C14 8 16 10 16 12" strokeLinecap="round"/>
                </svg>
              </div>
            </div>
            <div>
              <h1 className="text-4xl md:text-5xl font-extrabold text-pool-dark tracking-tight">
                Today&apos;s Training
              </h1>
              <p className="text-base text-pool-mid font-medium mt-1.5">
                {formatDate()}
              </p>
            </div>
          </div>
        </header>

        {/* Stroke Selection */}
        <section className="mb-10">
          <h2 className="text-lg font-bold text-pool-dark mb-5 flex items-center gap-3">
            <svg className="w-5 h-5 text-pool-mid" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <circle cx="12" cy="12" r="10"/>
              <path d="M8 12h8M12 8v8"/>
            </svg>
            Select Your Stroke
          </h2>

          {/* Stroke cards in responsive grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4 md:gap-5">
            {strokes.map((stroke, index) => (
              <StrokeCard
                key={stroke.id}
                {...stroke}
                laneNumber={index + 1}
              />
            ))}
          </div>

          {/* Master Techniques */}
          <div className="mt-5">
            <MasterTreeCard />
          </div>
        </section>

        {/* Goals Section */}
        <section className="glass-card rounded-2xl p-6 md:p-8">
          <h2 className="text-xl font-bold text-pool-dark mb-6 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-pool-mid/20 flex items-center justify-center">
              <svg className="w-5 h-5 text-pool-deep" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M9 12l2 2 4-4"/>
                <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9c2.12 0 4.07.74 5.61 1.97"/>
              </svg>
            </div>
            Today&apos;s Goals
            <div className="flex-1 h-1.5 bg-gradient-to-r from-pool-light to-transparent rounded-full" />
          </h2>

          <DailyNoteFormWrapper initialNote={note} strokes={strokeLookup} />
        </section>
      </main>
    </div>
  );
}