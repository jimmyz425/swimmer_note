'use client';

import { useState, useEffect, useRef } from 'react';
import { TechniqueTreeNode, MetricValue, ParsedTechniqueContent } from '@/lib/types';
import { Plus, X, Edit3, Save, Target, ChevronLeft, ChevronRight, GripVertical } from 'lucide-react';

interface NodeDetailPanelProps {
  node: TechniqueTreeNode | null;
  strokeId: string;
  onConfirm: (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string }) => void;
  onClose: () => void;
  onUpdateNode?: (node: TechniqueTreeNode) => void;
  onNavigateNode?: (filename: string) => void;
  expanded?: boolean;
  isMobile?: boolean;
}

type TabType = 'keyPoints' | 'mistakes' | 'drills';

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
  onUpdateNode,
  onNavigateNode,
  expanded = false,
  isMobile = false
}: NodeDetailPanelProps) {
  const [activeTab, setActiveTab] = useState<TabType>('keyPoints');
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState('');
  const [editDescription, setEditDescription] = useState('');

  // Markdown content state
  const [markdownContent, setMarkdownContent] = useState<ParsedTechniqueContent | null>(null);
  const [loadingMarkdown, setLoadingMarkdown] = useState(false);

  // Cache markdown content
  const markdownCacheRef = useRef<Record<string, ParsedTechniqueContent>>({});

  // Fetch markdown content when node changes
  useEffect(() => {
    if (node) {
      setIsEditing(false);
      setEditName(node.name);
      setEditDescription(node.description);
      setActiveTab('keyPoints');

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
      setMarkdownContent(null);
      setIsEditing(false);
    }
  }, [node, strokeId]);

  if (!node) {
    return (
      <div className={`glass-card rounded-2xl h-full flex flex-col items-center justify-center text-center ${isMobile ? 'p-4' : 'p-8'}`}>
        <div className="w-16 h-16 rounded-full bg-gradient-to-br from-pool-mid/20 to-pool-light/30 flex items-center justify-center mb-3">
          <ChevronRight className="w-8 h-8 text-pool-mid/60" />
        </div>
        <p className="text-pool-mid font-medium text-sm">
          Select a technique
        </p>
        {!isMobile && (
          <p className="text-pool-mid/60 text-xs mt-1">
            Click any node in the flowchart to view details
          </p>
        )}
      </div>
    );
  }

  const handleConfirm = (goalFromTier?: { drillName: string; tier: string; target: string }) => {
    onConfirm(node, {}, undefined, goalFromTier);
  };

  const handleCreateGoalFromTier = (drillName: string, tier: string, target: string) => {
    handleConfirm({ drillName, tier, target });
  };

  const handleStartEdit = () => {
    setEditName(node.name);
    setEditDescription(node.description);
    setIsEditing(true);
  };

  const handleSaveEdit = () => {
    if (!onUpdateNode || !editName.trim()) return;
    const updatedNode: TechniqueTreeNode = {
      ...node,
      name: editName.trim(),
      description: editDescription.trim(),
    };
    onUpdateNode(updatedNode);
    setIsEditing(false);
  };

  const handleCancelEdit = () => {
    setEditName(node.name);
    setEditDescription(node.description);
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
    { id: 'keyPoints', label: 'Key Points', hasContent: !!markdownContent?.keyPoints?.length },
    { id: 'mistakes', label: 'Mistakes', hasContent: !!markdownContent?.commonMistakes?.length },
    { id: 'drills', label: 'Drills', hasContent: !!markdownContent?.competitiveDrills?.length || !!markdownContent?.specificDrills?.length },
  ];

  // Mobile layout - full screen card with swipe navigation
  if (isMobile) {
    return (
      <div className="h-full flex flex-col bg-white">
        {/* Pull-down indicator */}
        <div className="flex justify-center pt-2 pb-1">
          <div className="w-12 h-1.5 rounded-full bg-gray-300" />
        </div>

        {/* Header */}
        <div className="px-4 py-2 flex items-center justify-between border-b border-gray-100">
          <button
            onClick={onClose}
            className="p-2 -ml-2 rounded-lg text-gray-500 active:bg-gray-100"
          >
            <X className="w-5 h-5" />
          </button>

          {/* Navigation arrows */}
          {markdownContent && (markdownContent.prevFile || markdownContent.nextFile) && (
            <div className="flex gap-1">
              <button
                onClick={handleNavigatePrev}
                disabled={!markdownContent.prevFile}
                className="p-2 rounded-lg text-gray-500 active:bg-gray-100 disabled:opacity-30"
              >
                <ChevronLeft className="w-5 h-5" />
              </button>
              <button
                onClick={handleNavigateNext}
                disabled={!markdownContent.nextFile}
                className="p-2 rounded-lg text-gray-500 active:bg-gray-100 disabled:opacity-30"
              >
                <ChevronRight className="w-5 h-5" />
              </button>
            </div>
          )}
        </div>

        {/* Level + Title */}
        <div className="px-4 py-3">
          <div className="flex items-center gap-2 mb-2">
            <span className={`inline-flex items-center px-3 py-1.5 rounded-full text-sm font-bold text-white bg-gradient-to-r ${levelGradient}`}>
              Level {node.level}
            </span>
            {!isEditing && onUpdateNode && (
              <button
                onClick={handleStartEdit}
                className="p-2 rounded-lg text-gray-400 active:bg-gray-100"
              >
                <Edit3 className="w-4 h-4" />
              </button>
            )}
          </div>

          {isEditing ? (
            <input
              type="text"
              value={editName}
              onChange={(e) => setEditName(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-xl font-bold bg-white"
            />
          ) : (
            <h3 className="text-xl font-bold text-gray-900 leading-tight">{node.name}</h3>
          )}

          {isEditing ? (
            <textarea
              value={editDescription}
              onChange={(e) => setEditDescription(e.target.value)}
              rows={2}
              className="w-full mt-2 rounded-lg border border-gray-200 px-3 py-2 text-sm text-gray-600 bg-white resize-none"
            />
          ) : (
            <p className="text-sm text-gray-500 mt-1 leading-relaxed">{node.description}</p>
          )}

          {isEditing && (
            <div className="flex gap-2 mt-3 justify-end">
              <button
                onClick={handleCancelEdit}
                className="px-4 py-2 text-sm font-medium text-gray-500 active:bg-gray-100"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveEdit}
                disabled={!editName.trim()}
                className="px-4 py-2 text-sm font-semibold bg-pool-mid text-white rounded-lg active:bg-pool-deep disabled:opacity-50"
              >
                Save
              </button>
            </div>
          )}
        </div>

        {/* Tabs */}
        {node.sourceFile && (
          <div className="px-4 py-2">
            <div className="flex gap-2">
              {tabs.map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  disabled={!tab.hasContent}
                  className={`flex-1 py-2.5 rounded-lg text-sm font-medium transition-colors
                    ${activeTab === tab.id
                      ? 'bg-pool-mid text-white'
                      : 'bg-gray-100 text-gray-600 active:bg-gray-200'
                    }
                    ${!tab.hasContent ? 'opacity-40' : ''}`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Content - scrollable */}
        <div className="flex-1 overflow-y-auto px-4 pb-safe">
          {loadingMarkdown && (
            <div className="py-8 text-center text-gray-400 text-sm">Loading...</div>
          )}

          {/* Key Points */}
          {activeTab === 'keyPoints' && markdownContent?.keyPoints && (
            <div className="space-y-3 py-4">
              {markdownContent.keyPoints.map((point, idx) => (
                <div
                  key={idx}
                  className="flex items-start gap-3 p-4 rounded-xl bg-emerald-50 border border-emerald-100"
                >
                  <div className="w-6 h-6 rounded-lg bg-emerald-200 flex items-center justify-center shrink-0">
                    <span className="text-sm font-bold text-emerald-700">{idx + 1}</span>
                  </div>
                  <p className="text-sm text-gray-700 leading-relaxed">{point.replace(/\*\*/g, '')}</p>
                </div>
              ))}
            </div>
          )}

          {/* Mistakes */}
          {activeTab === 'mistakes' && markdownContent?.commonMistakes && (
            <div className="space-y-3 py-4">
              {markdownContent.commonMistakes.map((mistake, idx) => (
                <div
                  key={idx}
                  className="flex items-start gap-3 p-4 rounded-xl bg-amber-50 border border-amber-100"
                >
                  <div className="w-6 h-6 rounded-lg bg-amber-200 flex items-center justify-center shrink-0">
                    <span className="text-sm font-bold text-amber-700">!</span>
                  </div>
                  <p className="text-sm text-gray-700 leading-relaxed">{mistake}</p>
                </div>
              ))}
            </div>
          )}

          {/* Drills */}
          {activeTab === 'drills' && markdownContent && (
            <div className="space-y-4 py-4">
              {/* Basic Drills */}
              {markdownContent.specificDrills && markdownContent.specificDrills.length > 0 && (
                <div>
                  <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                    Basic Drills
                  </h4>
                  <div className="space-y-3">
                    {markdownContent.specificDrills.map((drill, idx) => (
                      <div
                        key={idx}
                        className="p-4 rounded-xl bg-gray-50 border border-gray-100"
                      >
                        <p className="text-sm font-semibold text-gray-900">{drill.name.replace(/\*\*/g, '')}</p>
                        <p className="text-xs text-gray-500 mt-1 leading-relaxed">{drill.description}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Competitive Drills */}
              {markdownContent.competitiveDrills && markdownContent.competitiveDrills.length > 0 && (
                <div>
                  <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3 flex items-center gap-2">
                    <Target className="w-4 h-4" />
                    Competitive Drills
                  </h4>
                  <div className="space-y-4">
                    {markdownContent.competitiveDrills.map((drill, idx) => (
                      <div
                        key={idx}
                        className="rounded-xl border border-blue-100 bg-gradient-to-b from-blue-50 to-white overflow-hidden"
                      >
                        {/* Drill Header */}
                        <div className="px-4 py-3 bg-blue-100/50 border-b border-blue-100">
                          <h5 className="text-sm font-bold text-gray-900">{drill.name}</h5>
                          {drill.selfCheck && (
                            <p className="text-xs text-blue-600 mt-1">{drill.selfCheck}</p>
                          )}
                        </div>

                        {/* Tiers - always single column on mobile */}
                        <div className="p-3 space-y-2">
                          {(['beginner', 'intermediate', 'advanced', 'elite'] as const).map(tier => (
                            drill.tieredTargets[tier] && (
                              <div
                                key={tier}
                                className={`relative p-3 rounded-lg border ${tierColors[tier]} active:scale-[0.98] transition-transform`}
                                onClick={() => handleCreateGoalFromTier(drill.name, tier, drill.tieredTargets[tier])}
                              >
                                <div className="flex items-center justify-between">
                                  <span className={`px-2 py-1 rounded text-xs font-bold uppercase ${tierBadgeColors[tier]}`}>
                                    {tier}
                                  </span>
                                  <Plus className="w-4 h-4 text-current opacity-60" />
                                </div>
                                <p className="text-sm mt-2 leading-snug">{drill.tieredTargets[tier]}</p>
                              </div>
                            )
                          ))}
                        </div>

                        {/* Video Checks */}
                        {drill.videoChecks && drill.videoChecks.length > 0 && (
                          <div className="px-4 py-3 border-t border-blue-100 bg-gray-50/50">
                            <p className="text-xs font-semibold text-gray-500 mb-2">Video Check:</p>
                            <ul className="text-xs text-gray-500 space-y-1">
                              {drill.videoChecks.map((check, i) => (
                                <li key={i} className="flex items-start gap-2">
                                  <span className="text-blue-400 mt-0.5">•</span>
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
      </div>
    );
  }

  // Desktop layout (original)
  return (
    <div className="glass-card rounded-2xl h-full flex flex-col overflow-hidden">
      {/* Header Section - Fixed */}
      <div className="p-4 pb-0 space-y-3">
        {/* Top row: Close + Navigation */}
        <div className="flex items-center justify-between">
          <button onClick={onClose} className="p-2 rounded-lg text-pool-mid hover:text-pool-deep hover:bg-pool-light/30 transition-all">
            <X className="w-4 h-4" />
          </button>

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
          <div className="flex items-center gap-2 justify-end">
            <button onClick={handleCancelEdit} className="px-3 py-1 text-xs font-medium text-pool-mid hover:text-pool-dark">Cancel</button>
            <button onClick={handleSaveEdit} disabled={!editName.trim()} className="px-3 py-1 text-xs font-semibold bg-pool-mid text-white rounded-lg hover:bg-pool-deep disabled:opacity-50">
              <Save className="w-3 h-3 inline mr-1" />Save
            </button>
          </div>
        )}

        {/* Pill Tabs */}
        {node.sourceFile && (
          <div className="flex gap-1 p-1 bg-pool-surface/60 rounded-lg">
            {tabs.map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                disabled={!tab.hasContent}
                className={`flex-1 px-2 py-1 rounded-md text-xs font-medium transition-all
                  ${activeTab === tab.id
                    ? 'bg-pool-mid text-white shadow-sm'
                    : 'text-pool-mid hover:text-pool-dark hover:bg-pool-light/40'
                  }
                  ${!tab.hasContent ? 'opacity-40 cursor-not-allowed' : ''}`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Scrollable Content Area */}
      <div className="flex-1 overflow-y-auto px-4 pb-4 space-y-3">
        {loadingMarkdown && (
          <div className="flex items-center gap-2 py-4">
            <span className="text-sm text-pool-mid">Loading...</span>
          </div>
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

            {markdownContent.competitiveDrills && markdownContent.competitiveDrills.length > 0 && (
              <div>
                <h4 className="text-xs font-semibold text-pool-mid uppercase tracking-wide mb-2 flex items-center gap-1.5">
                  <Target className="w-3.5 h-3.5" />
                  Competitive Drills
                </h4>
                <div className="space-y-3">
                  {markdownContent.competitiveDrills.map((drill, idx) => (
                    <div key={idx} className="rounded-xl border border-blue-100/60 bg-gradient-to-br from-blue-50/40 to-white overflow-hidden">
                      <div className="px-3 py-2 bg-blue-100/30 border-b border-blue-100/40">
                        <h5 className="text-sm font-semibold text-pool-dark">{drill.name}</h5>
                        {drill.selfCheck && (
                          <p className="text-xs text-blue-600 mt-0.5">{drill.selfCheck}</p>
                        )}
                      </div>

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
    </div>
  );
}