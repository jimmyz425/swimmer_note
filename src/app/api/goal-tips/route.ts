import { NextRequest, NextResponse } from 'next/server';
import { getTechniqueTree } from '@/lib/data/trees';
import { getNodeById } from '@/lib/treeToMermaid';
import { generateCoachingTips } from '@/lib/llm/coaching';
import { getLLMConfig } from '@/lib/llm/config';
import { callAnthropic } from '@/lib/llm/anthropic';
import { callOpenAI } from '@/lib/llm/openai';

export async function POST(request: NextRequest) {
  const config = getLLMConfig();

  if (!config) {
    return NextResponse.json({
      tips: 'LLM not configured. Add API key in .env to get personalized coaching tips.',
    });
  }

  try {
    const body = await request.json();
    const { goalId, techniqueNodeId, goalDescription } = body;

    // Try to find the technique node from the tree
    let node = null;

    if (techniqueNodeId) {
      // Try to find in any tree
      const trees = ['freestyle', 'backstroke', 'breaststroke', 'butterfly', 'master'];
      for (const strokeId of trees) {
        const tree = getTechniqueTree(strokeId as 'freestyle' | 'backstroke' | 'breaststroke' | 'butterfly' | 'master');
        if (tree) {
          node = getNodeById(tree, techniqueNodeId);
          if (node) break;
        }
      }
    }

    // If node found, use detailed coaching
    if (node) {
      const tips = await generateCoachingTips(node);
      return NextResponse.json({ tips });
    }

    // Otherwise, generate tips based on goal description
    const prompt = `You are an expert swimming coach. A swimmer wants to focus on: "${goalDescription}".

Give 3-4 bullet-point tips. Each bullet must be ONE short sentence (max 10 words).
Focus on: body position, timing, or common mistake to avoid.

Output ONLY bullets, no intro/outro. Format:
• Tip one
• Tip two
• Tip three`;

    let tips: string;
    if (config.provider === 'anthropic') {
      tips = await callAnthropic(prompt, config);
    } else {
      tips = await callOpenAI(prompt, config);
    }

    return NextResponse.json({ tips });
  } catch (error) {
    console.error('Error generating goal tips:', error);
    return NextResponse.json({
      tips: 'Failed to generate coaching tips. Please try again.',
    }, { status: 500 });
  }
}