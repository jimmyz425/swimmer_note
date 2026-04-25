import { getAllNotes } from '@/lib/data/notes';
import { NoteHistoryList } from '@/components/NoteHistoryList';

export default async function HistoryPage() {
  const notes = getAllNotes();

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
      <main className="max-w-2xl mx-auto py-8 px-4">
        <h1 className="text-2xl font-bold text-pool-dark mb-6">Training History</h1>

        <NoteHistoryList notes={notes} />
      </main>
    </div>
  );
}