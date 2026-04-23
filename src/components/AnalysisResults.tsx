'use client';

import { VideoAnalysis } from '@/lib/video/storage';
import { Waves, Activity, Timer, TrendingUp, CheckCircle2, Loader2, Sparkles, RefreshCw } from 'lucide-react';

interface AnalysisResultsProps {
  analysis: VideoAnalysis;
  onGenerateFeedback?: () => void;
  loadingFeedback?: boolean;
}

export function AnalysisResults({ analysis, onGenerateFeedback, loadingFeedback }: AnalysisResultsProps) {
  const metricGroups = [
    {
      title: 'Stroke Metrics',
      icon: <Activity className="w-5 h-5" />,
      metrics: [
        { label: 'Stroke Rate', value: analysis.metrics.strokeRate, unit: 'spm', description: 'Strokes per minute' },
      ],
    },
    {
      title: 'Kick Metrics',
      icon: <Waves className="w-5 h-5" />,
      metrics: [
        { label: 'Kick Rate', value: analysis.metrics.kickRate, unit: 'kps', description: 'Kicks per second' },
      ],
    },
    {
      title: 'Body Position',
      icon: <Timer className="w-5 h-5" />,
      metrics: [
        { label: 'Avg Angle', value: analysis.metrics.bodyAngleAvg.toFixed(1), unit: '°', description: 'Degrees from horizontal' },
        { label: 'Min Angle', value: analysis.metrics.bodyAngleMin.toFixed(1), unit: '°', description: 'Lowest angle' },
        { label: 'Max Angle', value: analysis.metrics.bodyAngleMax.toFixed(1), unit: '°', description: 'Highest angle' },
      ],
    },
    {
      title: 'Arm Mechanics',
      icon: <TrendingUp className="w-5 h-5" />,
      metrics: [
        { label: 'Elbow Height', value: analysis.metrics.elbowHeightAvg.toFixed(2), unit: '', description: 'Positive = high elbow catch' },
      ],
    },
  ];

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
    <div className="glass-card rounded-xl p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <h3 className="text-lg font-bold text-pool-dark">Analysis Results</h3>
          <span className={`px-3 py-1 rounded-lg text-sm font-semibold ${badge.bg} ${badge.text}`}>
            {badge.label}
          </span>
        </div>
        {strokeLabel[analysis.strokeType] && (
          <span className="px-3 py-1.5 rounded-lg text-sm font-semibold bg-pool-mid/20 text-pool-dark border border-pool-mid/30">
            {strokeLabel[analysis.strokeType]}
          </span>
        )}
      </div>

      {/* Video info */}
      <div className="text-sm text-pool-mid mb-4 flex items-center gap-4">
        <span>Duration: {analysis.duration}s</span>
        <span>Frames: {analysis.framesProcessed}</span>
      </div>

      {analysis.status === 'completed' && (
        <>
          {/* Metrics */}
          <div className="grid grid-cols-2 gap-4 mb-6">
            {metricGroups.map((group) => (
              <div key={group.title} className="bg-pool-surface/50 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-8 h-8 rounded-lg bg-pool-mid/20 flex items-center justify-center text-pool-deep">
                    {group.icon}
                  </div>
                  <span className="text-sm font-bold text-pool-dark">{group.title}</span>
                </div>
                <div className="space-y-2">
                  {group.metrics.map((metric) => (
                    <div key={metric.label} className="flex items-center justify-between">
                      <span className="text-xs text-pool-mid">{metric.label}</span>
                      <div className="flex items-center gap-1">
                        <span className="text-sm font-bold text-pool-dark">{metric.value}</span>
                        <span className="text-xs text-pool-mid">{metric.unit}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>

          {/* Coaching Feedback */}
          <div className="bg-gradient-to-r from-blue-50/80 to-pool-surface/50 rounded-xl border border-blue-100">
            <details open={!!analysis.coachingFeedback}>
              <summary className="p-3 cursor-pointer text-sm font-bold text-pool-dark flex items-center gap-2.5 hover:bg-blue-50 rounded-xl transition-colors">
                <div className="w-7 h-7 rounded-lg bg-blue-100 flex items-center justify-center">
                  <Sparkles className="w-4 h-4 text-blue-600" />
                </div>
                AI Coaching Feedback
                {onGenerateFeedback && (
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onGenerateFeedback();
                    }}
                    disabled={loadingFeedback}
                    className="ml-2 text-xs text-pool-deep hover:text-accent disabled:text-pool-mid/50 flex items-center gap-1 font-medium transition-colors"
                  >
                    <RefreshCw className={`w-3.5 h-3.5 ${loadingFeedback ? 'animate-spin' : ''}`} />
                    Generate
                  </button>
                )}
                <span className="text-xs text-pool-mid ml-auto font-normal">
                  {analysis.coachingFeedback ? 'Click to collapse' : 'Click to generate'}
                </span>
              </summary>
              <div className="p-3 pt-2 text-sm text-pool-dark whitespace-pre-line border-t border-blue-100">
                {loadingFeedback ? (
                  <div className="flex items-center gap-2">
                    <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
                    <span className="text-pool-mid">Generating feedback...</span>
                  </div>
                ) : analysis.coachingFeedback ? (
                  <div>{analysis.coachingFeedback}</div>
                ) : (
                  <span className="text-pool-mid">No feedback generated yet</span>
                )}
              </div>
            </details>
          </div>
        </>
      )}

      {analysis.status === 'processing' && (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="w-8 h-8 text-pool-mid animate-spin" />
        </div>
      )}

      {analysis.status === 'failed' && (
        <div className="text-center py-8 text-red-600">
          <p>Analysis failed. Please try uploading again.</p>
        </div>
      )}
    </div>
  );
}