'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { PoseLandmark } from '@/lib/video/metrics';
import { Play, Pause, ChevronLeft, ChevronRight, Gauge, SkipBack, SkipForward } from 'lucide-react';

const LANDMARKS = {
  NOSE: 0,
  LEFT_SHOULDER: 11, RIGHT_SHOULDER: 12,
  LEFT_ELBOW: 13, RIGHT_ELBOW: 14,
  LEFT_WRIST: 15, RIGHT_WRIST: 16,
  LEFT_HIP: 23, RIGHT_HIP: 24,
  LEFT_KNEE: 25, RIGHT_KNEE: 26,
  LEFT_ANKLE: 27, RIGHT_ANKLE: 28,
};

const LANDMARK_NAMES: Record<number, string> = {
  0: 'Nose',
  11: 'L.Shoulder', 12: 'R.Shoulder',
  13: 'L.Elbow', 14: 'R.Elbow',
  15: 'L.Wrist', 16: 'R.Wrist',
  23: 'L.Hip', 24: 'R.Hip',
  25: 'L.Knee', 26: 'R.Knee',
  27: 'L.Ankle', 28: 'R.Ankle',
};

// Playback speeds for animation
const PLAYBACK_SPEEDS = [0.5, 1, 2, 5, 10, 30]; // frames per second

interface PoseDebugViewerProps {
  landmarks: PoseLandmark[];
  width: number;
  height: number;
}

export function PoseDebugViewer({ landmarks, width, height }: PoseDebugViewerProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!canvasRef.current || landmarks.length === 0) return;

    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, width, height);

    // Fill background
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, width, height);

    // Connections (skeleton lines)
    const connections = [
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.RIGHT_SHOULDER],
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.LEFT_ELBOW],
      [LANDMARKS.LEFT_ELBOW, LANDMARKS.LEFT_WRIST],
      [LANDMARKS.RIGHT_SHOULDER, LANDMARKS.RIGHT_ELBOW],
      [LANDMARKS.RIGHT_ELBOW, LANDMARKS.RIGHT_WRIST],
      [LANDMARKS.LEFT_SHOULDER, LANDMARKS.LEFT_HIP],
      [LANDMARKS.RIGHT_SHOULDER, LANDMARKS.RIGHT_HIP],
      [LANDMARKS.LEFT_HIP, LANDMARKS.RIGHT_HIP],
      [LANDMARKS.LEFT_HIP, LANDMARKS.LEFT_KNEE],
      [LANDMARKS.LEFT_KNEE, LANDMARKS.LEFT_ANKLE],
      [LANDMARKS.RIGHT_HIP, LANDMARKS.RIGHT_KNEE],
      [LANDMARKS.RIGHT_KNEE, LANDMARKS.RIGHT_ANKLE],
    ];

    // Draw skeleton lines with glow
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 3;
    ctx.shadowColor = '#00FF00';
    ctx.shadowBlur = 4;

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

    ctx.shadowBlur = 0;

    // Draw key landmarks with labels
    const keyIndices = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28, 0];

    for (const idx of keyIndices) {
      const lm = landmarks[idx];
      if (lm.visibility > 0.3) {
        const x = lm.x * width;
        const y = lm.y * height;

        // Draw point with white border
        ctx.fillStyle = idx === 13 || idx === 14 ? '#FF6B00' : '#FF3333';
        ctx.beginPath();
        ctx.arc(x, y, 6, 0, 2 * Math.PI);
        ctx.fill();

        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1;
        ctx.stroke();

        // Draw label
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 10px monospace';
        ctx.fillText(LANDMARK_NAMES[idx] || `[${idx}]`, x + 8, y - 4);

        // Draw coordinates
        ctx.fillStyle = '#AAAAAA';
        ctx.font = '9px monospace';
        ctx.fillText(`x:${lm.x.toFixed(2)} y:${lm.y.toFixed(2)}`, x + 8, y + 10);
      }
    }
  }, [landmarks, width, height]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="rounded-lg w-full"
      style={{ maxWidth: '100%', aspectRatio: `${width}/${height}` }}
    />
  );
}

// Frame-by-frame viewer component with video-player-like controls
interface PoseDebugPanelProps {
  framesData: { timestamp: number; landmarks: PoseLandmark[] }[];
}

export function PoseDebugPanel({ framesData }: PoseDebugPanelProps) {
  const [frameIndex, setFrameIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState(5); // frames per second
  const animationRef = useRef<NodeJS.Timeout | null>(null);

  const frame = framesData[frameIndex];
  const totalFrames = framesData.length;
  const duration = framesData.length > 0 ? framesData[framesData.length - 1].timestamp : 0;
  const currentTime = frame?.timestamp || 0;

  // Animation loop
  useEffect(() => {
    if (playing) {
      const interval = 1000 / playbackSpeed;
      animationRef.current = setInterval(() => {
        setFrameIndex(prev => {
          if (prev >= totalFrames - 1) {
            setPlaying(false);
            return prev;
          }
          return prev + 1;
        });
      }, interval);
    } else {
      if (animationRef.current) {
        clearInterval(animationRef.current);
        animationRef.current = null;
      }
    }

    return () => {
      if (animationRef.current) {
        clearInterval(animationRef.current);
      }
    };
  }, [playing, playbackSpeed, totalFrames]);

  // Navigation controls
  const prevFrame = useCallback(() => {
    setPlaying(false);
    setFrameIndex(prev => Math.max(0, prev - 1));
  }, []);

  const nextFrame = useCallback(() => {
    setPlaying(false);
    setFrameIndex(prev => Math.min(totalFrames - 1, prev + 1));
  }, [totalFrames]);

  const skipFrames = useCallback((count: number) => {
    setPlaying(false);
    setFrameIndex(prev => Math.max(0, Math.min(totalFrames - 1, prev + count)));
  }, [totalFrames]);

  const togglePlay = useCallback(() => {
    if (frameIndex >= totalFrames - 1) {
      // Restart from beginning if at end
      setFrameIndex(0);
    }
    setPlaying(prev => !prev);
  }, [frameIndex, totalFrames]);

  const seekTo = useCallback((index: number) => {
    setPlaying(false);
    setFrameIndex(Math.max(0, Math.min(totalFrames - 1, index)));
  }, [totalFrames]);

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === ' ' || e.key === 'k') {
        togglePlay();
      } else if (e.key === 'ArrowLeft' || e.key === ',') {
        prevFrame();
      } else if (e.key === 'ArrowRight' || e.key === '.') {
        nextFrame();
      } else if (e.key === 'ArrowUp') {
        skipFrames(10);
      } else if (e.key === 'ArrowDown') {
        skipFrames(-10);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [togglePlay, prevFrame, nextFrame, skipFrames]);

  if (!frame) return null;

  // Calculate displayed FPS
  const displayFps = playbackSpeed;

  return (
    <div className="space-y-3">
      {/* Controls Row 1 */}
      <div className="flex items-center gap-3">
        {/* Play/Pause */}
        <button
          onClick={togglePlay}
          className="w-10 h-10 rounded-lg bg-pool-mid/20 hover:bg-pool-mid/30 flex items-center justify-center transition-colors"
        >
          {playing ? (
            <Pause className="w-5 h-5 text-pool-dark" />
          ) : (
            <Play className="w-5 h-5 text-pool-dark" />
          )}
        </button>

        {/* Frame-by-frame */}
        <button
          onClick={prevFrame}
          className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
          title="Previous frame (← or ,)"
        >
          <ChevronLeft className="w-4 h-4 text-pool-dark" />
        </button>
        <button
          onClick={nextFrame}
          className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
          title="Next frame (→ or .)"
        >
          <ChevronRight className="w-4 h-4 text-pool-dark" />
        </button>

        {/* Skip buttons */}
        <button
          onClick={() => skipFrames(-10)}
          className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
          title="Skip -10 frames (↓)"
        >
          <SkipBack className="w-4 h-4 text-pool-dark" />
        </button>
        <button
          onClick={() => skipFrames(10)}
          className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
          title="Skip +10 frames (↑)"
        >
          <SkipForward className="w-4 h-4 text-pool-dark" />
        </button>

        {/* Timeline */}
        <div className="flex-1 flex items-center gap-2">
          <span className="text-xs text-pool-mid font-mono">
            {(currentTime / 1000).toFixed(1)}s
          </span>
          <input
            type="range"
            min={0}
            max={totalFrames - 1}
            value={frameIndex}
            onChange={(e) => seekTo(parseInt(e.target.value))}
            className="flex-1 accent-pool-mid"
          />
          <span className="text-xs text-pool-mid font-mono">
            {(duration / 1000).toFixed(1)}s
          </span>
        </div>
      </div>

      {/* Controls Row 2: Speed + Info */}
      <div className="flex items-center gap-4">
        {/* Playback speed */}
        <div className="flex items-center gap-2">
          <Gauge className="w-4 h-4 text-pool-mid" />
          <select
            value={playbackSpeed}
            onChange={(e) => setPlaybackSpeed(parseInt(e.target.value))}
            className="rounded-lg border border-pool-light/50 px-2 py-1.5 text-xs font-semibold text-pool-dark
              bg-white/80 focus:border-pool-mid outline-none"
          >
            {PLAYBACK_SPEEDS.map(fps => (
              <option key={fps} value={fps}>
                {fps} fps
              </option>
            ))}
          </select>
        </div>

        {/* Frame info */}
        <div className="text-xs text-pool-mid">
          Frame <span className="font-semibold text-pool-dark">{frameIndex + 1}</span> / {totalFrames}
        </div>
      </div>

      {/* Pose skeleton */}
      <PoseDebugViewer landmarks={frame.landmarks} width={480} height={360} />

      {/* Keyboard shortcuts hint */}
      <p className="text-xs text-pool-mid/60 text-center">
        Space = play/pause • ←→ = frame step • ↑↓ = skip 10 • ,/. = frame step • Speed: {playbackSpeed} fps
      </p>

      {/* Raw data */}
      <details className="mt-2">
        <summary className="cursor-pointer text-sm font-semibold text-pool-dark">
          Raw Landmark Data (key joints)
        </summary>
        <pre className="mt-2 p-2 bg-gray-100 rounded text-xs overflow-auto max-h-48">
          {JSON.stringify(frame.landmarks.filter((_, i) => [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28].includes(i)), null, 2)}
        </pre>
      </details>
    </div>
  );
}