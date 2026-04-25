import { getAllNotes } from '@/lib/data/notes';
import { NoteHistoryList } from '@/components/NoteHistoryList';

export default async function HistoryPage() {
  const notes = getAllNotes();

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
      <main className="max-w-2xl mx-auto py-8 px-4">
        {/* Header */}
        <header className="mb-8">
          <h1 className="title-impact text-pool-dark">
            TRAINING HISTORY
          </h1>
          <div className="lane-divider mt-6" />
        </header>

        {/* Timeline */}
        <section className="py-4">
          <NoteHistoryList notes={notes} />
        </section>
      </main>

      {/* Lane divider */}
      <div className="lane-divider mt-8" />
    </div>
  );
}