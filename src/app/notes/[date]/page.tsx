import { TrainingNote } from '@/lib/types';
import { getNote } from '@/lib/data/notes';
import { DailyNoteFormWrapper } from '@/app/DailyNoteFormWrapper';
import Link from 'next/link';
import { notFound } from 'next/navigation';

interface NotePageProps {
  params: Promise<{ date: string }>;
}

export default async function NotePage({ params }: NotePageProps) {
  const { date } = await params;
  const note = getNote(date);

  if (!note) {
    notFound();
  }

  const formatDate = (dateStr: string): string => {
    return new Date(dateStr).toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="flex-1 bg-zinc-50">
      <main className="max-w-2xl mx-auto py-8 px-4">
        <header className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Training Note</h1>
            <p className="text-sm text-gray-500 mt-1">{formatDate(date)}</p>
          </div>
          <div className="flex gap-3">
            <Link href="/history" className="text-sm text-blue-600 hover:underline">
              History
            </Link>
            <Link href="/" className="text-sm text-blue-600 hover:underline">
              Today
            </Link>
          </div>
        </header>

        <DailyNoteFormWrapper initialNote={note} />
      </main>
    </div>
  );
}