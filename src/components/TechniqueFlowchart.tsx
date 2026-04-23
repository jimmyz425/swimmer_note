'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { TechniqueTree, TechniqueTreeNode, Goal, MetricValue } from '@/lib/types';
import { MermaidDiagram } from '@/lib/mermaid';
import { treeToMermaid, getNodeById } from '@/lib/treeToMermaid';
import { NodeDetailPanel } from '@/components/NodeDetailPanel';
import { AlertTriangle, Check, ArrowLeft, Plus, X, Loader2, Edit3 } from 'lucide-react';

interface TechniqueFlowchartPageProps {
  strokeId: string;
}

export function TechniqueFlowchartPage({ strokeId }: TechniqueFlowchartPageProps) {
  const router = useRouter();
  const [tree, setTree] = useState<TechniqueTree | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedNode, setSelectedNode] = useState<TechniqueTreeNode | null>(null);
  const [addedGoals, setAddedGoals] = useState<Goal[]>([]);
  const [existingGoals, setExistingGoals] = useState<Goal[]>([]);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [warningMessage, setWarningMessage] = useState<string | null>(null);
  const [pendingGoal, setPendingGoal] = useState<Goal | null>(null);

  // Custom node creation state
  const [showCustomNodeModal, setShowCustomNodeModal] = useState(false);
  const [customNodeParent, setCustomNodeParent] = useState<TechniqueTreeNode | null>(null);
  const [customNodeName, setCustomNodeName] = useState('');
  const [customNodeDescription, setCustomNodeDescription] = useState('');
  const [customNodeRevisit, setCustomNodeRevisit] = useState(false);

  // Expansion loading state
  const [expandingNode, setExpandingNode] = useState(false);

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
      })
      .catch(err => console.error('Failed to load tree:', err))
      .finally(() => setLoading(false));
  }, [strokeId]);

  const handleNodeClick = (nodeId: string) => {
    if (!tree) return;
    const node = getNodeById(tree, nodeId);
    setSelectedNode(node);
  };

  // Check if there's already a goal from this stroke
  const hasGoalFromStroke = (stroke: string): Goal | undefined => {
    return existingGoals.find(g => g.strokeId === stroke) ||
           addedGoals.find(g => g.strokeId === stroke);
  };

  const handleConfirm = (node: TechniqueTreeNode, metrics: Record<string, MetricValue>, coachingTips?: string) => {
    const newGoal: Goal = {
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'technique',
      target: node.techniqueId,
      strokeId: strokeId,
      description: node.name,
      techniqueNodeId: node.id,
      revisit: node.revisit,
      metrics,
      coachingTips,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // Check if there's already a goal from this stroke
    const existingGoalFromStroke = hasGoalFromStroke(strokeId);

    if (existingGoalFromStroke) {
      // Show warning - need to replace
      setWarningMessage(`You already have "${existingGoalFromStroke.description}" from this stroke. Replace it with "${node.name}"?`);
      setPendingGoal(newGoal);
      setSelectedNode(null);
    } else {
      // No existing goal from this stroke - add directly
      setAddedGoals([...addedGoals, newGoal]);
      setSelectedNode(null);
      setSuccessMessage(`Added "${node.name}" to today's goals!`);
      setTimeout(() => setSuccessMessage(null), 3000);
    }
  };

  const handleConfirmReplace = () => {
    if (!pendingGoal) return;

    // Remove the existing goal from this stroke
    const filteredExisting = existingGoals.filter(g => g.strokeId !== strokeId);
    const filteredAdded = addedGoals.filter(g => g.strokeId !== strokeId);

    // Add the new goal
    setExistingGoals(filteredExisting);
    setAddedGoals([...filteredAdded, pendingGoal]);
    setPendingGoal(null);
    setWarningMessage(null);
    setSuccessMessage(`Replaced with "${pendingGoal.description}"!`);
    setTimeout(() => setSuccessMessage(null), 3000);
  };

  const handleCancelReplace = () => {
    setPendingGoal(null);
    setWarningMessage(null);
  };

  // Expand node with LLM
  const handleExpandNode = async (nodeId: string, coachingTips: string) => {
    if (!tree) return;
    setExpandingNode(true);

    try {
      const res = await fetch('/api/trees/expand', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          strokeId,
          nodeId,
          coachingTips,
        }),
      });

      const data = await res.json();
      if (data.success) {
        setTree(data.tree);
        setSuccessMessage(`Expanded "${data.parentNode.name}" into ${data.newNodes.length} sub-nodes!`);
        setTimeout(() => setSuccessMessage(null), 3000);
        // Keep node selected to show new children
        setSelectedNode(data.parentNode);
      } else {
        console.error('Failed to expand:', data.error);
      }
    } catch (err) {
      console.error('Failed to expand node:', err);
    } finally {
      setExpandingNode(false);
    }
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
        // Keep parent selected to show new child
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

  const handleSaveGoals = async () => {
    const today = new Date().toISOString().split('T')[0];

    try {
      // Combine existing goals (filtered to remove any replaced ones) with added goals
      const filteredExisting = existingGoals.filter(g => !addedGoals.some(ag => ag.strokeId === g.strokeId));
      const allGoals = [...filteredExisting, ...addedGoals];

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

  const mermaidCode = treeToMermaid(tree);
  const currentGoalFromStroke = hasGoalFromStroke(strokeId);

  return (
    <div className="flex-1 bg-gradient-to-b from-pool-surface to-pool-light min-h-screen">
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
          {/* Show current focus limit */}
          {currentGoalFromStroke && (
            <div className="flex items-center gap-2 bg-amber-100 text-amber-700 px-3 py-1.5 rounded-lg text-sm font-medium">
              <AlertTriangle className="w-4 h-4" />
              <span>Current focus: {currentGoalFromStroke.description}</span>
            </div>
          )}

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

      {/* Warning message - Replace confirmation */}
      {warningMessage && (
        <div className="fixed inset-x-4 top-20 mx-auto max-w-md bg-amber-50 border-2 border-amber-200 rounded-xl shadow-lg p-4 z-30">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-6 h-6 text-amber-500 flex-shrink-0" />
            <div className="flex-1">
              <p className="text-amber-800 font-semibold mb-3">{warningMessage}</p>
              <div className="flex gap-3">
                <button
                  onClick={handleConfirmReplace}
                  className="flex items-center gap-2 bg-amber-500 text-white px-4 py-2 rounded-lg font-medium hover:bg-amber-600 transition-colors"
                >
                  <Plus className="w-4 h-4" />
                  Replace
                </button>
                <button
                  onClick={handleCancelReplace}
                  className="text-amber-700 px-4 py-2 rounded-lg font-medium hover:bg-amber-100 transition-colors"
                >
                  Keep Current
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Expansion Loading Overlay */}
      {expandingNode && (
        <div className="fixed inset-0 bg-pool-surface/80 flex items-center justify-center z-40">
          <div className="glass-card rounded-xl p-6 flex flex-col items-center gap-4">
            <Loader2 className="w-8 h-8 text-pool-mid animate-spin" />
            <p className="text-pool-dark font-semibold">Expanding node with LLM...</p>
            <p className="text-pool-mid text-sm">Analyzing coaching tips to create sub-nodes</p>
          </div>
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

            {/* Preview of full name */}
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
                <p className="text-xs text-pool-mid mt-1">Will become "{customNodeParent.name}: [your input]"</p>
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
                  Mark as revisit (needs regular practice)
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

      {/* Main content: Flowchart + Side Panel */}
      <main className="p-6 flex gap-6 h-[calc(100vh-100px)]">
        {/* Flowchart */}
        <div className="flex-1 glass-card rounded-xl p-6 overflow-auto">
          <MermaidDiagram code={mermaidCode} onNodeClick={handleNodeClick} />
        </div>

        {/* Side Panel */}
        <div className="w-80">
          <NodeDetailPanel
            node={selectedNode}
            strokeId={strokeId}
            onConfirm={handleConfirm}
            onClose={() => setSelectedNode(null)}
            onExpandNode={handleExpandNode}
            onAddCustomNode={handleAddCustomNode}
            onUpdateNode={handleUpdateNode}
          />
        </div>
      </main>

      {/* Added goals list */}
      {addedGoals.length > 0 && (
        <div className="fixed bottom-4 left-4 right-4 glass-card rounded-xl shadow-lg p-4 z-20">
          <h3 className="text-sm font-semibold text-pool-dark mb-2">Today&apos;s Focus Goals:</h3>
          <div className="flex gap-2 overflow-x-auto">
            {addedGoals.map(goal => (
              <span key={goal.id} className="bg-pool-mid/20 text-pool-dark px-4 py-2 rounded-xl text-sm font-medium flex items-center gap-2">
                {goal.strokeId === 'master' ? (
                  <span className="text-amber-500">★</span>
                ) : (
                  <span className="text-pool-mid">🌊</span>
                )}
                {goal.description}
                {goal.revisit && <span className="text-xs text-amber-600">(Revisit)</span>}
              </span>
            ))}
          </div>
          <p className="text-xs text-pool-mid mt-2">One goal per stroke for razor-sharp focus</p>
        </div>
      )}
    </div>
  );
}