import { NextRequest, NextResponse } from 'next/server';
import { getTechniqueTree, saveTechniqueTree } from '@/lib/data/trees';
import { TechniqueTreeNode } from '@/lib/types';
import { getLLMConfig } from '@/lib/llm/config';
import { callAnthropic } from '@/lib/llm/anthropic';
import { callOpenAI } from '@/lib/llm/openai';

interface ExpandNodeRequest {
  strokeId: string;
  nodeId: string;
  coachingTips: string;
}

export async function POST(request: NextRequest) {
  const config = getLLMConfig();

  if (!config) {
    return NextResponse.json({
      error: 'LLM not configured. Add API key in .env.',
    }, { status: 400 });
  }

  try {
    const body = await request.json() as ExpandNodeRequest;
    const { strokeId, nodeId, coachingTips } = body;

    // Get existing tree
    const tree = getTechniqueTree(strokeId as 'freestyle' | 'backstroke' | 'breaststroke' | 'butterfly' | 'master');
    if (!tree) {
      return NextResponse.json({ error: 'Tree not found' }, { status: 404 });
    }

    // Find parent node
    const parentNode = tree.nodes.find(n => n.id === nodeId);
    if (!parentNode) {
      return NextResponse.json({ error: 'Node not found' }, { status: 404 });
    }

    // Use LLM to extract sub-nodes from coaching tips
    const prompt = `You are an expert swimming coach. Given these coaching tips for "${parentNode.name}":

${coachingTips}

Extract 3-5 specific focus points that could become separate practice sub-goals. Each should be:
- A specific, actionable technique element
- Something that can be practiced independently
- Progressing from easier to harder

Output ONLY a JSON array of objects with this exact format:
[
  {"name": "Focus point name", "description": "Brief description", "revisit": true/false}
]

No intro/outro text, just the JSON array.`;

    let response: string;
    if (config.provider === 'anthropic') {
      response = await callAnthropic(prompt, config);
    } else {
      response = await callOpenAI(prompt, config);
    }

    // Parse LLM response
    let subNodes: Array<{ name: string; description: string; revisit: boolean }>;
    try {
      // Extract JSON from response (handle markdown code blocks)
      const jsonMatch = response.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        subNodes = JSON.parse(jsonMatch[0]);
      } else {
        subNodes = JSON.parse(response);
      }
    } catch {
      return NextResponse.json({
        error: 'Failed to parse LLM response',
        rawResponse: response,
      }, { status: 500 });
    }

    // Create new nodes with dot notation IDs and parent:child naming
    const newNodes: TechniqueTreeNode[] = subNodes.map((sub, index) => ({
      id: `${nodeId}.${index + 1}`,
      techniqueId: parentNode.techniqueId,
      level: parentNode.level + 1,
      name: `${parentNode.name}: ${sub.name}`,
      description: sub.description,
      revisit: sub.revisit,
      prerequisites: [nodeId],
      children: [],
    }));

    // Update parent node to have these as children (preserve existing children)
    const updatedParent: TechniqueTreeNode = {
      ...parentNode,
      children: [...parentNode.children, ...newNodes.map(n => n.id)],
    };

    // Update tree - preserve all existing nodes and relationships
    const updatedTree = {
      ...tree,
      nodes: [
        ...tree.nodes.filter(n => n.id !== nodeId),
        updatedParent,
        ...newNodes,
      ],
      customized: true,
    };

    // Save tree
    saveTechniqueTree(updatedTree);

    return NextResponse.json({
      success: true,
      parentNode: updatedParent,
      newNodes,
      tree: updatedTree,
    });
  } catch (error) {
    console.error('Error expanding node:', error);
    return NextResponse.json({
      error: 'Failed to expand node',
    }, { status: 500 });
  }
}