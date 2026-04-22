import fs from 'fs';
import path from 'path';
import { ActiveGoals, Goal } from '../types';

const DATA_DIR = path.join(process.cwd(), 'data');
const GOALS_DIR = path.join(DATA_DIR, 'goals');
const ACTIVE_GOALS_FILE = path.join(GOALS_DIR, 'active.json');

function ensureGoalsDir(): void {
  if (!fs.existsSync(GOALS_DIR)) {
    fs.mkdirSync(GOALS_DIR, { recursive: true });
  }
}

function generateGoalId(): string {
  return `goal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

function readActiveGoals(): ActiveGoals {
  try {
    if (fs.existsSync(ACTIVE_GOALS_FILE)) {
      const content = fs.readFileSync(ACTIVE_GOALS_FILE, 'utf-8');
      return JSON.parse(content) as ActiveGoals;
    }
    return { activeGoals: [], lastUpdated: null };
  } catch (error) {
    console.error('Error reading active goals:', error);
    return { activeGoals: [], lastUpdated: null };
  }
}

function writeActiveGoals(goals: ActiveGoals): void {
  ensureGoalsDir();
  fs.writeFileSync(ACTIVE_GOALS_FILE, JSON.stringify(goals, null, 2), 'utf-8');
}

export function getActiveGoals(): Goal[] {
  return readActiveGoals().activeGoals;
}

export function addActiveGoal(goal: Omit<Goal, 'id' | 'createdAt' | 'updatedAt'>): Goal {
  const activeGoals = readActiveGoals();
  const now = new Date().toISOString();

  const newGoal: Goal = {
    ...goal,
    id: generateGoalId(),
    createdAt: now,
    updatedAt: now,
  };

  activeGoals.activeGoals.push(newGoal);
  activeGoals.lastUpdated = now;
  writeActiveGoals(activeGoals);

  return newGoal;
}

export function updateActiveGoal(goalId: string, updates: Partial<Goal>): Goal | null {
  const activeGoals = readActiveGoals();
  const goalIndex = activeGoals.activeGoals.findIndex(g => g.id === goalId);

  if (goalIndex === -1) return null;

  const now = new Date().toISOString();
  activeGoals.activeGoals[goalIndex] = {
    ...activeGoals.activeGoals[goalIndex],
    ...updates,
    updatedAt: now,
  };
  activeGoals.lastUpdated = now;
  writeActiveGoals(activeGoals);

  return activeGoals.activeGoals[goalIndex];
}

export function removeActiveGoal(goalId: string): boolean {
  const activeGoals = readActiveGoals();
  const goalIndex = activeGoals.activeGoals.findIndex(g => g.id === goalId);

  if (goalIndex === -1) return false;

  activeGoals.activeGoals.splice(goalIndex, 1);
  activeGoals.lastUpdated = new Date().toISOString();
  writeActiveGoals(activeGoals);

  return true;
}

export function clearActiveGoals(): void {
  writeActiveGoals({
    activeGoals: [],
    lastUpdated: new Date().toISOString(),
  });
}

export function getGoalsByType(type: Goal['type']): Goal[] {
  return getActiveGoals().filter(g => g.type === type);
}

export function getGoalsByStatus(status: Goal['status']): Goal[] {
  return getActiveGoals().filter(g => g.status === status);
}