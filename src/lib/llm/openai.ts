import OpenAI from 'openai';
import { LLMConfig, getModelName } from './config';

export async function callOpenAI(prompt: string, config: LLMConfig): Promise<string> {
  const client = new OpenAI({
    apiKey: config.apiKey,
    baseURL: config.apiBase || undefined,
    timeout: config.timeout ? config.timeout * 1000 : undefined,
    maxRetries: config.maxRetries || 3,
  });

  const modelName = getModelName(config);

  const response = await client.chat.completions.create({
    model: modelName,
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  });

  return response.choices[0]?.message?.content || '';
}