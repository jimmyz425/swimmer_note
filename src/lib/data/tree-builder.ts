import fs from 'fs';
import path from 'path';
import { TechniqueTree, TechniqueTreeNode, StrokeId } from '@/lib/types';
import { parseTechniqueFile, listTechniqueFiles, getMarkdownDir } from './markdown-parser';
import { getTechniqueTree, saveTechniqueTree } from './trees';

const STROKE_ABBREVS: Record<string, string> = {
  freestyle: 'free',
  backstroke: 'back',
  breaststroke: 'breast',
  butterfly: 'fly',
};

/**
 * Build a technique tree from markdown files for a given stroke
 */
export function buildTreeFromMarkdown(strokeId: StrokeId): TechniqueTree {
  const techniqueFiles = listTechniqueFiles(strokeId);
  const nodes: TechniqueTreeNode[] = [];
  const rootNodes: string[] = [];

  for (const filename of techniqueFiles) {
    const parsed = parseTechniqueFile(filename);

    if (!parsed) continue;

    // Generate node ID from filename
    const nodeId = generateNodeId(strokeId, filename);

    // Level from file sequence number (01 = level 1)
    const level = extractLevelFromFilename(filename);

    // Create node
    const node: TechniqueTreeNode = {
      id: nodeId,
      techniqueId: mapToTechniqueId(filename),
      level,
      name: parsed.title.split(' — ')[1] || parsed.title.split(' -- ')[1] || parsed.title,
      description: parsed.overview.split('\n')[0].replace(/\*\*Difficulty:[^*]*\*\*/g, '').trim(),
      revisit: level === 1, // Foundational techniques should be revisited
      prerequisites: extractPrerequisites(parsed, strokeId),
      children: [],
      sourceFile: filename,
    };

    nodes.push(node);

    // First file is a root node
    if (level === 1) {
      rootNodes.push(nodeId);
    }
  }

  // Link nodes based on prerequisites and sequence
  linkNodes(nodes, strokeId);

  const tree: TechniqueTree = {
    strokeId,
    name: `${capitalize(strokeId)} Technique Tree`,
    generatedAt: new Date().toISOString(),
    customized: false,
    nodes,
    rootNodes,
  };

  return tree;
}

/**
 * Generate a unique node ID from stroke and filename
 */
function generateNodeId(strokeId: string, filename: string): string {
  const abbrev = STROKE_ABBREVS[strokeId] || strokeId.slice(0, 4);
  // Extract slug from filename (e.g., "freestyle-01-body-position" -> "body_position")
  const slugMatch = filename.match(/\d+-(.+)$/);
  const slug = slugMatch ? slugMatch[1].replace(/-/g, '_') : filename;
  return `${abbrev}_${slug}`;
}

/**
 * Extract level from filename sequence number
 */
function extractLevelFromFilename(filename: string): number {
  const numMatch = filename.match(/-(\d+)-/);
  return numMatch ? parseInt(numMatch[1]) : 1;
}

/**
 * Map filename to a known TechniqueId if possible
 */
function mapToTechniqueId(filename: string): string {
  const slugMatch = filename.match(/\d+-(.+)$/);
  const slug = slugMatch ? slugMatch[1] : filename;

  // Map common slugs to TechniqueIds
  const mappings: Record<string, string> = {
    'body-position': 'body_position',
    'body-position-horizontal-alignment': 'body_position',
    'flutter-kick': 'flutter_kick',
    'dolphin-kick-mechanics': 'dolphin_kicks',
    'kick-mechanics-whip-kick': 'breaststroke_kick',
    'breathing-technique': 'breathing',
    'breathing-coordination': 'breathing',
    'breathing': 'breathing',
    'breathing-timing': 'breathing',
    'catch-evf': 'catch',
    'arm-entry-catch': 'catch',
    'arm-stroke-catch': 'catch',
    'pull-phase': 'pull',
    'arm-pull-phases': 'pull',
    'arm-pull-push': 'pull',
    'arm-stroke-pull-push': 'pull',
    'arm-recovery': 'recovery',
    'arm-stroke-recovery': 'recovery',
    'body-rotation': 'body_position',
    'stroke-timing-coordination': 'body_position',
    'timing-gliding': 'body_position',
    'timing-rhythm-two-kick': 'body_position',
    'whole-body-coordination': 'body_position',
    'starts-turns': 'start',
    'streamline': 'streamline',
  };

  return mappings[slug] || slug.replace(/-/g, '_');
}

/**
 * Extract prerequisite node IDs from related techniques
 */
function extractPrerequisites(parsed: { relatedTechniques: string[] }, strokeId: string): string[] {
  // For level 1, no prerequisites
  // For higher levels, related techniques with lower sequence numbers could be prerequisites
  // Simplified approach: no explicit prerequisites for now
  return [];
}

/**
 * Link nodes: add children based on sequence ordering
 */
function linkNodes(nodes: TechniqueTreeNode[], strokeId: string): void {
  // Sort nodes by level
  const sortedNodes = [...nodes].sort((a, b) => a.level - b.level);

  // Each node's next file becomes its "suggested next" in the tree
  // We add the next node as a child of the previous one for flowchart continuity
  for (let i = 0; i < sortedNodes.length - 1; i++) {
    const currentNode = sortedNodes[i];
    const nextNode = sortedNodes[i + 1];

    // Only add if levels are close (sequential progression)
    if (nextNode.level === currentNode.level + 1 || nextNode.level === currentNode.level) {
      currentNode.children.push(nextNode.id);
    }
  }
}

/**
 * Capitalize first letter
 */
function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Rebuild a technique tree from markdown and save it
 */
export function rebuildTreeFromMarkdown(strokeId: StrokeId): TechniqueTree {
  const tree = buildTreeFromMarkdown(strokeId);
  saveTechniqueTree(tree);
  return tree;
}

/**
 * Rebuild all technique trees from markdown
 */
export function rebuildAllTrees(): TechniqueTree[] {
  const strokes: StrokeId[] = ['freestyle', 'backstroke', 'breaststroke', 'butterfly'];
  const trees: TechniqueTree[] = [];

  for (const strokeId of strokes) {
    const tree = rebuildTreeFromMarkdown(strokeId);
    trees.push(tree);
  }

  return trees;
}

/**
 * Update existing tree with sourceFile references (preserve customizations)
 */
export function updateTreeWithSourceFiles(strokeId: StrokeId): TechniqueTree | null {
  const existingTree = getTechniqueTree(strokeId);

  if (!existingTree) {
    return buildTreeFromMarkdown(strokeId);
  }

  // If already customized, preserve it but add sourceFile references where possible
  if (existingTree.customized) {
    const techniqueFiles = listTechniqueFiles(strokeId);

    for (const node of existingTree.nodes) {
      // Try to match existing nodes to markdown files
      const matchingFile = findMatchingFile(node, techniqueFiles);
      if (matchingFile && !node.sourceFile) {
        node.sourceFile = matchingFile;
      }
    }

    return existingTree;
  }

  // If not customized, rebuild from markdown
  return buildTreeFromMarkdown(strokeId);
}

/**
 * Find matching markdown file for a node
 */
function findMatchingFile(node: TechniqueTreeNode, files: string[]): string | null {
  // Match by name similarity or techniqueId
  for (const filename of files) {
    const parsed = parseTechniqueFile(filename);
    if (parsed) {
      const parsedName = parsed.title.split(' — ')[1] || parsed.title.split(' -- ')[1] || parsed.title;
      if (node.name.toLowerCase().includes(parsedName.toLowerCase()) ||
          parsedName.toLowerCase().includes(node.name.toLowerCase())) {
        return filename;
      }
    }
  }

  return null;
}