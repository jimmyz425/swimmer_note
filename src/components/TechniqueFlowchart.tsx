'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { TechniqueTree, TechniqueTreeNode, Goal, MetricValue } from '@/lib/types';
import { NodeDetailPanel } from '@/components/NodeDetailPanel';
import { Check, ArrowLeft, ChevronRight, ChevronLeft, Waves } from 'lucide-react';

interface TechniqueFlowchartPageProps {
  strokeId: string;
}

// Level badge classes - sport ranking style
const levelClasses = [
  'level-1',
  'level-2',
  'level-3',
  'level-4',
  'level-5',
  'level-6',
  'level-7',
  'level-8',
];

export function TechniqueFlowchartPage({ strokeId }: TechniqueFlowchartPageProps) {
  const router = useRouter();
  const [tree, setTree] = useState<TechniqueTree | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedNode, setSelectedNode] = useState<TechniqueTreeNode | null>(null);
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

  const handleConfirm = async (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, _coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string; goalKind?: 'keyPoint' | 'mistake' | 'competitiveMetric' }) => {
    const description = goalFromTier
      ? goalFromTier.tier
        ? `${goalFromTier.drillName} (${goalFromTier.tier})`
        : goalFromTier.target
      : node.name;

    const newGoal: Goal = {
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'technique',
      target: node.techniqueId,
      strokeId: strokeId,
      description,
      techniqueNodeId: node.id,
      metrics,
      notes: '',
      goalKind: goalFromTier?.goalKind,
      status: 'planned',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // Save directly to today's note
    const today = new Date().toISOString().split('T')[0];
    try {
      const res = await fetch(`/api/notes/${today}`);
      const data = await res.json();
      const existingGoals = data?.note?.goals || [];

      const allGoals = [...existingGoals, newGoal];
      await fetch(`/api/notes/${today}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          date: today,
          goals: allGoals,
          strokeFocus: data?.note?.strokeFocus || [],
          techniqueFocus: data?.note?.techniqueFocus || [],
          notes: data?.note?.notes || '',
        }),
      });

      setExistingGoals(allGoals);
      setSuccessMessage(`Added "${newGoal.description}"!`);
      setTimeout(() => setSuccessMessage(null), 3000);
    } catch (err) {
      console.error('Failed to save goal:', err);
    }
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

  if (loading) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center min-h-screen">
        <p className="font-heading text-pool-mid font-medium uppercase tracking-wide">Loading...</p>
      </div>
    );
  }

  if (!tree) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center min-h-screen">
        <p className="font-heading text-pool-mid uppercase tracking-wide">No tree found</p>
      </div>
    );
  }

  const sortedNodes = [...tree.nodes].sort((a, b) => a.level - b.level);

  // ===== MOBILE LAYOUT =====
  if (isMobile) {
    return (
      <div className="fixed inset-0 bg-white flex flex-col">
        {/* Header */}
        <header className="sticky top-0 z-30 bg-white border-b border-pool-mid/20 px-4 py-3 flex items-center justify-between safe-top">
          <button
            onClick={() => router.push('/')}
            className="flex items-center gap-2 text-pool-dark font-heading font-medium uppercase tracking-wide active:opacity-70"
          >
            <ArrowLeft className="w-5 h-5" />
            Back
          </button>

          <div className="flex items-center gap-2">
            <div className="lane-badge w-6 h-6 flex items-center justify-center text-xs">
              <Waves className="w-3 h-3" />
            </div>
            <h1 className="font-heading text-base font-bold text-pool-dark uppercase tracking-wide">{tree.name}</h1>
          </div>
        </header>

        {/* Success Toast */}
        {successMessage && (
          <div className="fixed top-16 left-4 right-4 px-4 py-3 rounded-lg shadow-lg z-50 flex items-center gap-2 animate-slide-down font-heading font-bold"
            style={{
              background: 'linear-gradient(135deg, #ffd700 0%, #ffab00 100%)',
              color: '#5d4e0c',
            }}
          >
            <Check className="w-5 h-5" />
            {successMessage}
          </div>
        )}

        {/* Main Content */}
        {showSheet ? (
          /* Technique List Sheet */
          <div className="flex-1 overflow-y-auto px-4 py-4 pb-safe">
            {/* Lane divider */}
            <div className="lane-divider mb-4" />

            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="font-heading text-lg font-bold text-pool-dark uppercase tracking-wide">Techniques</h2>
                <p className="text-xs text-pool-mid font-body">{sortedNodes.length} skills</p>
              </div>
            </div>

            <div className="space-y-2">
              {sortedNodes.map((node, idx) => {
                const levelClass = levelClasses[Math.min(node.level - 1, levelClasses.length - 1)];
                const isSelected = selectedNode?.id === node.id;

                return (
                  <button
                    key={node.id}
                    onClick={() => handleNodeClick(node)}
                    className={`lane-card w-full p-3 transition-all text-left active:scale-[0.98] splash-trigger
                      ${isSelected ? 'ring-2 ring-accent' : ''}`}
                  >
                    <div className="flex items-center gap-3">
                      {/* Lane number */}
                      <div className="lane-badge w-8 h-8 flex items-center justify-center text-sm">
                        {idx + 1}
                      </div>

                      {/* Level badge */}
                      <span className={`level-badge ${levelClass}`}>
                        Lv.{node.level}
                      </span>

                      <div className="flex-1 min-w-0">
                        <p className="font-heading text-sm font-bold text-pool-dark truncate uppercase tracking-wide">{node.name}</p>
                        <p className="text-xs text-pool-mid font-body truncate">{node.description}</p>
                      </div>

                      <ChevronRight className="w-5 h-5 text-pool-mid" />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        ) : (
          /* Full-screen Detail View */
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
        )}
      </div>
    );
  }

  // ===== DESKTOP LAYOUT =====
  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen flex flex-col">
      {/* Header */}
      <header className="bg-white border-b border-pool-mid/20 px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push('/')}
            className="flex items-center gap-2 text-pool-dark font-heading font-medium uppercase tracking-wide hover:text-accent transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            Back
          </button>

          <div className="flex items-center gap-2">
            <div className="lane-badge w-8 h-8 flex items-center justify-center text-sm">
              <Waves className="w-4 h-4" />
            </div>
            <h1 className="font-heading text-xl font-bold text-pool-dark uppercase tracking-wide">{tree.name}</h1>
          </div>
        </div>
      </header>

      {/* Success message */}
      {successMessage && (
        <div className="fixed top-20 left-1/2 -translate-x-1/2 px-6 py-3 rounded-lg shadow-lg flex items-center gap-2 z-30 font-heading font-bold"
          style={{
            background: 'linear-gradient(135deg, #ffd700 0%, #ffab00 100%)',
            color: '#5d4e0c',
          }}
        >
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
            className="absolute -right-3 top-1/2 -translate-y-1/2 z-20 w-6 h-12 rounded-lg bg-white border border-pool-mid/30 hover:border-accent
              flex items-center justify-center text-pool-dark transition-all shadow-sm"
          >
            {leftPanelExpanded ? <ChevronLeft className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>

          <div className="h-full glass-card rounded-r-2xl overflow-hidden">
            {leftPanelExpanded ? (
              <div className="h-full flex flex-col">
                <div className="p-4 pb-2 border-b border-pool-mid/10">
                  <h2 className="font-heading text-sm font-bold text-pool-dark uppercase tracking-wide">Techniques</h2>
                  <p className="text-xs text-pool-mid font-body">{tree.nodes.length} skills</p>
                </div>

                <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
                  {sortedNodes.map((node, idx) => {
                    const levelClass = levelClasses[Math.min(node.level - 1, levelClasses.length - 1)];
                    const isSelected = selectedNode?.id === node.id;

                    return (
                      <button
                        key={node.id}
                        onClick={() => handleNodeClick(node)}
                        className={`lane-card w-full p-3 transition-all text-left
                          ${isSelected ? 'ring-2 ring-accent' : ''}`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <div className="lane-badge w-6 h-6 flex items-center justify-center text-xs">
                            {idx + 1}
                          </div>
                          <span className={`level-badge ${levelClass}`}>
                            Lv.{node.level}
                          </span>
                        </div>
                        <p className="font-heading text-sm font-bold text-pool-dark leading-tight uppercase tracking-wide">{node.name}</p>
                        <p className="text-xs text-pool-mid mt-0.5 line-clamp-1 font-body">{node.description}</p>
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center py-2 space-y-1">
                {sortedNodes.map((node, idx) => {
                  const isSelected = selectedNode?.id === node.id;

                  return (
                    <button
                      key={node.id}
                      onClick={() => handleNodeClick(node)}
                      className={`lane-badge w-8 h-8 flex items-center justify-center transition-all
                        ${isSelected ? 'ring-2 ring-accent ring-offset-1' : 'hover:scale-110'}`}
                    >
                      <span className="text-xs font-bold">
                        {idx + 1}
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
    </div>
  );
}