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
  metrics: {
    strokeRate: number; // strokes per minute
    kickRate: number; // kicks per second
    bodyAngleAvg: number; // degrees from horizontal
    bodyAngleMin: number;
    bodyAngleMax: number;
    armEntryAngleAvg: number;
    elbowHeightAvg: number;
  };
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
  const files = fs.readdirSync(VIDEOS_DIR).filter(f => f.endsWith('.json'));
  return files.map(f => {
    const content = fs.readFileSync(path.join(VIDEOS_DIR, f), 'utf-8');
    return JSON.parse(content) as VideoAnalysis;
  }).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
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