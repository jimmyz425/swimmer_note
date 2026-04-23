'use client';

import { useRouter } from 'next/navigation';
import { Video, Sparkles } from 'lucide-react';

export function VideoAnalysisCard() {
  const router = useRouter();

  return (
    <button
      onClick={() => router.push('/videos')}
      className="glass-card rounded-xl p-5 w-full hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300
        flex items-center gap-4 border-2 border-transparent hover:border-pool-mid/30"
    >
      <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-100 to-purple-100 flex items-center justify-center">
        <Video className="w-6 h-6 text-blue-600" />
      </div>
      <div className="flex-1">
        <h3 className="font-bold text-pool-dark">Video Analysis</h3>
        <p className="text-sm text-pool-mid">Upload underwater footage for pose tracking</p>
      </div>
      <div className="flex items-center gap-2 text-xs font-semibold bg-purple-100 text-purple-700 px-3 py-1.5 rounded-lg">
        <Sparkles className="w-3.5 h-3.5" />
        AI
      </div>
    </button>
  );
}