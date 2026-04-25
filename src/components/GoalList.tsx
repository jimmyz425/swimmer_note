'use client';

import { useState } from 'react';
import { Goal, GoalStatus } from '@/lib/types';
import {
  Clock,
  Activity,
  CheckCircle2,
  SkipForward,
  RefreshCw,
  Sparkles,
  MessageCircle,
  Target,
  Timer,
  Zap,
  Waves,
  X
} from 'lucide-react';

interface GoalListProps {
  goals: Goal[];
  strokes: { id: string; name: string }[];
  techniques: { id: string; name: string }[];
  onStatusChange?: (goalId: string, status: GoalStatus) => void;
  onDelete?: (goalId: string) => void;
  onMetricChange?: (goalId: string, metricId: string, value: number) => void;
  onNotesChange?: (goalId: string, notes: string) => void;
}

export function GoalList({ goals, strokes, techniques, onStatusChange, onDelete, onMetricChange, onNotesChange }: GoalListProps) {

  const statusStyles: Record<GoalStatus, { bg: string; text: string; icon: React.ReactNode; ring: string }> = {
    pending: {
      bg: 'bg-pool-surface',
      text: 'text-pool-mid',
      icon: <Clock className="w-4 h-4" />,
      ring: 'ring-pool-light',
    },
    in_progress: {
      bg: 'bg-gradient-to-r from-pool-light/80 to-pool-mid/60',
      text: 'text-pool-dark',
      icon: <Activity className="w-4 h-4" />,
      ring: 'ring-pool-mid',
    },
    completed: {
      bg: 'bg-gradient-to-r from-emerald-400/80 to-green-500/60',
      text: 'text-emerald-900',
      icon: <CheckCircle2 className="w-4 h-4" />,
      ring: 'ring-emerald-400',
    },
    abandoned: {
      bg: 'bg-gray-100',
      text: 'text-gray-500',
      icon: <SkipForward className="w-4 h-4" />,
      ring: 'ring-gray-300',
    },
  };

  const getStatusLabel = (status: GoalStatus): string => {
    switch (status) {
      case 'pending': return 'Ready';
      case 'in_progress': return 'Swimming';
      case 'completed': return 'Done';
      case 'abandoned': return 'Skipped';
    }
  };

  const getTargetLabel = (goal: Goal): string | null => {
    if (goal.type === 'stroke' && goal.target) {
      const stroke = strokes.find(s => s.id === goal.target);
      return stroke?.name || goal.target;
    }
    if (goal.type === 'technique' && goal.target) {
      const technique = techniques.find(t => t.id === goal.target);
      return technique?.name || goal.target;
    }
    return null;
  };

  const getStrokeSource = (goal: Goal): { id: string; name: string; icon: React.ReactNode } | null => {
    if (!goal.strokeId) return null;

    const stroke = strokes.find(s => s.id === goal.strokeId);
    if (!stroke) {
      // Handle master tree case
      if (goal.strokeId === 'master') {
        return { id: 'master', name: 'Master', icon: <Sparkles className="w-3.5 h-3.5" /> };
      }
      return { id: goal.strokeId, name: goal.strokeId, icon: <Waves className="w-3.5 h-3.5" /> };
    }

    return { id: stroke.id, name: stroke.name, icon: <Waves className="w-3.5 h-3.5" /> };
  };

  if (goals.length === 0) {
    return (
      <div className="text-center py-12 glass-card rounded-xl">
        <div className="relative inline-block mb-4">
          <div className="w-20 h-20 rounded-full bg-gradient-to-b from-pool-light to-pool-mid animate-pulse flex items-center justify-center">
            <Target className="w-10 h-10 text-white" />
          </div>
        </div>
        <p className="text-pool-deep font-semibold text-lg mb-2">
          No goals for today&apos;s session
        </p>
        <p className="text-pool-mid text-sm">
          Select a stroke above to add goals from the technique tree
        </p>
      </div>
    );
  }

  return (
    <ul className="space-y-4">
      {goals.map((goal, index) => {
        const targetLabel = getTargetLabel(goal);
        const strokeSource = getStrokeSource(goal);
        const style = statusStyles[goal.status];

        return (
          <li
            key={goal.id}
            className="group relative glass-card rounded-xl p-5
              transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5
              ripple-container overflow-hidden"
          >
            {/* Lane number */}
            <div className="absolute top-4 left-4 w-9 h-9 rounded-xl bg-pool-mid/20 text-pool-dark font-bold text-sm flex items-center justify-center">
              {index + 1}
            </div>

            {/* Accent line */}
            <div className="absolute top-0 left-0 bottom-0 w-2 bg-gradient-to-b from-pool-light via-pool-mid to-pool-deep opacity-50 rounded-l-xl" />

            {/* Hover ripple effect */}
            <div className="absolute inset-0 bg-gradient-radial from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

            <div className="flex items-start gap-5 relative z-10">
              {/* Main content */}
              <div className="flex-1 ml-8">
                {/* Header row */}
                <div className="flex items-center gap-2 mb-3 flex-wrap">
                  {/* Stroke source badge */}
                  {strokeSource && (
                    <span className={`text-xs font-bold px-3 py-1.5 rounded-lg flex items-center gap-1.5 ${
                      strokeSource.id === 'master'
                        ? 'bg-amber-100 text-amber-700 border border-amber-200'
                        : 'bg-pool-mid/20 text-pool-dark border border-pool-mid/30'
                    }`}>
                      {strokeSource.icon}
                      {strokeSource.name}
                    </span>
                  )}
                  {/* Target tag */}
                  {targetLabel && (
                    <span className="text-xs font-bold text-pool-dark bg-pool-surface/80 px-3 py-1.5 rounded-lg border border-pool-light/50">
                      {targetLabel}
                    </span>
                  )}
                  {/* Revisit indicator */}
                  {goal.revisit && (
                    <span className="text-xs font-bold text-amber-700 bg-amber-100 px-3 py-1.5 rounded-lg border border-amber-200 flex items-center gap-1.5">
                      <Timer className="w-3.5 h-3.5" />
                      Revisit
                    </span>
                  )}
                  {/* Status badge */}
                  <span className={`text-xs font-semibold px-3 py-1.5 rounded-lg ${style.bg} ${style.text} ring-1 ${style.ring} flex items-center gap-1.5`}>
                    {style.icon}
                    {getStatusLabel(goal.status)}
                  </span>
                </div>

                {/* Description */}
                <p className="text-base font-semibold text-pool-dark mb-3">
                  {goal.description}
                </p>

                {/* Metrics */}
                {goal.metrics && Object.keys(goal.metrics).length > 0 && onMetricChange && (
                  <div className="mb-3 flex flex-wrap gap-3">
                    {Object.entries(goal.metrics).map(([metricId, metric]) => (
                      <div key={metricId} className="flex items-center gap-2 bg-pool-surface/50 px-3 py-2 rounded-xl">
                        <span className="text-sm font-medium text-pool-mid">{metricId}:</span>
                        <input
                          type="number"
                          value={metric.actual ?? ''}
                          onChange={(e) => onMetricChange(goal.id, metricId, parseFloat(e.target.value) || 0)}
                          placeholder={metric.target?.toString() || ''}
                          className="w-16 text-sm font-semibold text-pool-dark bg-white/80 rounded-lg px-2 py-1 text-center
                            border border-pool-light/50 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none transition-all"
                        />
                        <span className="text-xs text-pool-mid">{metric.unit}</span>
                        {metric.previousBest && (
                          <span className="text-xs text-pool-mid/60">({metric.previousBest} best)</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {/* Goal Notes */}
                {onNotesChange && (
                  <details className="bg-gray-50/50 rounded-xl border border-gray-200/50" open={!!goal.notes}>
                    <summary className="p-3 cursor-pointer text-sm font-bold text-gray-700 flex items-center gap-2.5 hover:bg-gray-100/80 rounded-xl transition-colors">
                      <div className="w-7 h-7 rounded-lg bg-gray-200/50 flex items-center justify-center">
                        <MessageCircle className="w-4 h-4 text-gray-600" />
                      </div>
                      My Notes
                      {goal.notes && (
                        <span className="text-xs font-semibold text-emerald-600 bg-emerald-100 px-2 py-0.5 rounded-lg">
                          has notes
                        </span>
                      )}
                      <span className="text-xs text-gray-400 ml-auto font-normal">Click to expand</span>
                    </summary>
                    <div className="p-3 pt-2">
                      <textarea
                        value={goal.notes || ''}
                        onChange={(e) => onNotesChange(goal.id, e.target.value)}
                        placeholder="What did you notice? How did it feel?"
                        rows={2}
                        className="w-full text-sm text-pool-dark bg-white/80 rounded-lg px-3 py-2 resize-none
                          border border-gray-200/50 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none transition-all"
                      />
                    </div>
                  </details>
                )}
              </div>

              {/* Actions sidebar */}
              <div className="flex flex-col gap-2">
                {/* Status dropdown */}
                {onStatusChange && (
                  <select
                    value={goal.status}
                    onChange={(e) => onStatusChange(goal.id, e.target.value as GoalStatus)}
                    className="text-sm font-semibold text-pool-dark bg-pool-surface/80 rounded-xl px-3 py-2.5
                      border border-pool-light/50 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none
                      transition-all cursor-pointer hover:bg-white/90 flex items-center gap-2"
                  >
                    <option value="pending">Ready</option>
                    <option value="in_progress">Swimming</option>
                    <option value="completed">Done</option>
                    <option value="abandoned">Skip</option>
                  </select>
                )}
                {/* Delete button */}
                {onDelete && (
                  <button
                    onClick={() => onDelete(goal.id)}
                    className="text-sm text-gray-400 hover:text-red-500 transition-colors font-medium px-3 py-2
                      rounded-xl hover:bg-red-50 flex items-center gap-1.5 border border-transparent hover:border-red-200"
                  >
                    <X className="w-4 h-4" />
                    Remove
                  </button>
                )}
              </div>
            </div>

            {/* Bottom progress line */}
            <div className="absolute bottom-0 left-8 right-8 h-2 bg-gray-200/50 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-pool-light to-pool-deep transition-all duration-500"
                style={{
                  width: goal.status === 'completed' ? '100%' : goal.status === 'in_progress' ? '50%' : '0%'
                }}
              />
            </div>
          </li>
        );
      })}
    </ul>
  );
}