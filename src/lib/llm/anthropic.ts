import Anthropic from '@anthropic-ai/sdk';
import { LLMConfig } from './config';

export async function callAnthropic(prompt: string, config: LLMConfig): Promise<string> {
  const client = new Anthropic({ apiKey: config.apiKey });

  const message = await client.messages.create({
    model: 'claude-sonnet-4-6-20250514',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  });

  const textBlock = message.content.find(block => block.type === 'text');
  return textBlock ? textBlock.text : '';
}