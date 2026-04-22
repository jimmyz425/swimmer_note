import fs from 'fs';
import path from 'path';
import { TrainingNote, Goal } from '../types';

const DATA_DIR = path.join(process.cwd(), 'data');
const NOTES_DIR = path.join(DATA_DIR, 'notes');

function ensureNotesDir(): void {
  if (!fs.existsSync(NOTES_DIR)) {
    fs.mkdirSync(NOTES_DIR, { recursive: true });
  }
}

function getNoteFilePath(date: string): string {
  return path.join(NOTES_DIR, `${date}.json`);
}

function generateGoalId(): string {
  return `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

export function getNote(date: string): TrainingNote | null {
  try {
    const filePath = getNoteFilePath(date);
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf-8');
      return JSON.parse(content) as TrainingNote;
    }
    return null;
  } catch (error) {
    console.error(`Error reading note for ${date}:`, error);
    return null;
  }
}

export function getTodayNote(): TrainingNote | null {
  const today = new Date().toISOString().split('T')[0];
  return getNote(today);
}

export function saveNote(note: TrainingNote): TrainingNote {
  ensureNotesDir();
  const filePath = getNoteFilePath(note.date);

  const now = new Date().toISOString();
  const existingNote = getNote(note.date);

  const updatedNote: TrainingNote = {
    ...note,
    createdAt: existingNote?.createdAt || now,
    updatedAt: now,
    goals: note.goals.map(g => ({
      ...g,
      createdAt: g.createdAt || now,
      updatedAt: now,
    })),
  };

  fs.writeFileSync(filePath, JSON.stringify(updatedNote, null, 2), 'utf-8');
  return updatedNote;
}

export function createEmptyNote(date?: string): TrainingNote {
  const noteDate = date || new Date().toISOString().split('T')[0];
  const now = new Date().toISOString();

  return {
    date: noteDate,
    strokeFocus: [],
    techniqueFocus: [],
    goals: [],
    notes: '',
    createdAt: now,
    updatedAt: now,
  };
}

export function addGoalToNote(date: string, goal: Omit<Goal, 'id' | 'createdAt' | 'updatedAt'>): TrainingNote | null {
  const note = getNote(date);
  if (!note) {
    const newNote = createEmptyNote(date);
    const newGoal: Goal = {
      ...goal,
      id: generateGoalId(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    newNote.goals.push(newGoal);
    return saveNote(newNote);
  }

  const newGoal: Goal = {
    ...goal,
    id: generateGoalId(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  note.goals.push(newGoal);
  return saveNote(note);
}

export function updateGoalStatus(date: string, goalId: string, status: Goal['status']): TrainingNote | null {
  const note = getNote(date);
  if (!note) return null;

  const goalIndex = note.goals.findIndex(g => g.id === goalId);
  if (goalIndex === -1) return null;

  note.goals[goalIndex].status = status;
  note.goals[goalIndex].updatedAt = new Date().toISOString();
  return saveNote(note);
}

export function getAllNotes(): TrainingNote[] {
  try {
    ensureNotesDir();
    const files = fs.readdirSync(NOTES_DIR).filter(f => f.endsWith('.json'));

    const notes: TrainingNote[] = [];
    for (const file of files) {
      const content = fs.readFileSync(path.join(NOTES_DIR, file), 'utf-8');
      try {
        notes.push(JSON.parse(content) as TrainingNote);
      } catch {
        console.error(`Error parsing ${file}`);
      }
    }

    // Sort by date descending (most recent first)
    return notes.sort((a, b) => b.date.localeCompare(a.date));
  } catch (error) {
    console.error('Error reading all notes:', error);
    return [];
  }
}

export function getRecentNotes(days: number = 14): TrainingNote[] {
  const notes = getAllNotes();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffStr = cutoff.toISOString().split('T')[0];

  return notes.filter(n => n.date >= cutoffStr);
}

export function deleteNote(date: string): boolean {
  try {
    const filePath = getNoteFilePath(date);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    }
    return false;
  } catch (error) {
    console.error(`Error deleting note for ${date}:`, error);
    return false;
  }
}