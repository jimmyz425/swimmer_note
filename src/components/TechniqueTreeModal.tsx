'use client';

import { useState, useEffect } from 'react';
import { TechniqueTree, TechniqueTreeNode } from '@/lib/types';
import { TreeNodeWithChildren } from '@/lib/data/trees';

interface TechniqueTreeModalProps {
  strokeId: string;
  strokeName: string;
  isOpen: boolean;
  onClose: () => void;
  onSelectNode: (node: TechniqueTreeNode) => void;
}

export function TechniqueTreeModal({
  strokeId,
  strokeName,
  isOpen,
  onClose,
  onSelectNode,
}: TechniqueTreeModalProps) {
  const [tree, setTree] = useState<TechniqueTree | null>(null);
  const [hierarchy, setHierarchy] = useState<TreeNodeWithChildren[]>([]);
  const [loading, setLoading] = useState(false);
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (isOpen && strokeId) {
      setLoading(true);
      fetch(`/api/trees/${strokeId}`)
        .then(res => res.json())
        .then(data => {
          setTree(data.tree);
          setHierarchy(data.hierarchy);
          // Auto-expand root nodes
          setExpandedNodes(new Set(data.tree.rootNodes));
        })
        .catch(err => console.error('Failed to load tree:', err))
        .finally(() => setLoading(false));
    }
  }, [isOpen, strokeId]);

  const toggleNode = (nodeId: string) => {
    setExpandedNodes(prev => {
      const next = new Set(prev);
      if (next.has(nodeId)) {
        next.delete(nodeId);
      } else {
        next.add(nodeId);
      }
      return next;
    });
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
        <div className="p-4 border-b border-gray-200 flex justify-between items-center">
          <h2 className="text-lg font-semibold">{strokeName} Technique Tree</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            ✕
          </button>
        </div>

        <div className="p-4 overflow-y-auto max-h-[60vh]">
          {loading ? (
            <div className="text-center py-8 text-gray-500">Loading tree...</div>
          ) : tree ? (
            <div className="space-y-2">
              {hierarchy.map(rootNode => (
                <TreeNodeComponent
                  key={rootNode.id}
                  node={rootNode}
                  level={0}
                  expandedNodes={expandedNodes}
                  onToggle={toggleNode}
                  onSelect={onSelectNode}
                />
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">No tree found</div>
          )}
        </div>

        <div className="p-4 border-t border-gray-200 bg-gray-50">
          <p className="text-sm text-gray-600">
            Click on a technique to add it as a goal. <span className="text-orange-600">🔄</span> = revisit regularly.
          </p>
        </div>
      </div>
    </div>
  );
}

interface TreeNodeComponentProps {
  node: TreeNodeWithChildren;
  level: number;
  expandedNodes: Set<string>;
  onToggle: (nodeId: string) => void;
  onSelect: (node: TechniqueTreeNode) => void;
}

function TreeNodeComponent({
  node,
  level,
  expandedNodes,
  onToggle,
  onSelect,
}: TreeNodeComponentProps) {
  const isExpanded = expandedNodes.has(node.id);
  const hasChildren = node.childNodes.length > 0;

  const levelColors = [
    'bg-green-100 border-green-300',
    'bg-blue-100 border-blue-300',
    'bg-yellow-100 border-yellow-300',
    'bg-orange-100 border-orange-300',
    'bg-red-100 border-red-300',
    'bg-purple-100 border-purple-300',
    'bg-pink-100 border-pink-300',
    'bg-indigo-100 border-indigo-300',
  ];

  const bgColor = levelColors[Math.min(node.level - 1, levelColors.length - 1)];

  return (
    <div className={`${level > 0 ? 'ml-6 pl-4 border-l-2 border-gray-200' : ''}`}>
      <div
        className={`p-3 rounded-lg border ${bgColor} cursor-pointer hover:shadow-md transition`}
        onClick={() => onSelect(node)}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {hasChildren && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onToggle(node.id);
                }}
                className="text-gray-400 hover:text-gray-600 w-5"
              >
                {isExpanded ? '▼' : '▶'}
              </button>
            )}
            <span className="font-medium text-gray-800">{node.name}</span>
            {node.revisit && (
              <span className="text-orange-600 text-sm" title="Revisit regularly">🔄</span>
            )}
          </div>
          <span className="text-xs text-gray-500 bg-white px-2 py-0.5 rounded">Lv.{node.level}</span>
        </div>
        <p className="text-sm text-gray-600 mt-1">{node.description}</p>
        {node.metrics && node.metrics.length > 0 && (
          <div className="mt-2 flex gap-2">
            {node.metrics.map(m => (
              <span key={m.id} className="text-xs bg-gray-200 px-2 py-0.5 rounded">
                {m.name} ({m.unit})
              </span>
            ))}
          </div>
        )}
      </div>

      {hasChildren && isExpanded && (
        <div className="mt-2 space-y-2">
          {node.childNodes.map(child => (
            <TreeNodeComponent
              key={child.id}
              node={child}
              level={level + 1}
              expandedNodes={expandedNodes}
              onToggle={onToggle}
              onSelect={onSelect}
            />
          ))}
        </div>
      )}
    </div>
  );
}