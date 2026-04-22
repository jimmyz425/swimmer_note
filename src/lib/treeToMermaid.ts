import { TechniqueTree, TechniqueTreeNode } from './types';

export function treeToMermaid(tree: TechniqueTree): string {
  const lines: string[] = ['graph TD'];

  // Build node definitions
  const nodeDefs: string[] = [];
  const connections: string[] = [];
  const classAssignments: string[] = [];

  for (const node of tree.nodes) {
    // Node label with level indicator
    const label = `${node.name}`;
    nodeDefs.push(`    ${node.id}["${label}<br/><small>Lv.${node.level}</small>"]`);

    // Connections to children
    for (const childId of node.children) {
      connections.push(`    ${node.id} --> ${childId}`);
    }

    // Class assignment based on level and revisit
    const classes = [`level${node.level}`];
    if (node.revisit) {
      classes.push('revisit');
    }
    classAssignments.push(`    class ${node.id} ${classes.join(',')}`);
  }

  // Combine all parts
  lines.push(...nodeDefs);
  lines.push(...connections);

  // Add styling
  lines.push('');
  lines.push('    %% Node styling by level');

  const levelColors = [
    { bg: '#90EE90', stroke: '#2E8B57' }, // Level 1: light green
    { bg: '#87CEEB', stroke: '#4682B4' }, // Level 2: sky blue
    { bg: '#FFE4B5', stroke: '#FF8C00' }, // Level 3: moccasin
    { bg: '#FFD700', stroke: '#DAA520' }, // Level 4: gold
    { bg: '#DDA0DD', stroke: '#BA55D3' }, // Level 5: plum
    { bg: '#F0E68C', stroke: '#BDB76B' }, // Level 6: khaki
    { bg: '#E6E6FA', stroke: '#9370DB' }, // Level 7: lavender
    { bg: '#FFB6C1', stroke: '#DB7093' }, // Level 8: light pink
  ];

  for (let i = 1; i <= 8; i++) {
    const color = levelColors[i - 1];
    lines.push(`    classDef level${i} fill:${color.bg},stroke:${color.stroke},stroke-width:2px,color:#333`);
  }

  // Revisit styling (orange border, thicker)
  lines.push('    classDef revisit fill:#FFB347,stroke:#FF8C00,stroke-width:4px,color:#333');

  // Combine class assignments
  lines.push('');
  lines.push('    %% Class assignments');
  lines.push(...classAssignments);

  return lines.join('\n');
}

export function getNodeById(tree: TechniqueTree, nodeId: string): TechniqueTreeNode | null {
  return tree.nodes.find(n => n.id === nodeId) || null;
}

// Generate a simpler linear view for mobile/small screens
export function treeToLinearMermaid(tree: TechniqueTree): string {
  const lines: string[] = ['graph LR'];

  // Sort nodes by level
  const sortedNodes = [...tree.nodes].sort((a, b) => a.level - b.level);

  for (const node of sortedNodes) {
    const label = `${node.level}. ${node.name}`;
    lines.push(`    ${node.id}["${label}"]`);
  }

  // Add connections
  for (const node of sortedNodes) {
    for (const childId of node.children) {
      lines.push(`    ${node.id} --> ${childId}`);
    }
  }

  // Styling
  lines.push('    classDef revisit fill:#FFB347,stroke:#FF8C00,stroke-width:3px');

  for (const node of sortedNodes) {
    if (node.revisit) {
      lines.push(`    class ${node.id} revisit`);
    }
  }

  return lines.join('\n');
}