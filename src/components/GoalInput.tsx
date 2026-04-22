'use client';

import { useState } from 'react';
import { Goal, GoalType, GoalStatus } from '@/lib/types';

interface GoalInputProps {
  strokes: { id: string; name: string }[];
  techniques: { id: string; name: string; category: string }[];
  onAddGoal: (goal: Omit<Goal, 'id' | 'createdAt' | 'updatedAt'>) => void;
}

export function GoalInput({ strokes, techniques, onAddGoal }: GoalInputProps) {
  const [type, setType] = useState<GoalType>('general');
  const [target, setTarget] = useState<string>('');
  const [description, setDescription] = useState('');
  const [status, setStatus] = useState<GoalStatus>('pending');

  const strokesData = strokes;
  const techniquesData = techniques;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!description.trim()) return;

    onAddGoal({
      type,
      target: type !== 'general' ? target : undefined,
      description: description.trim(),
      status,
    });

    setDescription('');
    setTarget('');
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-3 p-4 bg-gray-50 rounded-lg">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Goal Type</label>
        <select
          value={type}
          onChange={(e) => setType(e.target.value as GoalType)}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
        >
          <option value="general">General</option>
          <option value="stroke">Stroke-specific</option>
          <option value="technique">Technique-specific</option>
        </select>
      </div>

      {type === 'stroke' && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Stroke</label>
          <select
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
          >
            <option value="">Select stroke...</option>
            {strokesData.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </div>
      )}

      {type === 'technique' && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Technique</label>
          <select
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
          >
            <option value="">Select technique...</option>
            {techniquesData.map((t) => (
              <option key={t.id} value={t.id}>{t.name} ({t.category})</option>
            ))}
          </select>
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
        <input
          type="text"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="What do you want to focus on?"
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Initial Status</label>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as GoalStatus)}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
        >
          <option value="pending">Pending</option>
          <option value="in_progress">In Progress</option>
        </select>
      </div>

      <button
        type="submit"
        disabled={!description.trim() || (type !== 'general' && !target)}
        className="w-full bg-blue-600 text-white rounded-md px-4 py-2 text-sm font-medium hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
      >
        Add Goal
      </button>
    </form>
  );
}