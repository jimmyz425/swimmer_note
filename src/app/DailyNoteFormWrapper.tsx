'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { TrainingNote } from '@/lib/types';
import { GoalList } from '@/components/GoalList';
import { Loader2, AlertCircle, CheckCircle2 } from 'lucide-react';

interface DailyNoteFormWrapperProps {
  initialNote: TrainingNote;
  strokes?: { id: string; name: string }[];
}

// Deep compare goals (excluding timestamps for comparison)
function goalsContentEqual(a: TrainingNote['goals'], b: TrainingNote['goals']): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    const ga = a[i];
    const gb = b[i];
    if (ga.id !== gb.id || ga.status !== gb.status || ga.description !== gb.description) return false;
    if (ga.coachingTips !== gb.coachingTips || ga.notes !== gb.notes) return false;
    // Compare metrics if present
    if (ga.metrics && gb.metrics) {
      const maKeys = Object.keys(ga.metrics);
      const mbKeys = Object.keys(gb.metrics);
      if (maKeys.length !== mbKeys.length) return false;
      for (const key of maKeys) {
        if (ga.metrics[key].actual !== gb.metrics[key]?.actual) return false;
      }
    }
  }
  return true;
}

export function DailyNoteFormWrapper({ initialNote, strokes = [] }: DailyNoteFormWrapperProps) {
  const [note, setNote] = useState<TrainingNote>(initialNote);
  const [saving, setSaving] = useState(false);
  const [pendingSave, setPendingSave] = useState(false);
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const saveTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const isInitialMount = useRef(true);
  const noteRef = useRef<TrainingNote>(note);
  const lastSavedGoalsRef = useRef<TrainingNote['goals']>(initialNote.goals);

  // Keep noteRef synced with note state
  useEffect(() => {
    noteRef.current = note;
  }, [note]);

  const saveNote = useCallback(async () => {
    setSaving(true);

    try {
      const res = await fetch(`/api/notes/${noteRef.current.date}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...noteRef.current,
          updatedAt: new Date().toISOString(),
        }),
      });

      if (res.ok) {
        const data = await res.json();
        setNote(data.note);
        setLastSaved(new Date());
        setPendingSave(false);
        // Update lastSavedGoalsRef to match what we just saved
        lastSavedGoalsRef.current = data.note.goals;
      } else {
        console.error('Save failed:', res.status, res.statusText);
      }
    } catch (err) {
      console.error('Failed to save:', err);
    } finally {
      setSaving(false);
    }
  }, []); // No dependencies - uses ref instead

  // Auto-save with debounce when goals change
  // 3 second delay to avoid saving on every keystroke
  useEffect(() => {
    // Skip on initial mount - initialNote is already saved
    if (isInitialMount.current) {
      isInitialMount.current = false;
      return;
    }

    // Check if goals actually changed (excluding timestamps)
    if (goalsContentEqual(note.goals, lastSavedGoalsRef.current)) {
      // Goals haven't actually changed, just timestamps - don't save
      return;
    }

    // Mark that there's a pending save
    setPendingSave(true);

    // Clear pending save
    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }

    // Debounce: wait 3 seconds before saving
    saveTimeoutRef.current = setTimeout(() => {
      saveNote();
    }, 3000);

    // Cleanup on unmount
    return () => {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
    };
  }, [note.goals, saveNote]);

  const handleStatusChange = async (goalId: string, status: 'pending' | 'in_progress' | 'completed' | 'abandoned') => {
    const updatedGoals = note.goals.map(g =>
      g.id === goalId ? { ...g, status, updatedAt: new Date().toISOString() } : g
    );
    setNote({ ...note, goals: updatedGoals });
  };

  const handleDeleteGoal = (goalId: string) => {
    setNote({ ...note, goals: note.goals.filter(g => g.id !== goalId) });
  };

  const handleMetricChange = (goalId: string, metricId: string, value: number) => {
    const updatedGoals = note.goals.map(g => {
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
    });
    setNote({ ...note, goals: updatedGoals });
  };

  const handleGenerateTips = async (goalId: string): Promise<string> => {
    const goal = note.goals.find(g => g.id === goalId);
    if (!goal) return 'Goal not found';

    const res = await fetch('/api/goal-tips', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        goalId,
        date: note.date,
        techniqueNodeId: goal.techniqueNodeId,
        goalDescription: goal.description,
      }),
    });

    const data = await res.json();
    return data.tips;
  };

  const handleUpdateTips = (goalId: string, tips: string) => {
    const updatedGoals = note.goals.map(g =>
      g.id === goalId ? { ...g, coachingTips: tips, updatedAt: new Date().toISOString() } : g
    );
    setNote({ ...note, goals: updatedGoals });
  };

  const handleNotesChange = (goalId: string, notes: string) => {
    const updatedGoals = note.goals.map(g =>
      g.id === goalId ? { ...g, notes, updatedAt: new Date().toISOString() } : g
    );
    setNote({ ...note, goals: updatedGoals });
  };

  return (
    <div>
      {/* Status indicator */}
      <div className="mb-5 flex items-center gap-3">
        {saving ? (
          <div className="flex items-center gap-2 bg-pool-surface/80 px-3 py-2 rounded-xl border border-pool-light/50">
            <Loader2 className="w-4 h-4 text-pool-mid animate-spin" />
            <span className="text-sm font-semibold text-pool-deep">Saving...</span>
          </div>
        ) : pendingSave ? (
          <div className="flex items-center gap-2 bg-amber-50 px-3 py-2 rounded-xl border border-amber-200">
            <AlertCircle className="w-4 h-4 text-amber-500" />
            <span className="text-sm font-semibold text-amber-700">Unsaved changes</span>
          </div>
        ) : lastSaved ? (
          <div className="flex items-center gap-2 bg-emerald-50/80 px-3 py-2 rounded-xl border border-emerald-200/50">
            <CheckCircle2 className="w-4 h-4 text-emerald-500" />
            <span className="text-sm font-semibold text-emerald-700">
              Saved {lastSaved.toLocaleTimeString()}
            </span>
          </div>
        ) : null}
      </div>

      {/* Goals */}
      <GoalList
        goals={note.goals}
        strokes={strokes}
        techniques={[]}
        onStatusChange={handleStatusChange}
        onDelete={handleDeleteGoal}
        onMetricChange={handleMetricChange}
        onNotesChange={handleNotesChange}
        onGenerateTips={handleGenerateTips}
        onUpdateTips={handleUpdateTips}
      />
    </div>
  );
}