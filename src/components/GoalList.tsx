'use client';

import { useState } from 'react';
import { Goal, GoalStatus } from '@/lib/types';
import {
  Clock,
  Activity,
  CheckCircle2,
  SkipForward,
  Sparkles,
  MessageCircle,
  Target,
  Timer,
  ChevronDown,
  ChevronUp,
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
  const [expandedGoals, setExpandedGoals] = useState<Set<string>>(new Set());

  const toggleExpand = (goalId: string) => {
    setExpandedGoals(prev => {
      const next = new Set(prev);
      if (next.has(goalId)) {
        next.delete(goalId);
      } else {
        next.add(goalId);
      }
      return next;
    });
  };

  const statusStyles: Record<GoalStatus | 'pending', { bg: string; text: string; icon: React.ReactNode; ring: string }> = {
    pending: {
      bg: 'status-planned',
      text: 'text-pool-dark',
      icon: <Clock className="w-4 h-4" />,
      ring: 'ring-pool-mid',
    },
    planned: {
      bg: 'status-planned',
      text: 'text-pool-dark',
      icon: <Clock className="w-4 h-4" />,
      ring: 'ring-pool-mid',
    },
    in_progress: {
      bg: 'status-progress',
      text: 'text-white',
      icon: <Activity className="w-4 h-4" />,
      ring: 'ring-lane-red',
    },
    achieved: {
      bg: 'status-achieved',
      text: 'text-amber-900',
      icon: <CheckCircle2 className="w-4 h-4" />,
      ring: 'ring-gold',
    },
    unable_to_achieve: {
      bg: 'status-unable',
      text: 'text-gray-500',
      icon: <SkipForward className="w-4 h-4" />,
      ring: 'ring-gray-300',
    },
  };

  const getStatusLabel = (status: GoalStatus): string => {
    switch (status) {
      case 'planned': return 'PLANNED';
      case 'in_progress': return 'IN PROGRESS';
      case 'achieved': return 'ACHIEVED';
      case 'unable_to_achieve': return 'SKIPPED';
    }
  };

  const getStrokeSource = (goal: Goal): { id: string; name: string; icon: React.ReactNode } | null => {
    if (!goal.strokeId) return null;

    const stroke = strokes.find(s => s.id === goal.strokeId);
    if (!stroke) {
      if (goal.strokeId === 'master') {
        return { id: 'master', name: 'Master', icon: <Sparkles className="w-3.5 h-3.5" /> };
      }
      return { id: goal.strokeId, name: goal.strokeId, icon: <Waves className="w-3.5 h-3.5" /> };
    }

    return { id: stroke.id, name: stroke.name, icon: <Waves className="w-3.5 h-3.5" /> };
  };

  const getNotesPlaceholder = (goal: Goal): string => {
    if (goal.goalKind === 'competitiveMetric') {
      return 'How long, how far, how quick? What was your result?';
    }
    if (goal.goalKind === 'keyPoint') {
      return 'How did you achieve it? What worked well?';
    }
    if (goal.goalKind === 'mistake') {
      return 'What prevented you? How can you avoid it next time?';
    }
    return 'What did you notice? How did it feel?';
  };

  if (goals.length === 0) {
    return (
      <div className="text-center py-12">
        <div className="relative inline-block mb-4">
          <div className="lane-badge w-16 h-16 flex items-center justify-center">
            <Target className="w-8 h-8 text-white" />
          </div>
        </div>
        <p className="font-heading font-bold text-pool-dark text-xl uppercase tracking-wide mb-2">
          NO GOALS SET
        </p>
        <p className="text-sm text-pool-mid font-body">
          Select a stroke above to add goals from the technique tree
        </p>
      </div>
    );
  }

  return (
    <ul className="space-y-3">
      {goals.map((goal, index) => {
        const strokeSource = getStrokeSource(goal);
        const style = statusStyles[goal.status];
        const isExpanded = expandedGoals.has(goal.id);

        return (
          <li
            key={goal.id}
            className="bg-white rounded-xl shadow-sm mb-3 overflow-hidden border border-pool-mid/10"
          >
            {/* Collapsed view - always visible */}
            <div
              className="px-4 py-3 cursor-pointer flex items-center gap-3"
              onClick={() => toggleExpand(goal.id)}
            >
              {/* Status badge */}
              <span className={`${style.bg} text-xs font-heading font-bold px-3 py-1.5 rounded flex items-center gap-1.5 uppercase tracking-wide`}>
                {style.icon}
                {getStatusLabel(goal.status)}
              </span>

              {/* Description */}
              <p className="flex-1 font-body font-semibold text-pool-dark text-sm">
                {goal.description}
              </p>

              {/* Expand indicator */}
              {isExpanded ? (
                <ChevronUp className="w-5 h-5 text-pool-mid" />
              ) : (
                <ChevronDown className="w-5 h-5 text-pool-mid" />
              )}
            </div>

            {/* Expanded details */}
            {isExpanded && (
              <div className="px-4 pb-4 border-t border-pool-mid/10 animate-slide-up">
                {/* Stroke source */}
                {strokeSource && (
                  <div className="flex items-center gap-2 mb-3">
                    <span className={`text-xs font-heading font-bold px-2 py-1 rounded flex items-center gap-1 ${
                      strokeSource.id === 'master'
                        ? 'bg-amber-100 text-amber-700 border border-amber-200'
                        : 'bg-pool-surface text-pool-dark border border-pool-mid/30'
                    }`}>
                      {strokeSource.icon}
                      {strokeSource.name.toUpperCase()}
                    </span>
                    {goal.revisit && (
                      <span className="text-xs font-heading font-bold text-amber-700 bg-amber-100 px-2 py-1 rounded flex items-center gap-1">
                        <Timer className="w-3 h-3" />
                        REVISIT
                      </span>
                    )}
                  </div>
                )}

                {/* Metrics */}
                {goal.metrics && Object.keys(goal.metrics).length > 0 && onMetricChange && (
                  <div className="mb-4 flex flex-wrap gap-3">
                    {Object.entries(goal.metrics).map(([metricId, metric]) => (
                      <div key={metricId} className="flex items-center gap-2 bg-pool-surface px-3 py-2 rounded-lg">
                        <span className="text-xs font-heading font-bold text-pool-mid uppercase">{metricId}:</span>
                        <input
                          type="number"
                          value={metric.actual ?? ''}
                          onChange={(e) => onMetricChange(goal.id, metricId, parseFloat(e.target.value) || 0)}
                          placeholder={metric.target?.toString() || ''}
                          className="w-16 text-sm font-semibold text-pool-dark bg-white rounded px-2 py-1 text-center
                            border border-pool-mid/30 focus:border-accent focus:ring-2 focus:ring-accent/20 outline-none"
                        />
                        <span className="text-xs text-pool-mid">{metric.unit}</span>
                        {metric.previousBest && (
                          <span className="text-xs text-pool-mid/60">(best: {metric.previousBest})</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {/* Notes */}
                {onNotesChange && (
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2">
                      <MessageCircle className="w-4 h-4 text-pool-mid" />
                      <span className="text-xs font-heading font-bold text-pool-mid uppercase">My Notes</span>
                    </div>
                    <textarea
                      value={goal.notes || ''}
                      onChange={(e) => onNotesChange(goal.id, e.target.value)}
                      placeholder={getNotesPlaceholder(goal)}
                      rows={2}
                      className="w-full text-sm text-pool-dark bg-pool-surface rounded-lg px-3 py-2 resize-none font-body
                        border border-pool-mid/20 focus:border-accent focus:ring-2 focus:ring-accent/20 outline-none"
                    />
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center gap-3 pt-2 border-t border-pool-mid/10">
                  {/* Status dropdown */}
                  {onStatusChange && (
                    <select
                      value={goal.status}
                      onChange={(e) => onStatusChange(goal.id, e.target.value as GoalStatus)}
                      className="font-heading font-semibold text-sm text-pool-dark bg-pool-surface rounded px-3 py-2
                        border border-pool-mid/30 focus:border-accent outline-none cursor-pointer uppercase tracking-wide"
                    >
                      <option value="planned">Planned</option>
                      <option value="in_progress">In Progress</option>
                      <option value="achieved">Achieved</option>
                      <option value="unable_to_achieve">Skipped</option>
                    </select>
                  )}

                  {/* Delete button */}
                  {onDelete && (
                    <button
                      onClick={() => onDelete(goal.id)}
                      className="text-sm text-gray-400 hover:text-lane-red transition-colors font-heading font-medium px-3 py-2
                        rounded hover:bg-red-50 flex items-center gap-1.5 uppercase tracking-wide"
                    >
                      <X className="w-4 h-4" />
                      Remove
                    </button>
                  )}
                </div>
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}