'use client';

import { useState, useCallback, useEffect } from 'react';
import { VideoUpload } from '@/components/VideoUpload';
import { AnalysisResults } from '@/components/AnalysisResults';
import { usePoseAnalysis, PoseModelVariant, AnalysisFramerate, FRAMERATE_INFO } from '@/lib/video/poseAnalysis';
import { VideoAnalysis } from '@/lib/video/storage';
import { Loader2, Trash2 } from 'lucide-react';
import { Navigation } from '@/components/Navigation';

export default function ToolsPage() {
  const [modelVariant, setModelVariant] = useState<PoseModelVariant>('lite');
  const [framerate, setFramerate] = useState<AnalysisFramerate>('auto');
  const { analyzeVideo, loading: analyzing, progress, error: analysisError, modelInfo } = usePoseAnalysis(modelVariant);
  const [analyses, setAnalyses] = useState<VideoAnalysis[]>([]);
  const [selectedAnalysis, setSelectedAnalysis] = useState<VideoAnalysis | null>(null);
  const [uploading, setUploading] = useState(false);
  const [deleting, setDeleting] = useState<string | null>(null);

  // Fetch existing analyses
  const fetchAnalyses = useCallback(async () => {
    try {
      const res = await fetch('/api/videos');
      const data = await res.json();
      setAnalyses(data.analyses || []);
    } catch (err) {
      console.error('Failed to fetch analyses:', err);
    }
  }, []);

  // Handle delete analysis
  const handleDeleteAnalysis = useCallback(async (id: string) => {
    setDeleting(id);
    try {
      const res = await fetch(`/api/videos/${id}`, { method: 'DELETE' });
      const data = await res.json();

      if (data.success) {
        setAnalyses(prev => prev.filter(a => a.id !== id));
        if (selectedAnalysis?.id === id) {
          setSelectedAnalysis(null);
        }
      } else {
        throw new Error(data.error || 'Delete failed');
      }
    } catch (err) {
      console.error('Delete failed:', err);
    } finally {
      setDeleting(null);
    }
  }, [selectedAnalysis]);

  // Handle video upload and analysis
  const handleUpload = useCallback(async (file: File, strokeType: string, selectedModel: PoseModelVariant, selectedFramerate: AnalysisFramerate) => {
    setUploading(true);
    setModelVariant(selectedModel);
    setFramerate(selectedFramerate);

    try {
      // First analyze the video locally using MediaPipe
      const result = await analyzeVideo(file, selectedFramerate);

      if (!result) {
        throw new Error('Analysis failed');
      }

      // Upload video with analysis results
      const formData = new FormData();
      formData.append('file', file);
      formData.append('strokeType', strokeType);
      formData.append('modelVariant', selectedModel);
      formData.append('framerate', selectedFramerate.toString());
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

  // Load analyses on mount
  useEffect(() => {
    fetchAnalyses();
  }, [fetchAnalyses]);

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
      <Navigation />

      {/* Analysis progress overlay */}
      {(analyzing || uploading) && (
        <div className="fixed inset-0 bg-pool-surface/80 flex items-center justify-center z-30">
          <div className="glass-card rounded-xl p-6 flex flex-col items-center gap-4 max-w-sm">
            <Loader2 className="w-8 h-8 text-pool-mid animate-spin" />
            <p className="text-pool-dark font-semibold">
              {analyzing ? 'Analyzing video...' : 'Uploading analysis...'}
            </p>
            {analyzing && modelInfo && (
              <p className="text-xs text-pool-mid">
                {modelInfo.name} model • {FRAMERATE_INFO[framerate].label}
              </p>
            )}
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
        {/* Header */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-pool-dark">Tools</h1>
          <p className="text-pool-mid text-sm mt-1">Video analysis and other utilities</p>
        </div>

        {/* Video Analysis Section */}
        <section className="mb-8">
          <h2 className="text-lg font-bold text-pool-dark mb-4">Video Pose Analysis</h2>
          <VideoUpload onUpload={handleUpload} disabled={analyzing || uploading} />
        </section>

        {/* Selected analysis */}
        {selectedAnalysis && (
          <section className="mb-8">
            <h2 className="text-lg font-bold text-pool-dark mb-4">Current Analysis</h2>
            <AnalysisResults
              analysis={selectedAnalysis}
              onDelete={() => handleDeleteAnalysis(selectedAnalysis.id)}
            />
          </section>
        )}

        {/* Analysis history */}
        {analyses.length > 0 && !selectedAnalysis && (
          <section>
            <h2 className="text-lg font-bold text-pool-dark mb-4">Recent Analyses</h2>
            <div className="overflow-x-auto pb-4 -mx-4 px-4 scroll-smooth [&::-webkit-scrollbar]:h-2 [&::-webkit-scrollbar-track]:bg-pool-light/30 [&::-webkit-scrollbar-track]:rounded-full [&::-webkit-scrollbar-thumb]:bg-pool-mid/50 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:hover:bg-pool-mid">
              <div className="flex gap-4" style={{ minWidth: 'min-content' }}>
                {analyses.map((analysis) => {
                  let dateStr = 'Unknown date';
                  try {
                    const date = new Date(analysis.createdAt);
                    if (!isNaN(date.getTime())) {
                      dateStr = date.toLocaleDateString();
                    }
                  } catch {
                    dateStr = 'Invalid date';
                  }

                  return (
                    <div
                      key={analysis.id}
                      className="glass-card rounded-xl p-4 flex flex-col justify-between hover:shadow-lg transition-all duration-300 ease-out cursor-pointer flex-shrink-0"
                      style={{ width: '280px', height: '140px' }}
                      onClick={() => setSelectedAnalysis(analysis)}
                    >
                      <div>
                        <p className="font-semibold text-pool-dark truncate">{analysis.filename}</p>
                        <p className="text-sm text-pool-mid mt-1">
                          {analysis.strokeType} • {dateStr}
                        </p>
                      </div>
                      <div className="flex items-center justify-between mt-2">
                        <span className={`text-xs font-semibold px-3 py-1 rounded-lg ${
                          analysis.status === 'completed' ? 'bg-emerald-100 text-emerald-700' :
                          analysis.status === 'processing' ? 'bg-pool-light/50 text-pool-mid' :
                          'bg-gray-100 text-gray-600'
                        }`}>
                          {analysis.status}
                        </span>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeleteAnalysis(analysis.id);
                          }}
                          disabled={deleting === analysis.id}
                          className="text-pool-mid hover:text-red-500 transition-colors p-2 rounded-lg hover:bg-red-50 disabled:opacity-50"
                          title="Delete"
                        >
                          {deleting === analysis.id ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Trash2 className="w-4 h-4" />
                          )}
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
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