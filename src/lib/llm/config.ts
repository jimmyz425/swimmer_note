export type LLMProvider = 'anthropic' | 'openai';

export interface LLMConfig {
  provider: LLMProvider;
  apiKey: string;
  apiBase?: string;
  modelName?: string;
  timeout?: number;
  maxRetries?: number;
}

export function getLLMConfig(): LLMConfig | null {
  const provider = (process.env.LLM_PROVIDER as LLMProvider) || 'anthropic';
  const apiKey = provider === 'anthropic'
    ? process.env.ANTHROPIC_API_KEY
    : process.env.OPENAI_API_KEY;

  if (!apiKey) {
    console.warn(`No API key found for provider ${provider}`);
    return null;
  }

  return {
    provider,
    apiKey,
    apiBase: process.env.OPENAI_API_BASE,
    modelName: process.env.MODEL_NAME,
    timeout: parseInt(process.env.LLM_TIMEOUT || '600', 10),
    maxRetries: parseInt(process.env.LLM_MAX_RETRIES || '3', 10),
  };
}

export function isLLMConfigured(): boolean {
  return getLLMConfig() !== null;
}

export function getModelName(config: LLMConfig): string {
  if (config.modelName) {
    // Handle model name format like "openai/qwen3.6-plus" -> use just "qwen3.6-plus"
    const parts = config.modelName.split('/');
    return parts.length > 1 ? parts[1] : config.modelName;
  }
  // Default models
  if (config.provider === 'anthropic') {
    return 'claude-sonnet-4-6-20250514';
  }
  return 'gpt-4o-mini';
}