import { callAnthropic } from './anthropic';
import { callOpenAI } from './openai';
import { getLLMConfig } from './config';
import { TechniqueTreeNode } from '../types';

export async function generateCoachingTips(node: TechniqueTreeNode): Promise<string> {
  const config = getLLMConfig();
  if (!config) {
    return 'LLM not configured. Add API key in .env to get personalized coaching tips.';
  }

  const prompt = `You are an expert swimming coach. A swimmer wants to focus on "${node.name}".

Technique: ${node.description}
Level: ${node.level} (1=easiest)
${node.revisit ? 'Note: This is a fundamental technique to practice regularly.' : ''}

Give 3-4 bullet-point tips. Each bullet must be ONE short sentence (max 10 words).
Focus on: body position, timing, or common mistake to avoid.

Output ONLY bullets, no intro/outro. Format:
• Tip one
• Tip two
• Tip three`;

  try {
    if (config.provider === 'anthropic') {
      return await callAnthropic(prompt, config);
    } else {
      return await callOpenAI(prompt, config);
    }
  } catch (error) {
    console.error('Error generating coaching tips:', error);
    return 'Failed to generate coaching tips. Please try again.';
  }
}