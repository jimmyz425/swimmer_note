'use client';

import { useState, useEffect } from 'react';
import { TechniqueTreeNode, MetricValue } from '@/lib/types';
import { RefreshCw, Plus, X, Sparkles, Loader2, ChevronDown } from 'lucide-react';

interface NodeDetailPanelProps {
  node: TechniqueTreeNode | null;
  strokeId: string;
  onConfirm: (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string) => void;
  onClose: () => void;
  onExpandNode?: (nodeId: string, coachingTips: string) => void;
  onAddCustomNode?: (parentNode: TechniqueTreeNode) => void;
}

export function NodeDetailPanel({ node, strokeId, onConfirm, onClose, onExpandNode, onAddCustomNode }: NodeDetailPanelProps) {
  const [metrics, setMetrics] = useState<Record<string, { actual: number; unit: string }>>({});
  const [coachingTips, setCoachingTips] = useState<string | null>(null);
  const [loadingTips, setLoadingTips] = useState(false);

  // Fetch coaching tips when node changes
  useEffect(() => {
    if (node) {
      setLoadingTips(true);
      setCoachingTips(null);

      fetch('/api/coaching', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ node }),
      })
        .then(res => res.json())
        .then(data => setCoachingTips(data.tips))
        .catch(err => {
          console.error('Failed to fetch coaching tips:', err);
          setCoachingTips('Failed to load coaching tips');
        })
        .finally(() => setLoadingTips(false));
    } else {
      setCoachingTips(null);
    }
  }, [node]);

  if (!node) {
    return (
      <div className="glass-card rounded-xl p-6 h-full flex flex-col items-center justify-center">
        <div className="w-16 h-16 rounded-full bg-pool-mid/20 flex items-center justify-center mb-4">
          <ChevronDown className="w-8 h-8 text-pool-mid" />
        </div>
        <p className="text-pool-mid text-center font-medium">
          Click a node in the flowchart to see details
        </p>
      </div>
    );
  }

  const handleMetricChange = (metricId: string, value: number) => {
    setMetrics(prev => ({
      ...prev,
      [metricId]: {
        actual: value,
        unit: node.metrics?.find(m => m.id === metricId)?.unit || '',
      },
    }));
  };

  const handleConfirm = () => {
    const metricValues: Record<string, MetricValue> = {};
    for (const [id, val] of Object.entries(metrics)) {
      metricValues[id] = { actual: val.actual, unit: val.unit };
    }
    onConfirm(node, metricValues, coachingTips || undefined);
  };

  const levelColors = [
    'bg-emerald-100 text-emerald-700 border-emerald-300',
    'bg-pool-mid/20 text-pool-dark border-pool-mid/30',
    'bg-amber-100 text-amber-700 border-amber-300',
    'bg-orange-100 text-orange-700 border-orange-300',
    'bg-purple-100 text-purple-700 border-purple-300',
    'bg-pink-100 text-pink-700 border-pink-300',
    'bg-indigo-100 text-indigo-700 border-indigo-300',
    'bg-red-100 text-red-700 border-red-300',
  ];

  const levelColor = levelColors[Math.min(node.level - 1, levelColors.length - 1)];

  const handleExpandNode = async () => {
    if (!onExpandNode || !coachingTips) return;
    onExpandNode(node.id, coachingTips);
  };

  return (
    <div className="glass-card rounded-xl p-5 h-full flex flex-col overflow-y-auto">
      {/* Close button */}
      <button onClick={onClose} className="text-pool-mid hover:text-pool-deep self-end mb-2 transition-colors">
        <X className="w-5 h-5" />
      </button>

      {/* Header */}
      <div className="flex items-center gap-2 mb-3 flex-wrap">
        <span className={`px-3 py-1.5 rounded-lg text-sm font-semibold border ${levelColor}`}>
          Level {node.level}
        </span>
        {node.revisit && (
          <span className="px-3 py-1.5 rounded-lg text-sm font-semibold bg-amber-100 text-amber-700 border border-amber-200 flex items-center gap-1.5">
            <RefreshCw className="w-3.5 h-3.5" />
            Revisit
          </span>
        )}
      </div>

      {/* Name */}
      <h3 className="text-xl font-bold text-pool-dark mb-2">{node.name}</h3>

      {/* Description */}
      <p className="text-pool-mid mb-4">{node.description}</p>

      {/* Coaching Tips - AI generated */}
      <div className="mb-4">
        <details className="bg-gradient-to-r from-blue-50/80 to-pool-surface/50 rounded-xl border border-blue-100">
          <summary className="p-3 cursor-pointer text-sm font-bold text-pool-dark flex items-center gap-2.5 hover:bg-blue-50 rounded-xl transition-colors">
            <div className="w-7 h-7 rounded-lg bg-blue-100 flex items-center justify-center">
              <Sparkles className="w-4 h-4 text-blue-600" />
            </div>
            Coach&apos;s Key Focus Points
            <span className="text-xs text-pool-mid ml-auto font-normal">Click to expand</span>
          </summary>
          <div className="p-3 pt-2 text-sm text-pool-dark whitespace-pre-line border-t border-blue-100">
            {loadingTips ? (
              <div className="flex items-center gap-2">
                <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
                <span className="text-pool-mid">Loading coaching tips...</span>
              </div>
            ) : coachingTips ? (
              <div>{coachingTips}</div>
            ) : (
              <span className="text-pool-mid">Tips not available</span>
            )}
          </div>
        </details>
      </div>

      {/* Expand Node Button */}
      {onExpandNode && coachingTips && !loadingTips && (
        <button
          onClick={handleExpandNode}
          className="mb-3 flex items-center gap-2.5 text-sm font-semibold text-pool-deep hover:text-accent transition-colors
            bg-pool-mid/10 px-4 py-2.5 rounded-xl hover:bg-pool-mid/20 border border-pool-mid/20"
        >
          <div className="w-6 h-6 rounded-lg bg-pool-mid/20 flex items-center justify-center">
            <RefreshCw className="w-3.5 h-3.5" />
          </div>
          Expand Node with LLM
          <span className="text-xs text-pool-mid font-normal ml-auto">Split tips into sub-nodes</span>
        </button>
      )}

      {/* Add Custom Node Button */}
      {onAddCustomNode && (
        <button
          onClick={() => onAddCustomNode(node)}
          className="mb-3 flex items-center gap-2.5 text-sm font-semibold text-pool-deep hover:text-accent transition-colors
            bg-pool-surface px-4 py-2.5 rounded-xl hover:bg-pool-light/50 border border-pool-light/30"
        >
          <div className="w-6 h-6 rounded-lg bg-pool-light/30 flex items-center justify-center">
            <Plus className="w-3.5 h-3.5" />
          </div>
          Add Custom Sub-Node
        </button>
      )}

      {/* Metrics */}
      {node.metrics && node.metrics.length > 0 && (
        <div className="mb-4">
          <h4 className="text-sm font-bold text-pool-dark mb-2">Track Your Progress</h4>
          <div className="space-y-3">
            {node.metrics.map(metric => (
              <div key={metric.id} className="flex items-center gap-2 bg-pool-surface/50 px-3 py-2 rounded-lg">
                <label className="text-sm font-medium text-pool-mid flex-1">{metric.name}:</label>
                <input
                  type="number"
                  value={metrics[metric.id]?.actual ?? ''}
                  onChange={(e) => handleMetricChange(metric.id, parseFloat(e.target.value) || 0)}
                  placeholder="0"
                  className="w-20 rounded-lg border border-pool-light/50 px-2 py-1 text-sm font-semibold text-pool-dark
                    bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none"
                />
                <span className="text-xs text-pool-mid">{metric.unit}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Prerequisites */}
      {node.prerequisites.length > 0 && (
        <div className="mb-4">
          <h4 className="text-sm font-bold text-pool-dark mb-1">Prerequisites</h4>
          <p className="text-xs text-pool-mid">
            Complete these before attempting: {node.prerequisites.join(', ')}
          </p>
        </div>
      )}

      {/* Confirm Button */}
      <button
        onClick={handleConfirm}
        className="mt-auto flex items-center justify-center gap-2 bg-pool-mid text-white rounded-xl px-6 py-3
          font-semibold hover:bg-pool-deep transition-colors shadow-lg shadow-pool-mid/20"
      >
        <Plus className="w-4 h-4" />
        Add as Today&apos;s Goal
      </button>
    </div>
  );
}