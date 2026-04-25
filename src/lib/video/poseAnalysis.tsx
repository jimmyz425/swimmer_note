'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { PoseLandmarker, FilesetResolver } from '@mediapipe/tasks-vision';
import { LANDMARKS, PoseLandmark, FrameData, analyzePoseData, CONNECTIONS } from './metrics';

// Model variants: lite (fastest), full (balanced), heavy (most accurate)
export type PoseModelVariant = 'lite' | 'full' | 'heavy';

// Framerate options for analysis - can use preset or detect from video
export type AnalysisFramerate = 30 | 60 | 120 | 240 | 'auto';

const FRAMERATE_INFO: Record<AnalysisFramerate, { label: string; description: string }> = {
  30: { label: '30 FPS', description: 'Standard, balanced speed' },
  60: { label: '60 FPS', description: 'Good for fast movements' },
  120: { label: '120 FPS', description: 'High detail, slower processing' },
  240: { label: '240 FPS', description: 'Maximum detail, very slow' },
  'auto': { label: 'Auto (Video FPS)', description: 'Use video\'s native framerate' },
};

const MODEL_PATHS: Record<PoseModelVariant, string> = {
  lite: 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task',
  full: 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task',
  heavy: 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task',
};

const MODEL_INFO: Record<PoseModelVariant, { name: string; speed: string; accuracy: string }> = {
  lite: { name: 'Lite', speed: '~2x faster', accuracy: 'Basic pose detection' },
  full: { name: 'Full', speed: 'Balanced', accuracy: 'Good accuracy for most poses' },
  heavy: { name: 'Heavy', speed: '~2x slower', accuracy: 'Highest accuracy, best for complex poses' },
};

interface PoseAnalysisResult {
  frames: FrameData[];
  metrics: ReturnType<typeof analyzePoseData>;
}

export function usePoseAnalysis(modelVariant: PoseModelVariant = 'lite') {
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [modelLoaded, setModelLoaded] = useState<PoseModelVariant | null>(null);
  const poseLandmarkerRef = useRef<PoseLandmarker | null>(null);

  // Initialize MediaPipe Pose Landmarker
  const initPoseLandmarker = useCallback(async (variant: PoseModelVariant) => {
    // Re-initialize if model variant changes
    if (poseLandmarkerRef.current && modelLoaded === variant) {
      return poseLandmarkerRef.current;
    }

    // Close existing landmarker if switching models
    if (poseLandmarkerRef.current && modelLoaded !== variant) {
      poseLandmarkerRef.current.close();
      poseLandmarkerRef.current = null;
    }

    try {
      const vision = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
      );

      const poseLandmarker = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_PATHS[variant],
          delegate: 'GPU',
        },
        runningMode: 'VIDEO',
        numPoses: 1,
      });

      poseLandmarkerRef.current = poseLandmarker;
      setModelLoaded(variant);
      return poseLandmarker;
    } catch (err) {
      console.error('Failed to init PoseLandmarker:', err);
      throw err;
    }
  }, [modelLoaded]);

  // Analyze video file
  const analyzeVideo = useCallback(async (videoFile: File, framerate: AnalysisFramerate = 30): Promise<PoseAnalysisResult | null> => {
    setLoading(true);
    setError(null);
    setProgress(0);

    try {
      const poseLandmarker = await initPoseLandmarker(modelVariant);

      // Create video element to process frames
      const video = document.createElement('video');
      video.src = URL.createObjectURL(videoFile);
      video.muted = true;
      video.playsInline = true;

      // Wait for video to load
      await new Promise<void>((resolve) => {
        video.onloadedmetadata = () => {
          video.currentTime = 0;
          resolve();
        };
      });

      const frames: FrameData[] = [];

      // Determine FPS to use
      let fps: number;
      if (framerate === 'auto') {
        // Try to detect video's native framerate
        // Most browsers don't expose this directly, so we estimate
        // Check if requestVideoFrameCallback API is available (indicates modern browser)
        const hasModernApi = 'requestVideoFrameCallback' in HTMLVideoElement.prototype;
        // Common video framerates: 24, 30, 60, 120, 240
        const detectedFps = hasModernApi ? 60 : 30;

        // Cap at 240 to prevent extremely slow processing
        fps = Math.min(detectedFps, 240);
      } else {
        fps = framerate;
      }

      const duration = video.duration * 1000; // ms
      const frameInterval = 1000 / fps;
      const totalFrames = Math.floor(video.duration * fps);

      // Process each frame
      for (let frameNum = 0; frameNum < totalFrames; frameNum++) {
        const timestamp = frameNum * frameInterval;
        video.currentTime = timestamp / 1000;

        // Wait for frame to be ready
        await new Promise<void>((resolve) => {
          video.onseeked = () => resolve();
        });

        // Detect pose for this frame
        const results = poseLandmarker.detectForVideo(video, Math.floor(timestamp));

        if (results.landmarks && results.landmarks.length > 0) {
          const landmarks: PoseLandmark[] = results.landmarks[0].map((lm) => ({
            x: lm.x,
            y: lm.y,
            z: lm.z ?? 0,
            visibility: lm.visibility ?? 0,
          }));

          frames.push({ timestamp, landmarks });
        }

        setProgress(Math.floor((frameNum / totalFrames) * 100));
      }

      // Clean up
      URL.revokeObjectURL(video.src);

      // Analyze metrics from collected landmarks
      const metrics = analyzePoseData(frames);

      setLoading(false);
      setProgress(100);

      return { frames, metrics };
    } catch (err) {
      console.error('Video analysis failed:', err);
      setError(err instanceof Error ? err.message : 'Analysis failed');
      setLoading(false);
      return null;
    }
  }, [initPoseLandmarker, modelVariant]);

  return {
    analyzeVideo,
    loading,
    progress,
    error,
    modelVariant,
    modelLoaded,
    modelInfo: MODEL_INFO[modelVariant],
    framerateOptions: FRAMERATE_INFO,
  };
}

export { FRAMERATE_INFO };

// Component for drawing pose overlay on video
export function PoseOverlay({
  landmarks,
  width,
  height,
}: {
  landmarks: PoseLandmark[];
  width: number;
  height: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!canvasRef.current || landmarks.length === 0) return;

    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, width, height);

    // Draw connections
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 3;

    for (const [start, end] of CONNECTIONS) {
      const startLm = landmarks[start];
      const endLm = landmarks[end];

      if (startLm.visibility > 0.5 && endLm.visibility > 0.5) {
        ctx.beginPath();
        ctx.moveTo(startLm.x * width, startLm.y * height);
        ctx.lineTo(endLm.x * width, endLm.y * height);
        ctx.stroke();
      }
    }

    // Draw landmarks as circles
    ctx.fillStyle = '#FF0000';

    for (const lm of landmarks) {
      if (lm.visibility > 0.5) {
        ctx.beginPath();
        ctx.arc(lm.x * width, lm.y * height, 5, 0, 2 * Math.PI);
        ctx.fill();
      }
    }
  }, [landmarks, width, height]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="absolute inset-0 pointer-events-none"
    />
  );
}