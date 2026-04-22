import { callAnthropic } from './anthropic';
import { callOpenAI } from './openai';
import { getLLMConfig } from './config';
import { TrainingNote, Stroke, Technique } from '../types';

export async function generateGoalSuggestions(
  recentNotes: TrainingNote[],
  strokes: Stroke[],
  techniques: Technique[]
): Promise<string> {
  const config = getLLMConfig();
  if (!config) {
    return 'LLM is not configured. Please set LLM_PROVIDER and API key in environment.';
  }

  const prompt = buildSuggestionPrompt(recentNotes, strokes, techniques);

  try {
    if (config.provider === 'anthropic') {
      return await callAnthropic(prompt, config);
    } else {
      return await callOpenAI(prompt, config);
    }
  } catch (error) {
    console.error('Error calling LLM:', error);
    return 'Failed to generate suggestions. Please check your API configuration.';
  }
}

function buildSuggestionPrompt(
  recentNotes: TrainingNote[],
  strokes: Stroke[],
  techniques: Technique[]
): string {
  const notesSummary = recentNotes.map(note => {
    const goalsSummary = note.goals.map(g => `${g.description} (${g.status})`).join(', ');
    return `
Date: ${note.date}
Strokes: ${note.strokeFocus.join(', ') || 'none'}
Techniques: ${note.techniqueFocus.join(', ') || 'none'}
Goals: ${goalsSummary || 'none'}
Notes: ${note.notes || 'none'}
    `.trim();
  }).join('\n\n');

  const strokeNames = strokes.map(s => s.name).join(', ');
  const techniqueNames = techniques.map(t => `${t.name} (${t.category})`).join(', ');

  return `You are a swimming coach helping a swimmer set daily training goals.

Recent training history (last ${recentNotes.length} sessions):
${notesSummary}

Available strokes: ${strokeNames}
Available techniques: ${techniqueNames}

Based on the recent training history, suggest 3-5 specific training goals for today's session.
Consider:
1. What strokes/techniques have been practiced recently
2. What goals have been pending or in progress
3. Balance between different strokes and techniques
4. Progressive improvement patterns

Format your response as a brief list with specific, actionable goals.
Example format:
- [stroke/technique] Focus on X to improve Y
- [general] Work on Z aspect

Keep suggestions concise and practical.`;
}

export async function generateFeedback(note: TrainingNote): Promise<string> {
  const config = getLLMConfig();
  if (!config) {
    return 'LLM is not configured.';
  }

  const prompt = `Analyze this swimmer's training note and provide brief feedback:

Date: ${note.date}
Strokes focused: ${note.strokeFocus.join(', ') || 'none'}
Techniques focused: ${note.techniqueFocus.join(', ') || 'none'}
Goals: ${note.goals.map(g => `${g.description} (${g.status})`).join(', ') || 'none'}
Self-notes: ${note.notes || 'none'}

Provide:
1. A brief encouraging comment on progress
2. One specific suggestion for improvement
3. A recommended focus for the next session

Keep response concise (3-4 sentences).`;

  try {
    if (config.provider === 'anthropic') {
      return await callAnthropic(prompt, config);
    } else {
      return await callOpenAI(prompt, config);
    }
  } catch (error) {
    console.error('Error generating feedback:', error);
    return 'Failed to generate feedback.';
  }
}