import { getAllNotes } from '@/lib/data/notes';
import { NoteHistoryList } from '@/components/NoteHistoryList';
import Link from 'next/link';

export default async function HistoryPage() {
  const notes = getAllNotes();

  return (
    <div className="flex-1 bg-zinc-50">
      <main className="max-w-2xl mx-auto py-8 px-4">
        <header className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Training History</h1>
          <Link href="/" className="text-sm text-blue-600 hover:underline">
            Today&apos;s Note
          </Link>
        </header>

        <NoteHistoryList notes={notes} />
      </main>
    </div>
  );
}