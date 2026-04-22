import fs from 'fs';
import path from 'path';
import { TechniqueTree, TechniqueTreeNode, StrokeId } from '../types';

const DATA_DIR = path.join(process.cwd(), 'data');
const TREES_DIR = path.join(DATA_DIR, 'config', 'technique_trees');

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

export function getTechniqueTree(strokeId: StrokeId | 'master'): TechniqueTree | null {
  const filePath = path.join(TREES_DIR, `${strokeId}.json`);
  return readJsonFile<TechniqueTree | null>(filePath, null);
}

export function getAllTechniqueTrees(): TechniqueTree[] {
  try {
    if (!fs.existsSync(TREES_DIR)) {
      return [];
    }

    const files = fs.readdirSync(TREES_DIR).filter(f => f.endsWith('.json'));
    const trees: TechniqueTree[] = [];

    for (const file of files) {
      const content = fs.readFileSync(path.join(TREES_DIR, file), 'utf-8');
      try {
        trees.push(JSON.parse(content) as TechniqueTree);
      } catch {
        console.error(`Error parsing ${file}`);
      }
    }

    return trees;
  } catch (error) {
    console.error('Error reading technique trees:', error);
    return [];
  }
}

export function getTreeNode(tree: TechniqueTree, nodeId: string): TechniqueTreeNode | null {
  return tree.nodes.find(n => n.id === nodeId) || null;
}

export function getTreeNodesByLevel(tree: TechniqueTree, level: number): TechniqueTreeNode[] {
  return tree.nodes.filter(n => n.level === level);
}

export function getRevisitNodes(tree: TechniqueTree): TechniqueTreeNode[] {
  return tree.nodes.filter(n => n.revisit);
}

export function getChildNodes(tree: TechniqueTree, node: TechniqueTreeNode): TechniqueTreeNode[] {
  return node.children.map(id => getTreeNode(tree, id)).filter((n): n is TechniqueTreeNode => n !== null);
}

export function getPrerequisiteNodes(tree: TechniqueTree, node: TechniqueTreeNode): TechniqueTreeNode[] {
  return node.prerequisites.map(id => getTreeNode(tree, id)).filter((n): n is TechniqueTreeNode => n !== null);
}

export function saveTechniqueTree(tree: TechniqueTree): TechniqueTree {
  if (!fs.existsSync(TREES_DIR)) {
    fs.mkdirSync(TREES_DIR, { recursive: true });
  }

  const filePath = path.join(TREES_DIR, `${tree.strokeId}.json`);
  fs.writeFileSync(filePath, JSON.stringify(tree, null, 2), 'utf-8');

  return tree;
}

export function getMaxLevel(tree: TechniqueTree): number {
  return Math.max(...tree.nodes.map(n => n.level), 0);
}

// Build tree structure for rendering
export interface TreeNodeWithChildren extends TechniqueTreeNode {
  childNodes: TreeNodeWithChildren[];
  prerequisiteNodes: TechniqueTreeNode[];
}

export function buildTreeHierarchy(tree: TechniqueTree): TreeNodeWithChildren[] {
  const nodeMap = new Map<string, TreeNodeWithChildren>();

  // First pass: create all nodes with empty children
  for (const node of tree.nodes) {
    nodeMap.set(node.id, {
      ...node,
      childNodes: [],
      prerequisiteNodes: getPrerequisiteNodes(tree, node),
    });
  }

  // Second pass: link children
  for (const node of tree.nodes) {
    const nodeWithChildren = nodeMap.get(node.id)!;
    for (const childId of node.children) {
      const childNode = nodeMap.get(childId);
      if (childNode) {
        nodeWithChildren.childNodes.push(childNode);
      }
    }
  }

  // Return root nodes
  return tree.rootNodes.map(id => nodeMap.get(id)).filter((n): n is TreeNodeWithChildren => n !== undefined);
}