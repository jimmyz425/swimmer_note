'use client';

import { useState } from 'react';
import { TrainingNote, StrokeId, TechniqueId, Goal, GoalStatus, TechniqueTreeNode } from '@/lib/types';
import { GoalInput } from './GoalInput';
import { GoalList } from './GoalList';
import { TechniqueTreeModal } from './TechniqueTreeModal';

interface DailyNoteFormProps {
  note: TrainingNote;
  strokes: { id: string; name: string }[];
  techniques: { id: string; name: string; category: string }[];
  onSave: (note: TrainingNote) => void;
  onRequestSuggestions?: () => void;
  suggestions?: string | null;
  isLoadingSuggestions?: boolean;
}

export function DailyNoteForm({
  note,
  strokes,
  techniques,
  onSave,
  onRequestSuggestions,
  suggestions,
  isLoadingSuggestions,
}: DailyNoteFormProps) {
  const [strokeFocus, setStrokeFocus] = useState<StrokeId[]>(note.strokeFocus);
  const [techniqueFocus, setTechniqueFocus] = useState<TechniqueId[]>(note.techniqueFocus);
  const [goals, setGoals] = useState<Goal[]>(note.goals);
  const [notes, setNotes] = useState(note.notes);
  const [treeModalOpen, setTreeModalOpen] = useState(false);
  const [selectedStroke, setSelectedStroke] = useState<{ id: string; name: string } | null>(null);

  const handleAddGoal = (goal: Omit<Goal, 'id' | 'createdAt' | 'updatedAt'>) => {
    const newGoal: Goal = {
      ...goal,
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    setGoals([...goals, newGoal]);
  };

  const handleStatusChange = (goalId: string, status: GoalStatus) => {
    setGoals(goals.map(g => g.id === goalId ? { ...g, status, updatedAt: new Date().toISOString() } : g));
  };

  const handleDeleteGoal = (goalId: string) => {
    setGoals(goals.filter(g => g.id !== goalId));
  };

  const handleMetricChange = (goalId: string, metricId: string, value: number) => {
    setGoals(goals.map(g => {
      if (g.id === goalId && g.metrics) {
        return {
          ...g,
          metrics: {
            ...g.metrics,
            [metricId]: {
              ...g.metrics[metricId],
              actual: value,
            },
          },
          updatedAt: new Date().toISOString(),
        };
      }
      return g;
    }));
  };

  const handleSave = () => {
    onSave({
      ...note,
      strokeFocus,
      techniqueFocus,
      goals,
      notes,
      updatedAt: new Date().toISOString(),
    });
  };

  const toggleStroke = (strokeId: StrokeId) => {
    setStrokeFocus(prev =>
      prev.includes(strokeId) ? prev.filter(s => s !== strokeId) : [...prev, strokeId]
    );
  };

  const toggleTechnique = (techniqueId: TechniqueId) => {
    setTechniqueFocus(prev =>
      prev.includes(techniqueId) ? prev.filter(t => t !== techniqueId) : [...prev, techniqueId]
    );
  };

  const openTreeModal = (stroke: { id: string; name: string }) => {
    setSelectedStroke(stroke);
    setTreeModalOpen(true);
  };

  const handleSelectTreeNode = (node: TechniqueTreeNode) => {
    // Add node as a goal
    const newGoal: Goal = {
      id: `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'technique',
      target: node.techniqueId,
      description: node.name,
      techniqueNodeId: node.id,
      revisit: node.revisit,
      metrics: node.metrics ? Object.fromEntries(node.metrics.map(m => [m.id, { unit: m.unit }])) : undefined,
      status: 'planned',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    setGoals([...goals, newGoal]);
    setTreeModalOpen(false);
  };

  return (
    <div className="space-y-6">
      {/* Technique Tree Modal */}
      {selectedStroke && (
        <TechniqueTreeModal
          strokeId={selectedStroke.id}
          strokeName={selectedStroke.name}
          isOpen={treeModalOpen}
          onClose={() => setTreeModalOpen(false)}
          onSelectNode={handleSelectTreeNode}
        />
      )}

      {/* Stroke Focus */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Stroke Focus</label>
        <p className="text-xs text-gray-500 mb-2">Click a stroke to see technique tree</p>
        <div className="flex flex-wrap gap-2">
          {strokes.map((stroke) => (
            <button
              key={stroke.id}
              onClick={() => openTreeModal(stroke)}
              className={`px-3 py-1.5 rounded-full text-sm font-medium transition ${
                strokeFocus.includes(stroke.id as StrokeId)
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {stroke.name} 🌳
            </button>
          ))}
        </div>
      </div>

      {/* Technique Focus */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Technique Focus</label>
        <div className="flex flex-wrap gap-2">
          {techniques.map((tech) => (
            <button
              key={tech.id}
              onClick={() => toggleTechnique(tech.id as TechniqueId)}
              className={`px-3 py-1.5 rounded-full text-sm font-medium transition ${
                techniqueFocus.includes(tech.id as TechniqueId)
                  ? 'bg-green-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {tech.name}
            </button>
          ))}
        </div>
      </div>

      {/* Goals */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Goals</label>
        <GoalList
          goals={goals}
          strokes={strokes}
          techniques={techniques}
          onStatusChange={handleStatusChange}
          onDelete={handleDeleteGoal}
          onMetricChange={handleMetricChange}
        />
        <div className="mt-4">
          <GoalInput strokes={strokes} techniques={techniques} onAddGoal={handleAddGoal} />
        </div>
        {onRequestSuggestions && (
          <div className="mt-3">
            <button
              onClick={onRequestSuggestions}
              disabled={isLoadingSuggestions}
              className="text-sm text-purple-600 hover:text-purple-800 disabled:text-gray-400"
            >
              {isLoadingSuggestions ? 'Loading suggestions...' : 'Get AI goal suggestions'}
            </button>
            {suggestions && (
              <div className="mt-2 p-3 bg-purple-50 rounded-lg text-sm text-gray-700">
                {suggestions}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Notes */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Notes</label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="What happened during training? What did you notice?"
          rows={4}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm resize-none"
        />
      </div>

      {/* Actions */}
      <div className="flex gap-3">
        <button
          onClick={handleSave}
          className="bg-blue-600 text-white rounded-md px-6 py-2 text-sm font-medium hover:bg-blue-700"
        >
          Save Note
        </button>
      </div>
    </div>
  );
}