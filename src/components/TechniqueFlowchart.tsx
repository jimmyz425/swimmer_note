'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { TechniqueTree, TechniqueTreeNode, Goal, MetricValue } from '@/lib/types';
import { getNodeById } from '@/lib/treeToMermaid';
import { NodeDetailPanel } from '@/components/NodeDetailPanel';
import { Check, ArrowLeft, Plus, X, ChevronRight, ChevronLeft, RefreshCw } from 'lucide-react';

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

  // Custom node creation state
  const [showCustomNodeModal, setShowCustomNodeModal] = useState(false);
  const [customNodeParent, setCustomNodeParent] = useState<TechniqueTreeNode | null>(null);
  const [customNodeName, setCustomNodeName] = useState('');
  const [customNodeDescription, setCustomNodeDescription] = useState('');
  const [customNodeRevisit, setCustomNodeRevisit] = useState(false);

  // Left panel state - auto-hide
  const [leftPanelExpanded, setLeftPanelExpanded] = useState(true);

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
        // Auto-select first node
        if (data.tree?.nodes?.length > 0) {
          setSelectedNode(data.tree.nodes[0]);
        }
      })
      .catch(err => console.error('Failed to load tree:', err))
      .finally(() => setLoading(false));
  }, [strokeId]);

  const handleNodeClick = (node: TechniqueTreeNode) => {
    setSelectedNode(node);
    setLeftPanelExpanded(true);
  };

  const handleConfirm = (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string, goalFromTier?: { drillName: string; tier: string; target: string }) => {
    const newGoal: Goal = {
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'technique',
      target: node.techniqueId,
      strokeId: strokeId,
      description: goalFromTier ? `${goalFromTier.drillName} (${goalFromTier.tier})` : node.name,
      techniqueNodeId: node.id,
      revisit: node.revisit,
      metrics,
      coachingTips,
      notes: goalFromTier ? `Target: ${goalFromTier.target}` : undefined,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // Add goal directly - no stroke limitation
    setAddedGoals([...addedGoals, newGoal]);
    setSuccessMessage(`Added "${newGoal.description}" to today's goals!`);
    setTimeout(() => setSuccessMessage(null), 3000);
  };

  // Open custom node modal
  const handleAddCustomNode = (parentNode: TechniqueTreeNode) => {
    setCustomNodeParent(parentNode);
    setCustomNodeName('');
    setCustomNodeDescription('');
    setCustomNodeRevisit(false);
    setShowCustomNodeModal(true);
  };

  // Create custom node
  const handleCreateCustomNode = async () => {
    if (!tree || !customNodeParent || !customNodeName.trim()) return;

    // Calculate next dot number based on existing children
    const existingChildIds = customNodeParent.children
      .filter(id => id.startsWith(`${customNodeParent.id}.`))
      .map(id => parseInt(id.split('.')[1] || '0', 10));
    const nextNumber = existingChildIds.length > 0 ? Math.max(...existingChildIds) + 1 : 1;

    const newNode: TechniqueTreeNode = {
      id: `${customNodeParent.id}.${nextNumber}`,
      techniqueId: customNodeParent.techniqueId,
      level: customNodeParent.level + 1,
      name: `${customNodeParent.name}: ${customNodeName.trim()}`,
      description: customNodeDescription.trim() || 'Custom practice focus',
      revisit: customNodeRevisit,
      prerequisites: [customNodeParent.id],
      children: [],
    };

    // Update parent node (preserve existing children)
    const updatedParent: TechniqueTreeNode = {
      ...customNodeParent,
      children: [...customNodeParent.children, newNode.id],
    };

    // Update tree
    const updatedTree: TechniqueTree = {
      ...tree,
      nodes: [
        ...tree.nodes.filter(n => n.id !== customNodeParent.id),
        updatedParent,
        newNode,
      ],
      customized: true,
    };

    // Save tree via API
    try {
      const res = await fetch(`/api/trees/${strokeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatedTree),
      });

      if (res.ok) {
        setTree(updatedTree);
        setShowCustomNodeModal(false);
        setCustomNodeParent(null);
        setSuccessMessage(`Added custom node "${newNode.name}"!`);
        setTimeout(() => setSuccessMessage(null), 3000);
        setSelectedNode(updatedParent);
      }
    } catch (err) {
      console.error('Failed to save custom node:', err);
    }
  };

  // Update existing node
  const handleUpdateNode = async (updatedNode: TechniqueTreeNode) => {
    if (!tree) return;

    const updatedTree: TechniqueTree = {
      ...tree,
      nodes: tree.nodes.map(n => n.id === updatedNode.id ? updatedNode : n),
      customized: true,
    };

    // Save tree via API
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

  // Navigate to node by sourceFile
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
      // Combine existing goals with added goals
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

  // Auto-collapse left panel after delay
  useEffect(() => {
    if (leftPanelExpanded && selectedNode) {
      const timer = setTimeout(() => {
        setLeftPanelExpanded(false);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [leftPanelExpanded, selectedNode]);

  if (loading) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center">
        <p className="text-pool-mid font-medium">Loading technique tree...</p>
      </div>
    );
  }

  if (!tree) {
    return (
      <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light flex items-center justify-center">
        <p className="text-pool-mid">No tree found for this stroke</p>
      </div>
    );
  }

  // Sort nodes by level
  const sortedNodes = [...tree.nodes].sort((a, b) => a.level - b.level);

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

      {/* Custom Node Creation Modal */}
      {showCustomNodeModal && customNodeParent && (
        <div className="fixed inset-0 bg-pool-surface/80 flex items-center justify-center z-40">
          <div className="glass-card rounded-xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-pool-dark">Add Custom Sub-Node</h3>
              <button
                onClick={() => setShowCustomNodeModal(false)}
                className="text-pool-mid hover:text-pool-deep transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-sm text-pool-mid mb-4">
              Adding to: <span className="font-semibold text-pool-dark">{customNodeParent.name}</span>
            </p>

            {customNodeName.trim() && (
              <div className="bg-pool-mid/10 px-4 py-2 rounded-lg mb-4">
                <span className="text-xs text-pool-mid">Full name: </span>
                <span className="text-sm font-semibold text-pool-dark">
                  {customNodeParent.name}: {customNodeName.trim()}
                </span>
              </div>
            )}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-semibold text-pool-dark mb-1.5">Sub-Node Name</label>
                <input
                  type="text"
                  value={customNodeName}
                  onChange={(e) => setCustomNodeName(e.target.value)}
                  placeholder="e.g., Shoulder Rotation"
                  className="w-full rounded-xl border border-pool-light/50 px-4 py-2.5 text-sm font-medium text-pool-dark
                    bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-pool-dark mb-1.5">Description</label>
                <textarea
                  value={customNodeDescription}
                  onChange={(e) => setCustomNodeDescription(e.target.value)}
                  placeholder="What to focus on for this technique element"
                  rows={2}
                  className="w-full rounded-xl border border-pool-light/50 px-4 py-2.5 text-sm text-pool-dark
                    bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none resize-none"
                />
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="customRevisit"
                  checked={customNodeRevisit}
                  onChange={(e) => setCustomNodeRevisit(e.target.checked)}
                  className="w-5 h-5 rounded border-pool-mid/30 text-pool-mid focus:ring-pool-mid/20"
                />
                <label htmlFor="customRevisit" className="text-sm font-medium text-pool-dark">
                  Mark as revisit
                </label>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleCreateCustomNode}
                disabled={!customNodeName.trim()}
                className="flex-1 flex items-center justify-center gap-2 bg-pool-mid text-white rounded-xl px-4 py-3
                  font-semibold hover:bg-pool-deep transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Plus className="w-4 h-4" />
                Create Node
              </button>
              <button
                onClick={() => setShowCustomNodeModal(false)}
                className="px-4 py-3 rounded-xl font-medium text-pool-mid hover:bg-pool-light/50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Main content: Collapsible Left Panel + Detail Panel */}
      <main className="flex-1 flex relative overflow-hidden">
        {/* Left Panel - Technique Cards */}
        <div
          className={`absolute left-0 top-0 bottom-0 z-10 transition-all duration-300 ease-out
            ${leftPanelExpanded ? 'w-72' : 'w-12'}`}
          onMouseEnter={() => setLeftPanelExpanded(true)}
        >
          {/* Collapse Toggle Button */}
          <button
            onClick={() => setLeftPanelExpanded(!leftPanelExpanded)}
            className="absolute -right-3 top-1/2 -translate-y-1/2 z-20 w-6 h-12 rounded-lg bg-pool-mid/30 hover:bg-pool-mid/50
              flex items-center justify-center text-pool-dark transition-all shadow-sm"
          >
            {leftPanelExpanded ? <ChevronLeft className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>

          {/* Panel Content */}
          <div className="h-full glass-card rounded-r-2xl overflow-hidden">
            {leftPanelExpanded ? (
              /* Expanded: Full card list */
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
                          {node.revisit && (
                            <RefreshCw className="w-3 h-3 text-amber-500" />
                          )}
                        </div>
                        <p className="text-sm font-semibold text-pool-dark leading-tight">{node.name}</p>
                        <p className="text-xs text-pool-mid mt-0.5 line-clamp-1">{node.description}</p>
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : (
              /* Collapsed: Level indicators only */
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

        {/* Right Panel - Detail View (takes full width when left collapsed) */}
        <div className={`flex-1 transition-all duration-300 ease-out ${leftPanelExpanded ? 'ml-72 pl-4' : 'ml-12 pl-4'} p-4`}>
          <NodeDetailPanel
            node={selectedNode}
            strokeId={strokeId}
            onConfirm={handleConfirm}
            onClose={() => setSelectedNode(null)}
            onAddCustomNode={handleAddCustomNode}
            onUpdateNode={handleUpdateNode}
            onNavigateNode={handleNavigateNode}
            expanded={!leftPanelExpanded}
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
                {goal.revisit && <RefreshCw className="w-3 h-3 text-amber-500" />}
              </span>
            ))}
          </div>
          <p className="text-xs text-pool-mid ml-auto">{addedGoals.length} goals added</p>
        </div>
      )}
    </div>
  );
}