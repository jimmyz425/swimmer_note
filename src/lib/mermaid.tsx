'use client';

import mermaid from 'mermaid';
import { useEffect, useRef, useState } from 'react';

// Initialize mermaid once
let initialized = false;

export function initMermaid() {
  if (!initialized && typeof window !== 'undefined') {
    mermaid.initialize({
      startOnLoad: false,
      theme: 'neutral',
      flowchart: {
        useMaxWidth: true,
        htmlLabels: true,
        curve: 'basis',
      },
      securityLevel: 'loose', // Allow click callbacks
    });
    initialized = true;
  }
}

export interface MermaidRenderResult {
  svg: string;
  bindFunctions: (element: HTMLElement) => void;
}

export function renderMermaid(id: string, code: string): Promise<{ svg: string }> {
  initMermaid();
  return mermaid.render(id, code);
}

export function useMermaid(code: string, id: string = 'mermaid-diagram') {
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!containerRef.current || !code) return;

    initMermaid();

    mermaid.render(`${id}-${Date.now()}`, code)
      .then(({ svg }) => {
        containerRef.current!.innerHTML = svg;
        setError(null);
      })
      .catch((err) => {
        console.error('Mermaid render error:', err);
        setError(err.message);
      });
  }, [code, id]);

  return { containerRef, error };
}

// Client-side component for rendering mermaid
export function MermaidDiagram({ code, onNodeClick }: { code: string; onNodeClick?: (nodeId: string) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current || !code) return;

    initMermaid();

    const renderId = `mermaid-${Math.random().toString(36).substr(2, 9)}`;

    mermaid.render(renderId, code)
      .then(({ svg }) => {
        containerRef.current!.innerHTML = svg;

        // Bind click handlers to nodes
        if (onNodeClick) {
          const nodes = containerRef.current!.querySelectorAll('.node');
          nodes.forEach((node) => {
            const el = node as HTMLElement;
            // Extract node ID from mermaid format: mermaid-{random}-flowchart-{nodeId}-{index}
            const match = el.id.match(/flowchart-(.+)-\d+$/);
            const nodeId = match ? match[1] : el.id;
            el.addEventListener('click', () => onNodeClick(nodeId));
            el.style.cursor = 'pointer';
          });
        }
      })
      .catch((err) => {
        console.error('Mermaid render error:', err);
        containerRef.current!.innerHTML = `<p class="text-red-500">Error rendering diagram</p>`;
      });
  }, [code, onNodeClick]);

  return <div ref={containerRef} className="mermaid-container w-full" />;
}