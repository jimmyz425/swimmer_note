import fs from 'fs';
import path from 'path';

const DATA_DIR = path.join(process.cwd(), 'data');
const VIDEOS_DIR = path.join(DATA_DIR, 'videos');

export interface VideoAnalysis {
  id: string;
  filename: string;
  createdAt: string;
  strokeType: 'freestyle' | 'backstroke' | 'breaststroke' | 'butterfly' | 'im';
  duration: number; // seconds
  framesProcessed: number;
  framerate: number; // fps used for analysis
  metrics: {
    strokeRate: number; // strokes per minute
    strokeRateHz: number; // strokes per second
    strokeRatePeakHz: number; // peak frequency detected
    strokeRateValidWindows: number; // windows above threshold
    strokeRateTotalWindows: number; // total windows analyzed
    kickRate: number; // kicks per minute
    kickRateHz: number; // kicks per second
    kickRateConfidence: number; // FFT confidence score
    kickRatePeakHz: number; // peak frequency detected
    kickRateValidWindows: number; // windows above 50% threshold
    kickRateTotalWindows: number; // total windows analyzed
    bodyAngleAvg: number; // degrees from horizontal
    bodyAngleMin: number;
    bodyAngleMax: number;
    armEntryAngleAvg: number;
    elbowHeightAvg: number;
  };
  realtimeStrokeRates?: Array<{
    timestamp: number;
    strokeRateHz: number;
    strokeRatePerMin: number;
    confidence: number;
    amplitude: number;
  }>;
  realtimeKickRates?: Array<{
    timestamp: number;
    kickRateHz: number;
    kickRatePerMin: number;
    confidence: number;
  }>;
  rawLandmarks: string; // path to JSON with all pose landmarks
  status: 'pending' | 'processing' | 'completed' | 'failed';
  coachingFeedback?: string;
}

function ensureVideosDir() {
  if (!fs.existsSync(VIDEOS_DIR)) {
    fs.mkdirSync(VIDEOS_DIR, { recursive: true });
  }
}

export function saveVideoFile(id: string, buffer: Buffer, extension: string): string {
  ensureVideosDir();
  const filename = `${id}.${extension}`;
  const filePath = path.join(VIDEOS_DIR, filename);
  fs.writeFileSync(filePath, buffer);
  return filePath;
}

export function getVideoPath(id: string): string | null {
  const extensions = ['mp4', 'mov', 'avi', 'webm'];
  for (const ext of extensions) {
    const filePath = path.join(VIDEOS_DIR, `${id}.${ext}`);
    if (fs.existsSync(filePath)) {
      return filePath;
    }
  }
  return null;
}

export function saveAnalysis(analysis: VideoAnalysis): void {
  ensureVideosDir();
  const filePath = path.join(VIDEOS_DIR, `${analysis.id}.json`);
  fs.writeFileSync(filePath, JSON.stringify(analysis, null, 2), 'utf-8');
}

export function getAnalysis(id: string): VideoAnalysis | null {
  const filePath = path.join(VIDEOS_DIR, `${id}.json`);
  if (!fs.existsSync(filePath)) {
    return null;
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(content) as VideoAnalysis;
}

export function listAnalyses(): VideoAnalysis[] {
  ensureVideosDir();
  const files = fs.readdirSync(VIDEOS_DIR).filter(f => f.endsWith('.json') && !f.includes('_landmarks'));
  return files.map(f => {
    const content = fs.readFileSync(path.join(VIDEOS_DIR, f), 'utf-8');
    return JSON.parse(content) as VideoAnalysis;
  }).filter(a => a && a.id && a.createdAt).sort((a, b) => {
    // Handle invalid dates gracefully
    const aTime = new Date(a.createdAt).getTime();
    const bTime = new Date(b.createdAt).getTime();
    // If either is invalid (NaN), treat as 0
    const aValid = isNaN(aTime) ? 0 : aTime;
    const bValid = isNaN(bTime) ? 0 : bTime;
    return bValid - aValid;
  });
}

export function deleteVideo(id: string): boolean {
  ensureVideosDir();
  const videoPath = getVideoPath(id);
  const analysisPath = path.join(VIDEOS_DIR, `${id}.json`);
  const landmarksPath = path.join(VIDEOS_DIR, `${id}_landmarks.json`);

  let deleted = false;
  if (videoPath && fs.existsSync(videoPath)) {
    fs.unlinkSync(videoPath);
    deleted = true;
  }
  if (fs.existsSync(analysisPath)) {
    fs.unlinkSync(analysisPath);
    deleted = true;
  }
  if (fs.existsSync(landmarksPath)) {
    fs.unlinkSync(landmarksPath);
    deleted = true;
  }
  return deleted;
}

export function saveLandmarks(id: string, landmarks: unknown[]): string {
  ensureVideosDir();
  const filePath = path.join(VIDEOS_DIR, `${id}_landmarks.json`);
  fs.writeFileSync(filePath, JSON.stringify(landmarks, null, 2), 'utf-8');
  return filePath;
}

export function getLandmarks(id: string): unknown[] | null {
  const filePath = path.join(VIDEOS_DIR, `${id}_landmarks.json`);
  if (!fs.existsSync(filePath)) {
    return null;
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(content);
}