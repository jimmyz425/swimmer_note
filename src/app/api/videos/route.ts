import { NextRequest, NextResponse } from 'next/server';
import { saveVideoFile, saveAnalysis, listAnalyses, VideoAnalysis } from '@/lib/video/storage';

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
    const framerate = formData.get('framerate') as string || '30';
    const analysis: VideoAnalysis = {
      id,
      filename: file.name,
      createdAt: new Date().toISOString(),
      strokeType: strokeType as VideoAnalysis['strokeType'],
      duration: 0,
      framesProcessed: 0,
      framerate: parseInt(framerate) || 30,
      metrics: {
        strokeRate: 0,
        strokeRateHz: 0,
        strokeRatePeakHz: 0,
        strokeRateValidWindows: 0,
        strokeRateTotalWindows: 0,
        kickRate: 0,
        kickRateHz: 0,
        kickRateConfidence: 0,
        kickRatePeakHz: 0,
        kickRateValidWindows: 0,
        kickRateTotalWindows: 0,
        bodyAngleAvg: 0,
        bodyAngleMin: 0,
        bodyAngleMax: 0,
        armEntryAngleAvg: 0,
        elbowHeightAvg: 0,
      },
      realtimeStrokeRates: [],
      realtimeKickRates: [],
      rawLandmarks: '',
      status: 'pending',
    };

    // If client sent analyzed data, update the analysis
    if (metricsJson && landmarksJson) {
      const metrics = JSON.parse(metricsJson);
      const landmarks = JSON.parse(landmarksJson);

      analysis.metrics = {
        strokeRate: metrics.strokeRate || 0,
        strokeRateHz: metrics.strokeRateHz || 0,
        strokeRatePeakHz: metrics.strokeRatePeakHz || 0,
        strokeRateValidWindows: metrics.strokeRateValidWindows || 0,
        strokeRateTotalWindows: metrics.strokeRateTotalWindows || 0,
        kickRate: metrics.kickRate || 0,
        kickRateHz: metrics.kickRateHz || 0,
        kickRateConfidence: metrics.kickRateConfidence || 0,
        kickRatePeakHz: metrics.kickRatePeakHz || 0,
        kickRateValidWindows: metrics.kickRateValidWindows || 0,
        kickRateTotalWindows: metrics.kickRateTotalWindows || 0,
        bodyAngleAvg: metrics.bodyAngleAvg || 0,
        bodyAngleMin: metrics.bodyAngleMin || 0,
        bodyAngleMax: metrics.bodyAngleMax || 0,
        armEntryAngleAvg: metrics.armEntryAngleAvg || 0,
        elbowHeightAvg: metrics.elbowHeightAvg || 0,
      };
      analysis.realtimeStrokeRates = metrics.realtimeStrokeRates || [];
      analysis.realtimeKickRates = metrics.realtimeKickRates || [];
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
    }

    // Save analysis
    saveAnalysis(analysis);

    return NextResponse.json({ success: true, analysis });
  } catch (error) {
    console.error('Video upload error:', error);
    return NextResponse.json({ error: 'Failed to process video' }, { status: 500 });
  }
}