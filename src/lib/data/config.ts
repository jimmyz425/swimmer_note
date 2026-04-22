import fs from 'fs';
import path from 'path';
import { StrokesConfig, TechniquesConfig, Stroke, Technique } from '../types';

const DATA_DIR = path.join(process.cwd(), 'data');
const CONFIG_DIR = path.join(DATA_DIR, 'config');

function readJsonFile<T>(filePath: string, defaultValue: T): T {
  try {
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf-8');
      return JSON.parse(content) as T;
    }
    return defaultValue;
  } catch (error) {
    console.error(`Error reading ${filePath}:`, error);
    return defaultValue;
  }
}

export function getStrokes(): Stroke[] {
  const config = readJsonFile<StrokesConfig>(
    path.join(CONFIG_DIR, 'strokes.json'),
    { strokes: [] }
  );
  return config.strokes;
}

export function getTechniques(): Technique[] {
  const config = readJsonFile<TechniquesConfig>(
    path.join(CONFIG_DIR, 'techniques.json'),
    { techniques: [] }
  );
  return config.techniques;
}

export function getStrokeById(id: string): Stroke | undefined {
  return getStrokes().find(s => s.id === id);
}

export function getTechniqueById(id: string): Technique | undefined {
  return getTechniques().find(t => t.id === id);
}

export function getTechniquesByCategory(category: string): Technique[] {
  return getTechniques().filter(t => t.category === category);
}

export function getAllCategories(): string[] {
  const techniques = getTechniques();
  return [...new Set(techniques.map(t => t.category))];
}