'use client';

import { useState, useEffect, useRef } from 'react';
import { TechniqueTreeNode, MetricValue, ParsedTechniqueContent } from '@/lib/types';
import { RefreshCw, Plus, X, Sparkles, Loader2, ChevronDown, ChevronUp, Edit3, Check, Save, Target, Lightbulb, AlertTriangle, Dumbbell, ChevronLeft, ChevronRight } from 'lucide-react';

interface NodeDetailPanelProps {
  node: TechniqueTreeNode | null;
  strokeId: string;
  onConfirm: (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string }) => void;
  onClose: () => void;
  onExpandNode?: (nodeId: string, coachingTips: string) => void;
  onAddCustomNode?: (parentNode: TechniqueTreeNode) => void;
  onUpdateNode?: (node: TechniqueTreeNode) => void;
  onNavigateNode?: (filename: string) => void;
}

type TabType = 'overview' | 'keyPoints' | 'mistakes' | 'drills';

export function NodeDetailPanel({
  node,
  strokeId,
  onConfirm,
  onClose,
  onExpandNode,
  onAddCustomNode,
  onUpdateNode,
  onNavigateNode
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

  const tabs: { id: TabType; label: string; icon: React.ReactNode; hasContent: boolean }[] = [
    { id: 'overview', label: 'Overview', icon: <Sparkles className="w-4 h-4" />, hasContent: true },
    { id: 'keyPoints', label: 'Key Points', icon: <Lightbulb className="w-4 h-4" />, hasContent: !!markdownContent?.keyPoints?.length },
    { id: 'mistakes', label: 'Mistakes', icon: <AlertTriangle className="w-4 h-4" />, hasContent: !!markdownContent?.commonMistakes?.length },
    { id: 'drills', label: 'Drills', icon: <Dumbbell className="w-4 h-4" />, hasContent: !!markdownContent?.competitiveDrills?.length || !!markdownContent?.specificDrills?.length },
  ];

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
        {!isEditing && node.revisit && (
          <span className="px-3 py-1.5 rounded-lg text-sm font-semibold bg-amber-100 text-amber-700 border border-amber-200 flex items-center gap-1.5">
            <RefreshCw className="w-3.5 h-3.5" />
            Revisit
          </span>
        )}
        {!isEditing && onUpdateNode && (
          <button
            onClick={handleStartEdit}
            className="px-3 py-1.5 rounded-lg text-sm font-semibold bg-pool-surface text-pool-dark border border-pool-light/50
              hover:bg-pool-light/50 transition-colors flex items-center gap-1.5"
          >
            <Edit3 className="w-3.5 h-3.5" />
            Edit
          </button>
        )}
      </div>

      {/* Navigation buttons */}
      {markdownContent && (markdownContent.prevFile || markdownContent.nextFile) && (
        <div className="flex gap-2 mb-3">
          <button
            onClick={handleNavigatePrev}
            disabled={!markdownContent.prevFile || !onNavigateNode}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium bg-pool-surface text-pool-dark border border-pool-light/30
              hover:bg-pool-light/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <ChevronLeft className="w-4 h-4" />
            Prev
          </button>
          <button
            onClick={handleNavigateNext}
            disabled={!markdownContent.nextFile || !onNavigateNode}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium bg-pool-surface text-pool-dark border border-pool-light/30
              hover:bg-pool-light/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Next
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Name - Editable */}
      {isEditing ? (
        <div className="mb-2">
          <label className="block text-xs font-semibold text-pool-mid mb-1">Name</label>
          <input
            type="text"
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
            className="w-full rounded-xl border border-pool-mid/30 px-3 py-2 text-lg font-bold text-pool-dark
              bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none"
          />
        </div>
      ) : (
        <h3 className="text-xl font-bold text-pool-dark mb-2">{node.name}</h3>
      )}

      {/* Description - Editable */}
      {isEditing ? (
        <div className="mb-4">
          <label className="block text-xs font-semibold text-pool-mid mb-1">Description</label>
          <textarea
            value={editDescription}
            onChange={(e) => setEditDescription(e.target.value)}
            rows={3}
            className="w-full rounded-xl border border-pool-mid/30 px-3 py-2 text-sm text-pool-dark
              bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none resize-none"
          />
        </div>
      ) : (
        <p className="text-pool-mid mb-4">{node.description}</p>
      )}

      {/* Revisit toggle in edit mode */}
      {isEditing && (
        <div className="flex items-center gap-3 mb-4">
          <input
            type="checkbox"
            id="editRevisit"
            checked={editRevisit}
            onChange={(e) => setEditRevisit(e.target.checked)}
            className="w-5 h-5 rounded border-pool-mid/30 text-pool-mid focus:ring-pool-mid/20"
          />
          <label htmlFor="editRevisit" className="text-sm font-medium text-pool-dark">
            Mark as revisit (needs regular practice)
          </label>
        </div>
      )}

      {/* Edit Save/Cancel buttons */}
      {isEditing && (
        <div className="flex gap-2 mb-4">
          <button
            onClick={handleSaveEdit}
            disabled={!editName.trim()}
            className="flex-1 flex items-center justify-center gap-2 bg-pool-mid text-white rounded-xl px-4 py-2
              font-semibold hover:bg-pool-deep transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Save className="w-4 h-4" />
            Save Changes
          </button>
          <button
            onClick={handleCancelEdit}
            className="flex items-center justify-center gap-2 bg-pool-surface text-pool-dark rounded-xl px-4 py-2
              font-semibold hover:bg-pool-light/50 transition-colors border border-pool-light/50"
          >
            <X className="w-4 h-4" />
            Cancel
          </button>
        </div>
      )}

      {/* Tabs */}
      {node.sourceFile && (
        <div className="flex gap-1 mb-4 border-b border-pool-light/30">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              disabled={!tab.hasContent && tab.id !== 'overview'}
              className={`flex items-center gap-1.5 px-3 py-2 text-sm font-medium transition-colors rounded-t-lg
                ${activeTab === tab.id
                  ? 'bg-pool-mid/10 text-pool-dark border-b-2 border-pool-mid'
                  : 'text-pool-mid hover:text-pool-dark hover:bg-pool-light/30'
                }
                ${!tab.hasContent && tab.id !== 'overview' ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              {tab.icon}
              {tab.label}
            </button>
          ))}
        </div>
      )}

      {/* Tab Content */}
      {loadingMarkdown && activeTab !== 'overview' && (
        <div className="flex items-center gap-2 mb-4">
          <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
          <span className="text-pool-mid">Loading content...</span>
        </div>
      )}

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <div className="mb-4">
          <details className="bg-gradient-to-r from-blue-50/80 to-pool-surface/50 rounded-xl border border-blue-100">
            <summary className="p-3 cursor-pointer text-sm font-bold text-pool-dark flex items-center gap-2.5 hover:bg-blue-50 rounded-xl transition-colors">
              <div className="w-7 h-7 rounded-lg bg-blue-100 flex items-center justify-center">
                <Sparkles className="w-4 h-4 text-blue-600" />
              </div>
              Coach&apos;s Key Focus Points
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
                className="ml-2 text-xs text-pool-deep hover:text-accent disabled:text-pool-mid/50 flex items-center gap-1 font-medium transition-colors"
                title="Refresh tips"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${loadingTips ? 'animate-spin' : ''}`} />
                Refresh
              </button>
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
      )}

      {/* Key Points Tab */}
      {activeTab === 'keyPoints' && markdownContent?.keyPoints && (
        <div className="mb-4 space-y-2">
          {markdownContent.keyPoints.map((point, idx) => (
            <div key={idx} className="flex items-start gap-2 bg-emerald-50/50 p-3 rounded-lg border border-emerald-100">
              <Lightbulb className="w-4 h-4 text-emerald-600 mt-0.5 shrink-0" />
              <p className="text-sm text-pool-dark">{point}</p>
            </div>
          ))}
        </div>
      )}

      {/* Mistakes Tab */}
      {activeTab === 'mistakes' && markdownContent?.commonMistakes && (
        <div className="mb-4 space-y-2">
          {markdownContent.commonMistakes.map((mistake, idx) => (
            <div key={idx} className="flex items-start gap-2 bg-amber-50/50 p-3 rounded-lg border border-amber-100">
              <AlertTriangle className="w-4 h-4 text-amber-600 mt-0.5 shrink-0" />
              <p className="text-sm text-pool-dark">{mistake}</p>
            </div>
          ))}
        </div>
      )}

      {/* Drills Tab */}
      {activeTab === 'drills' && markdownContent && (
        <div className="mb-4 space-y-4">
          {/* Specific Drills */}
          {markdownContent.specificDrills && markdownContent.specificDrills.length > 0 && (
            <div>
              <h4 className="text-sm font-bold text-pool-dark mb-2 flex items-center gap-2">
                <Dumbbell className="w-4 h-4" />
                Basic Drills
              </h4>
              <div className="bg-pool-surface/50 rounded-lg border border-pool-light/30 overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-pool-light/30">
                      <th className="px-3 py-2 text-left font-semibold text-pool-dark">Drill</th>
                      <th className="px-3 py-2 text-left font-semibold text-pool-dark">Description</th>
                    </tr>
                  </thead>
                  <tbody>
                    {markdownContent.specificDrills.map((drill, idx) => (
                      <tr key={idx} className="border-t border-pool-light/20">
                        <td className="px-3 py-2 font-medium text-pool-dark">{drill.name}</td>
                        <td className="px-3 py-2 text-pool-mid">{drill.description}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Competitive Drills with Tiered Targets */}
          {markdownContent.competitiveDrills && markdownContent.competitiveDrills.length > 0 && (
            <div>
              <h4 className="text-sm font-bold text-pool-dark mb-2 flex items-center gap-2">
                <Target className="w-4 h-4" />
                Competitive Drills (with Tiered Targets)
              </h4>
              <div className="space-y-3">
                {markdownContent.competitiveDrills.map((drill, idx) => (
                  <div key={idx} className="bg-blue-50/30 rounded-lg border border-blue-100 p-3">
                    <h5 className="font-semibold text-pool-dark mb-2">{drill.name}</h5>
                    {drill.selfCheck && (
                      <p className="text-xs text-pool-mid mb-2">
                        <strong>Self-Check:</strong> {drill.selfCheck}
                      </p>
                    )}

                    {/* Tiered Targets with Goal Creation */}
                    <div className="bg-white/80 rounded-lg p-2 mb-2">
                      <p className="text-xs font-semibold text-pool-dark mb-1">Tiered Targets:</p>
                      <div className="space-y-1">
                        {(['beginner', 'intermediate', 'advanced', 'elite'] as const).map(tier => (
                          drill.tieredTargets[tier] && (
                            <div key={tier} className="flex items-center justify-between gap-2">
                              <span className="text-xs text-pool-mid">
                                <strong className="capitalize text-pool-dark">{tier}:</strong> {drill.tieredTargets[tier]}
                              </span>
                              <button
                                onClick={() => handleCreateGoalFromTier(drill.name, tier, drill.tieredTargets[tier])}
                                className="text-xs px-2 py-1 bg-pool-mid/20 text-pool-dark rounded hover:bg-pool-mid/30 transition-colors flex items-center gap-1"
                              >
                                <Plus className="w-3 h-3" />
                                Add Goal
                              </button>
                            </div>
                          )
                        ))}
                      </div>
                    </div>

                    {drill.videoChecks && drill.videoChecks.length > 0 && (
                      <div className="text-xs text-pool-mid">
                        <strong>Video Check:</strong>
                        <ul className="list-disc list-inside mt-1">
                          {drill.videoChecks.map((check, i) => (
                            <li key={i}>{check}</li>
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

      {/* Expand Node Button */}
      {onExpandNode && coachingTips && !loadingTips && activeTab === 'overview' && (
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
      {onAddCustomNode && activeTab === 'overview' && (
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
      {node.metrics && node.metrics.length > 0 && activeTab === 'overview' && (
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
      {node.prerequisites.length > 0 && activeTab === 'overview' && (
        <div className="mb-4">
          <h4 className="text-sm font-bold text-pool-dark mb-1">Prerequisites</h4>
          <p className="text-xs text-pool-mid">
            Complete these before attempting: {node.prerequisites.join(', ')}
          </p>
        </div>
      )}

      {/* Confirm Button */}
      {activeTab === 'overview' && (
        <button
          onClick={() => handleConfirm()}
          className="mt-auto flex items-center justify-center gap-2 bg-pool-mid text-white rounded-xl px-6 py-3
            font-semibold hover:bg-pool-deep transition-colors shadow-lg shadow-pool-mid/20"
        >
          <Plus className="w-4 h-4" />
          Add as Today&apos;s Goal
        </button>
      )}
    </div>
  );
}