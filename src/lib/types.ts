// Types for the swimmer training notes app

export type StrokeId = 'freestyle' | 'backstroke' | 'breaststroke' | 'butterfly' | 'im';

export type TechniqueId =
  | 'start'
  | 'dolphin_kicks'
  | 'flutter_kick'
  | 'breaststroke_kick'
  | 'flip_turn'
  | 'open_turn'
  | 'streamline'
  | 'breathing'
  | 'catch'
  | 'pull'
  | 'recovery'
  | 'body_position'
  | 'finish';

export type GoalType = 'general' | 'stroke' | 'technique';

export type GoalStatus = 'pending' | 'in_progress' | 'completed' | 'abandoned';

export interface Stroke {
  id: StrokeId;
  name: string;
  aliases: string[];
}

export interface Technique {
  id: TechniqueId;
  name: string;
  category: string;
  description: string;
}

export interface Goal {
  id: string;
  type: GoalType;
  target?: string; // stroke ID or technique ID if type is specific
  strokeId?: string; // Which stroke tree this goal came from (freestyle, backstroke, master, etc.)
  description: string;
  status: GoalStatus;
  revisit?: boolean; // Flag for techniques to revisit regularly
  metrics?: Record<string, MetricValue>; // Quantifiable progress metrics
  techniqueNodeId?: string; // Reference to technique tree node
  coachingTips?: string; // LLM-generated coaching tips
  notes?: string; // Goal-specific notes from training
  createdAt: string;
  updatedAt: string;
}

export interface MetricValue {
  target?: number;
  actual?: number;
  previousBest?: number;
  unit: string; // e.g., "seconds", "count", "meters"
}

export interface MetricDefinition {
  id: string;
  name: string;
  unit: string;
  description: string;
}

export interface TrainingNote {
  date: string; // YYYY-MM-DD format
  strokeFocus: StrokeId[];
  techniqueFocus: TechniqueId[];
  goals: Goal[];
  notes: string;
  llmInsights?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ActiveGoals {
  activeGoals: Goal[];
  lastUpdated: string | null;
}

export interface StrokesConfig {
  strokes: Stroke[];
}

export interface TechniquesConfig {
  techniques: Technique[];
}

// Technique Tree Types

export interface TechniqueTreeNode {
  id: string;
  techniqueId: TechniqueId | string;
  level: number; // Difficulty level (1 = easiest)
  name: string;
  description: string;
  revisit: boolean; // Flag for repetitive practice
  metrics?: MetricDefinition[]; // Metrics for this node
  prerequisites: string[]; // IDs of prerequisite nodes
  children: string[]; // IDs of child nodes (branches)
}

export interface TechniqueTree {
  strokeId: StrokeId | 'master'; // 'master' for unified tree
  name: string;
  generatedAt: string;
  customized: boolean;
  nodes: TechniqueTreeNode[];
  rootNodes: string[]; // IDs of starting nodes
}

export interface TechniqueTreeConfig {
  trees: TechniqueTree[];
}