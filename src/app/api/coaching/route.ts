import { NextRequest, NextResponse } from 'next/server';
import { generateCoachingTips } from '@/lib/llm/coaching';
import { TechniqueTreeNode } from '@/lib/types';
import { isLLMConfigured } from '@/lib/llm/config';

export async function POST(request: NextRequest) {
  if (!isLLMConfigured()) {
    return NextResponse.json({
      tips: 'LLM not configured. Add API key in .env to get personalized coaching tips.',
    });
  }

  try {
    const body = await request.json();
    const node = body.node as TechniqueTreeNode;

    if (!node) {
      return NextResponse.json({ error: 'Node data required' }, { status: 400 });
    }

    const tips = await generateCoachingTips(node);
    return NextResponse.json({ tips });
  } catch (error) {
    console.error('Error generating coaching tips:', error);
    return NextResponse.json({
      tips: 'Failed to generate coaching tips. Please try again.',
    }, { status: 500 });
  }
}