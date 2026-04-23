'use client';

import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { VideoUpload } from '@/components/VideoUpload';
import { AnalysisResults } from '@/components/AnalysisResults';
import { usePoseAnalysis } from '@/lib/video/poseAnalysis';
import { VideoAnalysis } from '@/lib/video/storage';
import { ArrowLeft, History, Loader2, Video as VideoIcon } from 'lucide-react';

export default function VideoAnalysisPage() {
  const router = useRouter();
  const { analyzeVideo, loading: analyzing, progress, error: analysisError } = usePoseAnalysis();
  const [analyses, setAnalyses] = useState<VideoAnalysis[]>([]);
  const [selectedAnalysis, setSelectedAnalysis] = useState<VideoAnalysis | null>(null);
  const [loadingAnalyses, setLoadingAnalyses] = useState(false);
  const [uploading, setUploading] = useState(false);

  // Fetch existing analyses
  const fetchAnalyses = useCallback(async () => {
    setLoadingAnalyses(true);
    try {
      const res = await fetch('/api/videos');
      const data = await res.json();
      setAnalyses(data.analyses || []);
    } catch (err) {
      console.error('Failed to fetch analyses:', err);
    } finally {
      setLoadingAnalyses(false);
    }
  }, []);

  // Handle video upload and analysis
  const handleUpload = useCallback(async (file: File, strokeType: string) => {
    setUploading(true);

    try {
      // First analyze the video locally using MediaPipe
      const result = await analyzeVideo(file);

      if (!result) {
        throw new Error('Analysis failed');
      }

      // Upload video with analysis results
      const formData = new FormData();
      formData.append('file', file);
      formData.append('strokeType', strokeType);
      formData.append('metrics', JSON.stringify(result.metrics));
      formData.append('landmarks', JSON.stringify(result.frames));

      const res = await fetch('/api/videos', {
        method: 'POST',
        body: formData,
      });

      const data = await res.json();

      if (data.success) {
        // Add to list and select
        setAnalyses(prev => [data.analysis, ...prev]);
        setSelectedAnalysis(data.analysis);
      } else {
        throw new Error(data.error || 'Upload failed');
      }
    } catch (err) {
      console.error('Upload failed:', err);
    } finally {
      setUploading(false);
    }
  }, [analyzeVideo]);

  // Generate feedback for existing analysis
  const generateFeedback = useCallback(async () => {
    if (!selectedAnalysis) return;

    // TODO: Implement feedback regeneration via API
  }, [selectedAnalysis]);

  // Load analyses on mount
  useState(() => {
    fetchAnalyses();
  });

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
      {/* Header */}
      <header className="glass-card shadow-sm px-6 py-4 flex items-center justify-between sticky top-0 z-20">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push('/')}
            className="flex items-center gap-2 text-pool-dark hover:text-pool-deep transition-colors font-medium"
          >
            <ArrowLeft className="w-5 h-5" />
            Back
          </button>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-pool-mid/20 flex items-center justify-center">
              <VideoIcon className="w-5 h-5 text-pool-deep" />
            </div>
            <h1 className="text-xl font-bold text-pool-dark">Video Analysis</h1>
          </div>
        </div>

        <button
          onClick={fetchAnalyses}
          disabled={loadingAnalyses}
          className="flex items-center gap-2 text-pool-mid hover:text-pool-deep transition-colors font-medium"
        >
          {loadingAnalyses ? (
            <Loader2 className="w-5 h-5 animate-spin" />
          ) : (
            <History className="w-5 h-5" />
          )}
          History
        </button>
      </header>

      {/* Analysis progress overlay */}
      {(analyzing || uploading) && (
        <div className="fixed inset-0 bg-pool-surface/80 flex items-center justify-center z-30">
          <div className="glass-card rounded-xl p-6 flex flex-col items-center gap-4 max-w-sm">
            <Loader2 className="w-8 h-8 text-pool-mid animate-spin" />
            <p className="text-pool-dark font-semibold">
              {analyzing ? 'Analyzing video...' : 'Uploading analysis...'}
            </p>
            {analyzing && (
              <div className="w-full">
                <div className="h-2 bg-pool-light/50 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-pool-mid transition-all duration-300"
                    style={{ width: `${progress}%` }}
                  />
                </div>
                <p className="text-xs text-pool-mid mt-2 text-center">{progress}% processed</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Main content */}
      <main className="max-w-5xl mx-auto py-8 px-4 md:px-8">
        {/* Upload section */}
        <section className="mb-8">
          <h2 className="text-lg font-bold text-pool-dark mb-4">Upload Video</h2>
          <VideoUpload onUpload={handleUpload} disabled={analyzing || uploading} />
        </section>

        {/* Selected analysis */}
        {selectedAnalysis && (
          <section className="mb-8">
            <h2 className="text-lg font-bold text-pool-dark mb-4">Current Analysis</h2>
            <AnalysisResults
              analysis={selectedAnalysis}
              onGenerateFeedback={generateFeedback}
            />
          </section>
        )}

        {/* Analysis history */}
        {analyses.length > 0 && !selectedAnalysis && (
          <section>
            <h2 className="text-lg font-bold text-pool-dark mb-4">Recent Analyses</h2>
            <div className="space-y-3">
              {analyses.map((analysis) => (
                <button
                  key={analysis.id}
                  onClick={() => setSelectedAnalysis(analysis)}
                  className="glass-card rounded-xl p-4 w-full text-left hover:shadow-lg transition-all"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="font-semibold text-pool-dark">{analysis.filename}</p>
                      <p className="text-sm text-pool-mid">
                        {analysis.strokeType} • {new Date(analysis.createdAt).toLocaleDateString()}
                      </p>
                    </div>
                    <span className="text-xs font-semibold bg-pool-mid/20 text-pool-dark px-3 py-1 rounded-lg">
                      {analysis.status}
                    </span>
                  </div>
                </button>
              ))}
            </div>
          </section>
        )}

        {/* Error display */}
        {analysisError && (
          <div className="fixed bottom-4 left-4 right-4 bg-red-100 text-red-700 px-6 py-3 rounded-xl shadow-lg z-30">
            {analysisError}
          </div>
        )}
      </main>
    </div>
  );
}