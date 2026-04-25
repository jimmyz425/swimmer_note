'use client';

import { useState, useEffect, useRef } from 'react';
import { TechniqueTreeNode, MetricValue, ParsedTechniqueContent } from '@/lib/types';
import { RefreshCw, Plus, X, Sparkles, Loader2, Edit3, Save, Target, ChevronLeft, ChevronRight } from 'lucide-react';

interface NodeDetailPanelProps {
  node: TechniqueTreeNode | null;
  strokeId: string;
  onConfirm: (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string }) => void;
  onClose: () => void;
  onExpandNode?: (nodeId: string, coachingTips: string) => void;
  onAddCustomNode?: (parentNode: TechniqueTreeNode) => void;
  onUpdateNode?: (node: TechniqueTreeNode) => void;
  onNavigateNode?: (filename: string) => void;
  expanded?: boolean;
}

type TabType = 'overview' | 'keyPoints' | 'mistakes' | 'drills';

const tierColors: Record<string, string> = {
  beginner: 'bg-emerald-50 border-emerald-200 text-emerald-700',
  intermediate: 'bg-blue-50 border-blue-200 text-blue-700',
  advanced: 'bg-purple-50 border-purple-200 text-purple-700',
  elite: 'bg-amber-50 border-amber-200 text-amber-700',
};

const tierBadgeColors: Record<string, string> = {
  beginner: 'bg-emerald-100 text-emerald-600',
  intermediate: 'bg-blue-100 text-blue-600',
  advanced: 'bg-purple-100 text-purple-600',
  elite: 'bg-amber-100 text-amber-600',
};

export function NodeDetailPanel({
  node,
  strokeId,
  onConfirm,
  onClose,
  onExpandNode,
  onAddCustomNode,
  onUpdateNode,
  onNavigateNode,
  expanded = false
}: NodeDetailPanelProps) {
  const [activeTab, setActiveTab] = useState<TabType>('overview');
  const [metrics, setMetrics] = useState<Record<string, { actual: number; unit: string }>>({});
  const [coachingTips, setCoachingTips] = useState<string | null>(null);
  const [loadingTips, setLoadingTips] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState('');
  const [editDescription, setEditDescription] = useState('');
  const [editRevisit, setEditRevisit] = useState(false);

  // Markdown content state
  const [markdownContent, setMarkdownContent] = useState<ParsedTechniqueContent | null>(null);
  const [loadingMarkdown, setLoadingMarkdown] = useState(false);

  // Cache tips by node ID to avoid re-fetching
  const tipsCacheRef = useRef<Record<string, string>>({});
  const markdownCacheRef = useRef<Record<string, ParsedTechniqueContent>>({});

  // Fetch coaching tips and markdown content when node changes
  useEffect(() => {
    if (node) {
      setIsEditing(false);
      setEditName(node.name);
      setEditDescription(node.description);
      setEditRevisit(node.revisit);
      setActiveTab('overview');

      // Fetch coaching tips
      if (tipsCacheRef.current[node.id]) {
        setCoachingTips(tipsCacheRef.current[node.id]);
        setLoadingTips(false);
      } else {
        setLoadingTips(true);
        setCoachingTips(null);

        fetch('/api/coaching', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ node }),
        })
          .then(res => res.json())
          .then(data => {
            setCoachingTips(data.tips);
            tipsCacheRef.current[node.id] = data.tips;
          })
          .catch(err => {
            console.error('Failed to fetch coaching tips:', err);
            setCoachingTips('Failed to load coaching tips');
          })
          .finally(() => setLoadingTips(false));
      }

      // Fetch markdown content if sourceFile exists
      if (node.sourceFile) {
        const sourceFile = node.sourceFile;
        if (markdownCacheRef.current[sourceFile]) {
          setMarkdownContent(markdownCacheRef.current[sourceFile]);
          setLoadingMarkdown(false);
        } else {
          setLoadingMarkdown(true);
          setMarkdownContent(null);

          fetch(`/api/markdown/${strokeId}/${sourceFile}`)
            .then(res => res.json())
            .then(data => {
              setMarkdownContent(data);
              markdownCacheRef.current[sourceFile] = data;
            })
            .catch(err => {
              console.error('Failed to fetch markdown:', err);
              setMarkdownContent(null);
            })
            .finally(() => setLoadingMarkdown(false));
        }
      } else {
        setMarkdownContent(null);
        setLoadingMarkdown(false);
      }
    } else {
      setCoachingTips(null);
      setMarkdownContent(null);
      setIsEditing(false);
    }
  }, [node, strokeId]);

  if (!node) {
    return (
      <div className="glass-card rounded-2xl h-full flex flex-col items-center justify-center text-center p-8">
        <div className="w-20 h-20 rounded-full bg-gradient-to-br from-pool-mid/20 to-pool-light/30 flex items-center justify-center mb-4">
          <ChevronRight className="w-10 h-10 text-pool-mid/60" />
        </div>
        <p className="text-pool-mid font-medium text-sm">
          Select a technique node
        </p>
        <p className="text-pool-mid/60 text-xs mt-1">
          Click any node in the flowchart to view details
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

  const handleConfirm = (goalFromTier?: { drillName: string; tier: string; target: string }) => {
    const metricValues: Record<string, MetricValue> = {};
    for (const [id, val] of Object.entries(metrics)) {
      metricValues[id] = { actual: val.actual, unit: val.unit };
    }
    onConfirm(node, metricValues, coachingTips || undefined, goalFromTier);
  };

  const handleCreateGoalFromTier = (drillName: string, tier: string, target: string) => {
    handleConfirm({ drillName, tier, target });
  };

  const handleStartEdit = () => {
    setEditName(node.name);
    setEditDescription(node.description);
    setEditRevisit(node.revisit);
    setIsEditing(true);
  };

  const handleSaveEdit = () => {
    if (!onUpdateNode || !editName.trim()) return;
    const updatedNode: TechniqueTreeNode = {
      ...node,
      name: editName.trim(),
      description: editDescription.trim(),
      revisit: editRevisit,
    };
    onUpdateNode(updatedNode);
    setIsEditing(false);
  };

  const handleCancelEdit = () => {
    setEditName(node.name);
    setEditDescription(node.description);
    setEditRevisit(node.revisit);
    setIsEditing(false);
  };

  const levelGradients = [
    'from-emerald-400 to-emerald-500',
    'from-cyan-400 to-cyan-500',
    'from-amber-400 to-amber-500',
    'from-orange-400 to-orange-500',
    'from-purple-400 to-purple-500',
    'from-pink-400 to-pink-500',
    'from-indigo-400 to-indigo-500',
    'from-red-400 to-red-500',
  ];

  const levelGradient = levelGradients[Math.min(node.level - 1, levelGradients.length - 1)];

  const handleExpandNode = async () => {
    if (!onExpandNode || !coachingTips) return;
    onExpandNode(node.id, coachingTips);
  };

  const handleNavigatePrev = () => {
    if (markdownContent?.prevFile && onNavigateNode) {
      onNavigateNode(markdownContent.prevFile);
    }
  };

  const handleNavigateNext = () => {
    if (markdownContent?.nextFile && onNavigateNode) {
      onNavigateNode(markdownContent.nextFile);
    }
  };

  const tabs: { id: TabType; label: string; hasContent: boolean }[] = [
    { id: 'overview', label: 'Overview', hasContent: true },
    { id: 'keyPoints', label: 'Key Points', hasContent: !!markdownContent?.keyPoints?.length },
    { id: 'mistakes', label: 'Mistakes', hasContent: !!markdownContent?.commonMistakes?.length },
    { id: 'drills', label: 'Drills', hasContent: !!markdownContent?.competitiveDrills?.length || !!markdownContent?.specificDrills?.length },
  ];

  return (
    <div className="glass-card rounded-2xl h-full flex flex-col overflow-hidden">
      {/* Header Section - Fixed */}
      <div className="p-4 pb-0 space-y-3">
        {/* Top row: Close + Navigation */}
        <div className="flex items-center justify-between">
          <button onClick={onClose} className="p-2 rounded-lg text-pool-mid hover:text-pool-deep hover:bg-pool-light/30 transition-all">
            <X className="w-4 h-4" />
          </button>

          {/* Navigation buttons */}
          {markdownContent && (markdownContent.prevFile || markdownContent.nextFile) && (
            <div className="flex gap-1">
              <button
                onClick={handleNavigatePrev}
                disabled={!markdownContent.prevFile}
                className="p-1.5 rounded-md text-pool-mid hover:text-pool-dark hover:bg-pool-light/30 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                onClick={handleNavigateNext}
                disabled={!markdownContent.nextFile}
                className="p-1.5 rounded-md text-pool-mid hover:text-pool-dark hover:bg-pool-light/30 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>

        {/* Level Badge + Meta */}
        <div className="flex items-center gap-2 flex-wrap">
          <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold text-white bg-gradient-to-r ${levelGradient} shadow-sm`}>
            Lv.{node.level}
          </span>
          {!isEditing && node.revisit && (
            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
              <RefreshCw className="w-3 h-3" />
              Revisit
            </span>
          )}
          {!isEditing && onUpdateNode && (
            <button
              onClick={handleStartEdit}
              className="p-1.5 rounded-md text-pool-mid hover:text-pool-dark hover:bg-pool-light/30 transition-all"
            >
              <Edit3 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        {/* Title */}
        {isEditing ? (
          <input
            type="text"
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
            className="w-full rounded-lg border border-pool-mid/30 px-3 py-1.5 text-lg font-bold text-pool-dark bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none"
          />
        ) : (
          <h3 className="text-lg font-bold text-pool-dark leading-tight">{node.name}</h3>
        )}

        {/* Description */}
        {isEditing ? (
          <textarea
            value={editDescription}
            onChange={(e) => setEditDescription(e.target.value)}
            rows={2}
            className="w-full rounded-lg border border-pool-mid/30 px-3 py-1.5 text-sm text-pool-dark bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none resize-none"
          />
        ) : (
          <p className="text-sm text-pool-mid leading-relaxed">{node.description}</p>
        )}

        {/* Edit controls */}
        {isEditing && (
          <div className="flex items-center gap-3">
            <input
              type="checkbox"
              id="editRevisit"
              checked={editRevisit}
              onChange={(e) => setEditRevisit(e.target.checked)}
              className="w-4 h-4 rounded border-pool-mid/30"
            />
            <label htmlFor="editRevisit" className="text-xs text-pool-dark">Revisit</label>
            <div className="flex-1 flex gap-2 justify-end">
              <button onClick={handleCancelEdit} className="px-3 py-1 text-xs font-medium text-pool-mid hover:text-pool-dark">Cancel</button>
              <button onClick={handleSaveEdit} disabled={!editName.trim()} className="px-3 py-1 text-xs font-semibold bg-pool-mid text-white rounded-lg hover:bg-pool-deep disabled:opacity-50">
                <Save className="w-3 h-3 inline mr-1" />Save
              </button>
            </div>
          </div>
        )}

        {/* Pill Tabs */}
        {node.sourceFile && (
          <div className="flex gap-1 p-1 bg-pool-surface/60 rounded-lg">
            {tabs.map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                disabled={!tab.hasContent && tab.id !== 'overview'}
                className={`flex-1 px-2 py-1 rounded-md text-xs font-medium transition-all
                  ${activeTab === tab.id
                    ? 'bg-pool-mid text-white shadow-sm'
                    : 'text-pool-mid hover:text-pool-dark hover:bg-pool-light/40'
                  }
                  ${!tab.hasContent && tab.id !== 'overview' ? 'opacity-40 cursor-not-allowed' : ''}`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Scrollable Content Area */}
      <div className="flex-1 overflow-y-auto px-4 pb-4 space-y-3">
        {loadingMarkdown && activeTab !== 'overview' && (
          <div className="flex items-center gap-2 py-4">
            <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
            <span className="text-sm text-pool-mid">Loading...</span>
          </div>
        )}

        {/* Overview Tab */}
        {activeTab === 'overview' && (
          <>
            {/* Coaching Tips */}
            <details className="group bg-gradient-to-br from-blue-50/80 to-white rounded-xl border border-blue-100/60 overflow-hidden" open>
              <summary className="flex items-center gap-2 p-3 cursor-pointer hover:bg-blue-50/50 transition-colors list-none">
                <div className="w-6 h-6 rounded-md bg-blue-100 flex items-center justify-center">
                  <Sparkles className="w-3.5 h-3.5 text-blue-600" />
                </div>
                <span className="text-sm font-semibold text-pool-dark flex-1">Coach Tips</span>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (node) {
                      tipsCacheRef.current[node.id] = '';
                      setLoadingTips(true);
                      fetch('/api/coaching', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ node }),
                      })
                        .then(res => res.json())
                        .then(data => {
                          setCoachingTips(data.tips);
                          tipsCacheRef.current[node.id] = data.tips;
                        })
                        .catch(err => console.error('Failed to refresh tips:', err))
                        .finally(() => setLoadingTips(false));
                    }
                  }}
                  disabled={loadingTips}
                  className="p-1 rounded text-pool-mid hover:text-pool-deep disabled:opacity-50"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${loadingTips ? 'animate-spin' : ''}`} />
                </button>
                <ChevronRight className="w-4 h-4 text-pool-mid group-open:rotate-90 transition-transform" />
              </summary>
              <div className="px-3 pb-3 pt-0 text-sm text-pool-dark whitespace-pre-line border-t border-blue-100/50">
                {loadingTips ? (
                  <div className="flex items-center gap-2 py-2">
                    <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
                    <span className="text-pool-mid">Loading...</span>
                  </div>
                ) : coachingTips ? (
                  <div className="py-2">{coachingTips}</div>
                ) : (
                  <span className="text-pool-mid py-2">Tips not available</span>
                )}
              </div>
            </details>

            {/* Quick Actions */}
            {onExpandNode && coachingTips && !loadingTips && (
              <button
                onClick={handleExpandNode}
                className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium text-pool-deep bg-pool-mid/10 hover:bg-pool-mid/20 transition-colors"
              >
                <RefreshCw className="w-4 h-4" />
                Expand with LLM
              </button>
            )}

            {onAddCustomNode && (
              <button
                onClick={() => onAddCustomNode(node)}
                className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium text-pool-dark bg-pool-light/30 hover:bg-pool-light/50 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Add Custom Sub-Node
              </button>
            )}

            {/* Metrics */}
            {node.metrics && node.metrics.length > 0 && (
              <div className="space-y-2">
                <h4 className="text-xs font-semibold text-pool-mid uppercase tracking-wide">Metrics</h4>
                {node.metrics.map(metric => (
                  <div key={metric.id} className="flex items-center gap-2 bg-pool-surface/40 px-3 py-2 rounded-lg">
                    <label className="text-sm text-pool-dark flex-1">{metric.name}</label>
                    <input
                      type="number"
                      value={metrics[metric.id]?.actual ?? ''}
                      onChange={(e) => handleMetricChange(metric.id, parseFloat(e.target.value) || 0)}
                      placeholder="0"
                      className="w-16 rounded-md border border-pool-light/40 px-2 py-1 text-sm text-pool-dark bg-white text-center"
                    />
                    <span className="text-xs text-pool-mid">{metric.unit}</span>
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        {/* Key Points Tab */}
        {activeTab === 'keyPoints' && markdownContent?.keyPoints && (
          <div className="space-y-2">
            {markdownContent.keyPoints.map((point, idx) => (
              <div key={idx} className="flex items-start gap-2.5 p-3 rounded-lg bg-emerald-50/60 border border-emerald-100/60">
                <div className="w-5 h-5 rounded-md bg-emerald-100 flex items-center justify-center shrink-0 mt-0.5">
                  <span className="text-xs font-bold text-emerald-600">{idx + 1}</span>
                </div>
                <p className="text-sm text-pool-dark leading-relaxed">{point.replace(/\*\*/g, '')}</p>
              </div>
            ))}
          </div>
        )}

        {/* Mistakes Tab */}
        {activeTab === 'mistakes' && markdownContent?.commonMistakes && (
          <div className="space-y-2">
            {markdownContent.commonMistakes.map((mistake, idx) => (
              <div key={idx} className="flex items-start gap-2.5 p-3 rounded-lg bg-amber-50/60 border border-amber-100/60">
                <div className="w-5 h-5 rounded-md bg-amber-100 flex items-center justify-center shrink-0 mt-0.5">
                  <span className="text-xs font-bold text-amber-600">!</span>
                </div>
                <p className="text-sm text-pool-dark leading-relaxed">{mistake}</p>
              </div>
            ))}
          </div>
        )}

        {/* Drills Tab */}
        {activeTab === 'drills' && markdownContent && (
          <div className="space-y-4">
            {/* Basic Drills */}
            {markdownContent.specificDrills && markdownContent.specificDrills.length > 0 && (
              <div>
                <h4 className="text-xs font-semibold text-pool-mid uppercase tracking-wide mb-2">Basic Drills</h4>
                <div className="space-y-2">
                  {markdownContent.specificDrills.map((drill, idx) => (
                    <div key={idx} className="p-3 rounded-lg bg-white/60 border border-pool-light/30 hover:border-pool-mid/30 transition-colors">
                      <p className="text-sm font-medium text-pool-dark">{drill.name.replace(/\*\*/g, '')}</p>
                      <p className="text-xs text-pool-mid mt-1 leading-relaxed">{drill.description}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Competitive Drills */}
            {markdownContent.competitiveDrills && markdownContent.competitiveDrills.length > 0 && (
              <div>
                <h4 className="text-xs font-semibold text-pool-mid uppercase tracking-wide mb-2 flex items-center gap-1.5">
                  <Target className="w-3.5 h-3.5" />
                  Competitive Drills
                </h4>
                <div className="space-y-3">
                  {markdownContent.competitiveDrills.map((drill, idx) => (
                    <div key={idx} className="rounded-xl border border-blue-100/60 bg-gradient-to-br from-blue-50/40 to-white overflow-hidden">
                      {/* Drill Header */}
                      <div className="px-3 py-2 bg-blue-100/30 border-b border-blue-100/40">
                        <h5 className="text-sm font-semibold text-pool-dark">{drill.name}</h5>
                        {drill.selfCheck && (
                          <p className="text-xs text-blue-600 mt-0.5">{drill.selfCheck}</p>
                        )}
                      </div>

                      {/* Tier Grid - 2 columns when expanded, 1 when not */}
                      <div className={`p-2 grid gap-1.5 ${expanded ? 'grid-cols-2' : 'grid-cols-1'}`}>
                        {(['beginner', 'intermediate', 'advanced', 'elite'] as const).map(tier => (
                          drill.tieredTargets[tier] && (
                            <div key={tier} className={`group relative p-2 rounded-lg border ${tierColors[tier]} hover:shadow-sm transition-all`}>
                              <span className={`inline-block px-1.5 py-0.5 rounded text-xs font-semibold uppercase ${tierBadgeColors[tier]}`}>
                                {tier}
                              </span>
                              <p className="text-xs mt-1 leading-snug">{drill.tieredTargets[tier]}</p>
                              <button
                                onClick={() => handleCreateGoalFromTier(drill.name, tier, drill.tieredTargets[tier])}
                                className="absolute top-1 right-1 opacity-0 group-hover:opacity-100 transition-opacity p-1 bg-white/80 rounded hover:bg-white shadow-sm"
                                title="Add as goal"
                              >
                                <Plus className="w-3 h-3" />
                              </button>
                            </div>
                          )
                        ))}
                      </div>

                      {/* Video Checks */}
                      {drill.videoChecks && drill.videoChecks.length > 0 && (
                        <div className="px-3 py-2 border-t border-blue-100/40">
                          <p className="text-xs font-medium text-pool-mid mb-1">Video Check:</p>
                          <ul className="text-xs text-pool-mid space-y-0.5">
                            {drill.videoChecks.map((check, i) => (
                              <li key={i} className="flex items-start gap-1">
                                <span className="text-blue-400">•</span>
                                <span>{check}</span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Fixed Footer - Add Goal Button */}
      {activeTab === 'overview' && (
        <div className="p-4 pt-0">
          <button
            onClick={() => handleConfirm()}
            className="w-full flex items-center justify-center gap-2 bg-gradient-to-r from-pool-mid to-pool-deep text-white rounded-xl px-4 py-2.5
              font-semibold hover:from-pool-deep hover:to-pool-darker transition-all shadow-lg shadow-pool-mid/20"
          >
            <Plus className="w-4 h-4" />
            Add as Today&apos;s Goal
          </button>
        </div>
      )}
    </div>
  );
}