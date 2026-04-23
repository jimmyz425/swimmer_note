'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { PoseLandmarker, FilesetResolver, DrawingUtils } from '@mediapipe/tasks-vision';
import { LANDMARKS, PoseLandmark, FrameData, analyzePoseData } from './metrics';

interface PoseAnalysisResult {
  frames: FrameData[];
  metrics: ReturnType<typeof analyzePoseData>;
}

export function usePoseAnalysis() {
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const poseLandmarkerRef = useRef<PoseLandmarker | null>(null);

  // Initialize MediaPipe Pose Landmarker
  const initPoseLandmarker = useCallback(async () => {
    if (poseLandmarkerRef.current) return poseLandmarkerRef.current;

    try {
      const vision = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
      );

      const poseLandmarker = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task',
          delegate: 'GPU',
        },
        runningMode: 'VIDEO',
        numPoses: 1,
      });

      poseLandmarkerRef.current = poseLandmarker;
      return poseLandmarker;
    } catch (err) {
      console.error('Failed to init PoseLandmarker:', err);
      throw err;
    }
  }, []);

  // Analyze video file
  const analyzeVideo = useCallback(async (videoFile: File): Promise<PoseAnalysisResult | null> => {
    setLoading(true);
    setError(null);
    setProgress(0);

    try {
      const poseLandmarker = await initPoseLandmarker();

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
      const fps = 30; // Process at 30 fps
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
  }, [initPoseLandmarker]);

  return {
    analyzeVideo,
    loading,
    progress,
    error,
  };
}

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

    // Define connections to draw
    const connections = [
      // Torso
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.RIGHT_SHOULDER],
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.LEFT_HIP],
      [LANDMARKS.RIGHT_SHOULDER, LANDMARKS.RIGHT_HIP],
      [LANDMARKS.LEFT_HIP, LANDMARKS.RIGHT_HIP],
      // Arms
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.LEFT_ELBOW],
      [LANDMARKS.LEFT_ELBOW, LANDMARKS.LEFT_WRIST],
      [LANDMARKS.RIGHT_SHOULDER, LANDMARKS.RIGHT_ELBOW],
      [LANDMARKS.RIGHT_ELBOW, LANDMARKS.RIGHT_WRIST],
      // Legs
      [LANDMARKS.LEFT_HIP, LANDMARKS.LEFT_KNEE],
      [LANDMARKS.LEFT_KNEE, LANDMARKS.LEFT_ANKLE],
      [LANDMARKS.RIGHT_HIP, LANDMARKS.RIGHT_KNEE],
      [LANDMARKS.RIGHT_KNEE, LANDMARKS.RIGHT_ANKLE],
    ];

    // Draw connections
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 3;

    for (const [start, end] of connections) {
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