import { NextRequest, NextResponse } from 'next/server';
import { saveVideoFile, saveAnalysis, listAnalyses, VideoAnalysis } from '@/lib/video/storage';
import { getLLMConfig } from '@/lib/llm/config';
import { callAnthropic } from '@/lib/llm/anthropic';
import { callOpenAI } from '@/lib/llm/openai';

export async function GET() {
  const analyses = listAnalyses();
  return NextResponse.json({ analyses });
}

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    const strokeType = formData.get('strokeType') as string || 'freestyle';
    const metricsJson = formData.get('metrics') as string | null;
    const landmarksJson = formData.get('landmarks') as string | null;

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 });
    }

    // Generate ID
    const id = `video_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Get file extension
    const extension = file.name.split('.').pop() || 'mp4';

    // Save video file
    const buffer = Buffer.from(await file.arrayBuffer());
    saveVideoFile(id, buffer, extension);

    // Create initial analysis record
    const analysis: VideoAnalysis = {
      id,
      filename: file.name,
      createdAt: new Date().toISOString(),
      strokeType: strokeType as VideoAnalysis['strokeType'],
      duration: 0,
      framesProcessed: 0,
      metrics: {
        strokeRate: 0,
        kickRate: 0,
        bodyAngleAvg: 0,
        bodyAngleMin: 0,
        bodyAngleMax: 0,
        armEntryAngleAvg: 0,
        elbowHeightAvg: 0,
      },
      rawLandmarks: '',
      status: 'pending',
    };

    // If client sent analyzed data, update the analysis
    if (metricsJson && landmarksJson) {
      const metrics = JSON.parse(metricsJson);
      const landmarks = JSON.parse(landmarksJson);

      analysis.metrics = metrics;
      analysis.framesProcessed = landmarks.length;
      analysis.duration = landmarks.length > 0 ? landmarks[landmarks.length - 1].timestamp / 1000 : 0;
      analysis.status = 'completed';
      analysis.rawLandmarks = `${id}_landmarks.json`;

      // Save landmarks to separate file
      const landmarksPath = `${id}_landmarks.json`;
      const fs = require('fs');
      const path = require('path');
      const VIDEOS_DIR = path.join(process.cwd(), 'data', 'videos');
      fs.writeFileSync(path.join(VIDEOS_DIR, landmarksPath), JSON.stringify(landmarks, null, 2));

      // Generate coaching feedback
      const config = getLLMConfig();
      if (config) {
        const feedbackPrompt = `You are an expert swimming coach. Analyze these metrics from underwater video analysis for ${strokeType}:

- Stroke Rate: ${metrics.strokeRate} strokes per minute
- Kick Rate: ${metrics.kickRate} kicks per second
- Body Angle: avg ${metrics.bodyAngleAvg.toFixed(1)}°, range ${metrics.bodyAngleMin.toFixed(1)}° to ${metrics.bodyAngleMax.toFixed(1)}°
- Elbow Height Index: ${metrics.elbowHeightAvg.toFixed(2)} (positive = high elbow catch)

Provide 3-4 brief bullet-point coaching tips focused on technique improvement. Each bullet ONE short sentence max 10 words.
Output ONLY bullets, no intro/outro.`;

        try {
          let feedback: string;
          if (config.provider === 'anthropic') {
            feedback = await callAnthropic(feedbackPrompt, config);
          } else {
            feedback = await callOpenAI(feedbackPrompt, config);
          }
          analysis.coachingFeedback = feedback;
        } catch (err) {
          console.error('Failed to generate feedback:', err);
        }
      }
    }

    // Save analysis
    saveAnalysis(analysis);

    return NextResponse.json({ success: true, analysis });
  } catch (error) {
    console.error('Video upload error:', error);
    return NextResponse.json({ error: 'Failed to process video' }, { status: 500 });
  }
}