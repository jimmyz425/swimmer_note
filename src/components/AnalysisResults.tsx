'use client';

import { useState, useEffect } from 'react';
import { VideoAnalysis } from '@/lib/video/storage';
import { PoseLandmark } from '@/lib/video/metrics';
import { PoseDebugPanel } from './PoseDebugViewer';
import { VideoSkeletonOverlay } from './VideoSkeletonOverlay';
import { KickRateGraph, StrokeRateGraph } from './KickRateGraph';
import { Waves, Activity, Loader2, Bug, Video, Trash2 } from 'lucide-react';

interface AnalysisResultsProps {
  analysis: VideoAnalysis;
  onDelete?: () => void;
}

export function AnalysisResults({ analysis, onDelete }: AnalysisResultsProps) {
  const [showDebug, setShowDebug] = useState(false);
  const [landmarksData, setLandmarksData] = useState<{ timestamp: number; landmarks: PoseLandmark[] }[]>([]);
  const [loadingLandmarks, setLoadingLandmarks] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);

  // Handle delete
  const handleDelete = async () => {
    if (!onDelete) return;
    setDeleting(true);
    try {
      await onDelete();
    } catch (err) {
      console.error('Delete failed:', err);
    } finally {
      setDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  // Load landmarks for debug view
  useEffect(() => {
    if (showDebug && analysis.rawLandmarks && landmarksData.length === 0) {
      setLoadingLandmarks(true);
      fetch(`/api/videos/${analysis.id}/landmarks`)
        .then(res => res.json())
        .then(data => {
          setLandmarksData(data.landmarks || []);
        })
        .catch(err => console.error('Failed to load landmarks:', err))
        .finally(() => setLoadingLandmarks(false));
    }
  }, [showDebug, analysis.id, analysis.rawLandmarks, landmarksData.length]);

  const strokeLabel = {
    freestyle: 'Freestyle',
    backstroke: 'Backstroke',
    breaststroke: 'Breaststroke',
    butterfly: 'Butterfly',
    im: 'IM',
  };

  const statusBadge = {
    pending: { bg: 'bg-gray-100', text: 'text-gray-600', label: 'Pending' },
    processing: { bg: 'bg-pool-light/50', text: 'text-pool-mid', label: 'Processing' },
    completed: { bg: 'bg-emerald-100', text: 'text-emerald-700', label: 'Completed' },
    failed: { bg: 'bg-red-100', text: 'text-red-700', label: 'Failed' },
  };

  const badge = statusBadge[analysis.status];

  return (
    <div className="glass-card rounded-xl p-4 relative">
      {/* Delete confirmation overlay */}
      {showDeleteConfirm && (
        <div className="absolute inset-0 bg-pool-surface/90 rounded-xl flex items-center justify-center z-10">
          <div className="bg-white rounded-xl p-4 shadow-lg max-w-sm">
            <p className="text-pool-dark font-semibold mb-2">Delete this analysis?</p>
            <p className="text-pool-mid text-sm mb-4">This will remove the video, landmarks data, and all metrics.</p>
            <div className="flex gap-3">
              <button
                onClick={handleDelete}
                disabled={deleting}
                className="flex-1 flex items-center justify-center gap-2 bg-red-500 text-white rounded-lg px-4 py-2
                  font-semibold hover:bg-red-600 transition-colors disabled:opacity-50"
              >
                {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                Delete
              </button>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                disabled={deleting}
                className="flex-1 px-4 py-2 rounded-lg font-semibold text-pool-dark bg-pool-surface hover:bg-pool-light transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header - compact */}
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2 text-sm">
          {strokeLabel[analysis.strokeType] && (
            <span className="px-2 py-0.5 rounded bg-pool-mid/20 text-pool-dark font-semibold">
              {strokeLabel[analysis.strokeType]}
            </span>
          )}
          <span className="text-pool-mid">{analysis.duration}s • {analysis.framesProcessed} frames</span>
        </div>
        <div className="flex items-center gap-2">
          <span className={`px-2 py-0.5 rounded text-xs font-semibold ${badge.bg} ${badge.text}`}>
            {badge.label}
          </span>
          {onDelete && (
            <button
              onClick={() => setShowDeleteConfirm(true)}
              className="text-pool-mid hover:text-red-500 transition-colors p-1 rounded hover:bg-red-50"
              title="Delete"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {analysis.status === 'completed' && (
        <>
          {/* Main content: Stats left, Graphs right */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-3">
            {/* Stats - compact */}
            <div className="md:col-span-1 flex flex-col gap-2">
              {/* Stroke Rate */}
              <div className="bg-pool-surface/50 rounded-lg p-3">
                <div className="flex items-center gap-2">
                  <Activity className="w-4 h-4 text-pool-deep" />
                  <span className="text-xs font-semibold text-pool-mid">Stroke Rate</span>
                </div>
                <div className="mt-1 flex items-baseline gap-1">
                  <span className="text-2xl font-bold text-pool-dark">{Math.round(analysis.metrics.strokeRate)}</span>
                  <span className="text-xs text-pool-mid">spm</span>
                </div>
                <div className="mt-1 text-xs text-pool-mid/70">
                  Peak: {analysis.metrics.strokeRatePeakHz?.toFixed(2) || '0'} Hz
                  • Valid: {analysis.metrics.strokeRateValidWindows || 0}/{analysis.metrics.strokeRateTotalWindows || 0}
                </div>
              </div>

              {/* Kick Rate */}
              <div className="bg-pool-surface/50 rounded-lg p-3">
                <div className="flex items-center gap-2">
                  <Waves className="w-4 h-4 text-pool-deep" />
                  <span className="text-xs font-semibold text-pool-mid">Kick Rate</span>
                </div>
                <div className="mt-1 flex items-baseline gap-1">
                  <span className="text-2xl font-bold text-pool-dark">{Math.round(analysis.metrics.kickRate)}</span>
                  <span className="text-xs text-pool-mid">kpm</span>
                </div>
                <div className="mt-1 text-xs text-pool-mid/70">
                  Peak: {analysis.metrics.kickRatePeakHz?.toFixed(2) || '0'} Hz
                  • Valid: {analysis.metrics.kickRateValidWindows || 0}/{analysis.metrics.kickRateTotalWindows || 0}
                </div>
              </div>
            </div>

            {/* Graphs - stacked */}
            <div className="md:col-span-3 flex flex-col gap-3">
              {/* Stroke Rate Graph */}
              {analysis.realtimeStrokeRates && analysis.realtimeStrokeRates.length > 0 ? (
                <StrokeRateGraph
                  realtimeStrokeRates={analysis.realtimeStrokeRates}
                  peakHz={analysis.metrics.strokeRatePeakHz}
                  minConfidence={1.5}
                  height={100}
                />
              ) : (
                <div className="bg-pool-surface/30 rounded-lg p-3 text-center text-pool-mid text-xs">
                  No stroke rate data
                </div>
              )}

              {/* Kick Rate Graph */}
              {analysis.realtimeKickRates && analysis.realtimeKickRates.length > 0 ? (
                <KickRateGraph
                  realtimeKickRates={analysis.realtimeKickRates}
                  peakHz={analysis.metrics.kickRatePeakHz}
                  minConfidence={1.5}
                  height={100}
                />
              ) : (
                <div className="bg-pool-surface/30 rounded-lg p-3 text-center text-pool-mid text-xs">
                  No kick rate data
                </div>
              )}
            </div>
          </div>

          {/* Videos section - collapsed at bottom */}
          <div className="space-y-2">
            {/* Video with Skeleton */}
            <details className="bg-emerald-50/30 rounded-lg">
              <summary className="p-2 cursor-pointer text-xs font-semibold text-pool-dark flex items-center gap-2 hover:bg-emerald-50/50">
                <Video className="w-3.5 h-3.5 text-emerald-600" />
                Video with Skeleton Overlay
              </summary>
              <div className="p-2 border-t border-emerald-100">
                <VideoSkeletonOverlay
                  videoId={analysis.id}
                  realtimeKickRates={analysis.realtimeKickRates}
                />
              </div>
            </details>

            {/* Pose Debug */}
            <details className="bg-purple-50/30 rounded-lg" open={showDebug} onToggle={(e) => setShowDebug((e.target as HTMLDetailsElement).open)}>
              <summary className="p-2 cursor-pointer text-xs font-semibold text-pool-dark flex items-center gap-2 hover:bg-purple-50/50">
                <Bug className="w-3.5 h-3.5 text-purple-600" />
                Pose Debug View
              </summary>
              <div className="p-2 border-t border-purple-100">
                {loadingLandmarks ? (
                  <div className="flex items-center gap-2 py-4 justify-center">
                    <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
                    <span className="text-xs text-pool-mid">Loading...</span>
                  </div>
                ) : landmarksData.length > 0 ? (
                  <PoseDebugPanel framesData={landmarksData} />
                ) : (
                  <p className="text-xs text-pool-mid text-center py-4">No pose data</p>
                )}
              </div>
            </details>
          </div>
        </>
      )}

      {analysis.status === 'processing' && (
        <div className="flex items-center justify-center py-6">
          <Loader2 className="w-6 h-6 text-pool-mid animate-spin" />
        </div>
      )}

      {analysis.status === 'failed' && (
        <div className="text-center py-6 text-red-600 text-sm">
          Analysis failed. Please try uploading again.
        </div>
      )}
    </div>
  );
}