'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { TechniqueTree, TechniqueTreeNode, Goal, MetricValue } from '@/lib/types';
import { NodeDetailPanel } from '@/components/NodeDetailPanel';
import { Check, ArrowLeft, ChevronRight, ChevronLeft } from 'lucide-react';

interface TechniqueFlowchartPageProps {
  strokeId: string;
}

const levelColors = [
  'from-emerald-400 to-emerald-500',
  'from-cyan-400 to-cyan-500',
  'from-amber-400 to-amber-500',
  'from-orange-400 to-orange-500',
  'from-purple-400 to-purple-500',
  'from-pink-400 to-pink-500',
  'from-indigo-400 to-indigo-500',
  'from-red-400 to-red-500',
];

export function TechniqueFlowchartPage({ strokeId }: TechniqueFlowchartPageProps) {
  const router = useRouter();
  const [tree, setTree] = useState<TechniqueTree | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedNode, setSelectedNode] = useState<TechniqueTreeNode | null>(null);
  const [addedGoals, setAddedGoals] = useState<Goal[]>([]);
  const [existingGoals, setExistingGoals] = useState<Goal[]>([]);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Mobile state
  const [isMobile, setIsMobile] = useState(false);
  const [showSheet, setShowSheet] = useState(true);

  // Desktop: Left panel state - auto-hide
  const [leftPanelExpanded, setLeftPanelExpanded] = useState(true);

  // Detect mobile viewport
  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // Fetch existing goals on mount
  useEffect(() => {
    const today = new Date().toISOString().split('T')[0];
    fetch(`/api/notes/${today}`)
      .then(res => res.json())
      .then(data => {
        if (data?.note?.goals) {
          setExistingGoals(data.note.goals);
        }
      })
      .catch(err => console.error('Failed to fetch existing goals:', err));
  }, []);

  useEffect(() => {
    setLoading(true);
    fetch(`/api/trees/${strokeId}`)
      .then(res => res.json())
      .then(data => {
        setTree(data.tree);
        if (data.tree?.nodes?.length > 0) {
          setSelectedNode(data.tree.nodes[0]);
        }
      })
      .catch(err => console.error('Failed to load tree:', err))
      .finally(() => setLoading(false));
  }, [strokeId]);

  const handleNodeClick = (node: TechniqueTreeNode) => {
    setSelectedNode(node);
    if (isMobile) {
      setShowSheet(false);
    }
  };

  const handleConfirm = (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string }) => {
    const description = goalFromTier
      ? goalFromTier.tier
        ? `${goalFromTier.drillName} (${goalFromTier.tier})`
        : goalFromTier.target.slice(0, 60) + (goalFromTier.target.length > 60 ? '...' : '')
      : node.name;

    const newGoal: Goal = {
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'technique',
      target: node.techniqueId,
      strokeId: strokeId,
      description,
      techniqueNodeId: node.id,
      metrics,
      coachingTips,
      notes: goalFromTier?.target || undefined,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    setAddedGoals([...addedGoals, newGoal]);
    setSuccessMessage(`Added "${newGoal.description}"!`);
    setTimeout(() => setSuccessMessage(null), 3000);
  };

  const handleUpdateNode = async (updatedNode: TechniqueTreeNode) => {
    if (!tree) return;

    const updatedTree: TechniqueTree = {
      ...tree,
      nodes: tree.nodes.map(n => n.id === updatedNode.id ? updatedNode : n),
      customized: true,
    };

    try {
      const res = await fetch(`/api/trees/${strokeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatedTree),
      });

      if (res.ok) {
        setTree(updatedTree);
        setSelectedNode(updatedNode);
        setSuccessMessage(`Updated "${updatedNode.name}"!`);
        setTimeout(() => setSuccessMessage(null), 3000);
      }
    } catch (err) {
      console.error('Failed to update node:', err);
    }
  };

  const handleNavigateNode = (filename: string) => {
    if (!tree) return;
    const node = tree.nodes.find(n => n.sourceFile === filename);
    if (node) {
      setSelectedNode(node);
    }
  };

  const handleSaveGoals = async () => {
    const today = new Date().toISOString().split('T')[0];

    try {
      const allGoals = [...existingGoals, ...addedGoals];
      const res = await fetch(`/api/notes/${today}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          date: today,
          goals: allGoals,
          strokeFocus: [],
          techniqueFocus: [],
          notes: '',
        }),
      });

      if (res.ok) {
        router.push('/');
      }
    } catch (err) {
      console.error('Failed to save goals:', err);
    }
  };

  if (loading) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center min-h-screen">
        <p className="text-pool-mid font-medium">Loading...</p>
      </div>
    );
  }

  if (!tree) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center min-h-screen">
        <p className="text-pool-mid">No tree found</p>
      </div>
    );
  }

  const sortedNodes = [...tree.nodes].sort((a, b) => a.level - b.level);

  // ===== MOBILE LAYOUT =====
  if (isMobile) {
    return (
      <div className="fixed inset-0 bg-white flex flex-col">
        {/* Header */}
        <header className="sticky top-0 z-30 bg-white border-b border-gray-100 px-4 py-3 flex items-center justify-between safe-top">
          <button
            onClick={() => router.push('/')}
            className="flex items-center gap-2 text-gray-700 font-medium active:opacity-70"
          >
            <ArrowLeft className="w-5 h-5" />
            Back
          </button>
          <h1 className="text-base font-bold text-gray-900">{tree.name}</h1>
          {addedGoals.length > 0 && (
            <button
              onClick={handleSaveGoals}
              className="flex items-center gap-1 bg-pool-mid text-white px-3 py-1.5 rounded-lg text-sm font-semibold active:bg-pool-deep"
            >
              <Check className="w-4 h-4" />
              Save
            </button>
          )}
        </header>

        {/* Success Toast */}
        {successMessage && (
          <div className="fixed top-16 left-4 right-4 bg-emerald-500 text-white px-4 py-3 rounded-xl shadow-lg z-50 flex items-center gap-2 animate-slide-down">
            <Check className="w-5 h-5" />
            {successMessage}
          </div>
        )}

        {/* Main Content: Either Sheet or Detail */}
        {showSheet ? (
          /* Technique List Sheet */
          <div className="flex-1 overflow-y-auto px-4 py-4 pb-safe">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-bold text-gray-900">Techniques</h2>
                <p className="text-xs text-gray-500">{sortedNodes.length} skills</p>
              </div>
            </div>

            <div className="space-y-2">
              {sortedNodes.map(node => {
                const levelGradient = levelColors[Math.min(node.level - 1, levelColors.length - 1)];
                const isSelected = selectedNode?.id === node.id;

                return (
                  <button
                    key={node.id}
                    onClick={() => handleNodeClick(node)}
                    className={`w-full p-4 rounded-xl transition-all text-left active:scale-[0.98]
                      ${isSelected
                        ? 'bg-pool-mid/10 border-2 border-pool-mid'
                        : 'bg-gray-50 border border-gray-100 active:bg-gray-100'
                      }`}
                  >
                    <div className="flex items-center gap-3 mb-1">
                      <span className={`inline-flex items-center justify-center w-8 h-8 rounded-full text-sm font-bold text-white bg-gradient-to-r ${levelGradient}`}>
                        {node.level}
                      </span>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-900 truncate">{node.name}</p>
                        <p className="text-xs text-gray-500 truncate">{node.description}</p>
                      </div>
                      <ChevronRight className="w-5 h-5 text-gray-400" />
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Goals indicator */}
            {addedGoals.length > 0 && (
              <div className="mt-4 p-4 rounded-xl bg-pool-mid/5 border border-pool-mid/20">
                <p className="text-xs text-gray-500 mb-2">Goals to save:</p>
                <div className="flex flex-wrap gap-2">
                  {addedGoals.map(goal => (
                    <span
                      key={goal.id}
                      className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-sm text-gray-700"
                    >
                      🌊 {goal.description}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        ) : (
          /* Full-screen Detail View */
          <>
            <div className="flex-1 overflow-hidden">
              <NodeDetailPanel
                node={selectedNode}
                strokeId={strokeId}
                onConfirm={handleConfirm}
                onClose={() => setShowSheet(true)}
                onUpdateNode={handleUpdateNode}
                onNavigateNode={handleNavigateNode}
                isMobile={true}
              />
            </div>
          </>
        )}
      </div>
    );
  }

  // ===== DESKTOP LAYOUT =====
  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen flex flex-col">
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
          <h1 className="text-xl font-bold text-pool-dark">{tree.name}</h1>
        </div>

        <div className="flex items-center gap-4">
          {addedGoals.length > 0 && (
            <button
              onClick={handleSaveGoals}
              className="flex items-center gap-2 bg-pool-mid text-white px-4 py-2 rounded-xl text-sm font-semibold hover:bg-pool-deep transition-colors"
            >
              <Check className="w-4 h-4" />
              Save & Return
            </button>
          )}
        </div>
      </header>

      {/* Success message */}
      {successMessage && (
        <div className="fixed top-20 left-1/2 -translate-x-1/2 bg-emerald-100 text-emerald-700 px-6 py-3 rounded-xl shadow-lg flex items-center gap-2 z-30">
          <Check className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      {/* Main content */}
      <main className="flex-1 flex relative overflow-hidden">
        {/* Left Panel */}
        <div
          className={`absolute left-0 top-0 bottom-0 z-10 transition-all duration-300 ease-out
            ${leftPanelExpanded ? 'w-72' : 'w-12'}`}
        >
          <button
            onClick={() => setLeftPanelExpanded(!leftPanelExpanded)}
            className="absolute -right-3 top-1/2 -translate-y-1/2 z-20 w-6 h-12 rounded-lg bg-pool-mid/30 hover:bg-pool-mid/50
              flex items-center justify-center text-pool-dark transition-all shadow-sm"
          >
            {leftPanelExpanded ? <ChevronLeft className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>

          <div className="h-full glass-card rounded-r-2xl overflow-hidden">
            {leftPanelExpanded ? (
              <div className="h-full flex flex-col">
                <div className="p-4 pb-2">
                  <h2 className="text-sm font-bold text-pool-dark uppercase tracking-wide">Techniques</h2>
                  <p className="text-xs text-pool-mid">{tree.nodes.length} skills</p>
                </div>

                <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
                  {sortedNodes.map(node => {
                    const levelGradient = levelColors[Math.min(node.level - 1, levelColors.length - 1)];
                    const isSelected = selectedNode?.id === node.id;

                    return (
                      <button
                        key={node.id}
                        onClick={() => handleNodeClick(node)}
                        className={`w-full p-3 rounded-xl transition-all text-left
                          ${isSelected
                            ? 'bg-pool-mid/20 border-2 border-pool-mid shadow-sm'
                            : 'bg-white/60 border border-pool-light/30 hover:bg-white/80 hover:border-pool-mid/30'
                          }`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold text-white bg-gradient-to-r ${levelGradient}`}>
                            Lv.{node.level}
                          </span>
                        </div>
                        <p className="text-sm font-semibold text-pool-dark leading-tight">{node.name}</p>
                        <p className="text-xs text-pool-mid mt-0.5 line-clamp-1">{node.description}</p>
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center py-2 space-y-1">
                {sortedNodes.map(node => {
                  const levelGradient = levelColors[Math.min(node.level - 1, levelColors.length - 1)];
                  const isSelected = selectedNode?.id === node.id;

                  return (
                    <button
                      key={node.id}
                      onClick={() => handleNodeClick(node)}
                      className={`w-8 h-8 rounded-lg flex items-center justify-center transition-all
                        ${isSelected
                          ? 'ring-2 ring-pool-mid ring-offset-1'
                          : 'hover:scale-110'
                        }`}
                      style={{ background: isSelected ? `linear-gradient(135deg, ${levelGradient.replace('from-', '').replace('to-', ', ')})` : '#f0f4f8' }}
                    >
                      <span className={`text-xs font-bold ${isSelected ? 'text-white' : 'text-pool-mid'}`}>
                        {node.level}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right Panel */}
        <div className={`flex-1 transition-all duration-300 ease-out ${leftPanelExpanded ? 'ml-72 pl-4' : 'ml-12 pl-4'} p-4`}>
          <NodeDetailPanel
            node={selectedNode}
            strokeId={strokeId}
            onConfirm={handleConfirm}
            onClose={() => setSelectedNode(null)}
            onUpdateNode={handleUpdateNode}
            onNavigateNode={handleNavigateNode}
            expanded={!leftPanelExpanded}
            isMobile={false}
          />
        </div>
      </main>

      {/* Added goals list */}
      {addedGoals.length > 0 && (
        <div className="glass-card shadow-sm px-6 py-3 flex items-center gap-4">
          <h3 className="text-sm font-semibold text-pool-dark">Added:</h3>
          <div className="flex gap-2 overflow-x-auto">
            {addedGoals.map(goal => (
              <span key={goal.id} className="bg-pool-mid/20 text-pool-dark px-3 py-1 rounded-lg text-sm font-medium flex items-center gap-2">
                <span className="text-pool-mid">🌊</span>
                {goal.description}
              </span>
            ))}
          </div>
          <p className="text-xs text-pool-mid ml-auto">{addedGoals.length} goals added</p>
        </div>
      )}
    </div>
  );
}