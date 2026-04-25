'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { PoseLandmark } from '@/lib/video/metrics';
import { Play, Pause, SkipBack, SkipForward, Loader2, Gauge, ChevronLeft, ChevronRight } from 'lucide-react';

const LANDMARKS = {
  NOSE: 0,
  LEFT_SHOULDER: 11, RIGHT_SHOULDER: 12,
  LEFT_ELBOW: 13, RIGHT_ELBOW: 14,
  LEFT_WRIST: 15, RIGHT_WRIST: 16,
  LEFT_HIP: 23, RIGHT_HIP: 24,
  LEFT_KNEE: 25, RIGHT_KNEE: 26,
  LEFT_ANKLE: 27, RIGHT_ANKLE: 28,
};

const CONNECTIONS = [
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

// Playback speed options
const PLAYBACK_SPEEDS = [0.25, 0.5, 1, 1.5, 2];

interface FrameData {
  timestamp: number;
  landmarks: PoseLandmark[];
  kickRateHz?: number;
  kickRatePerMin?: number;
  kickRateConfidence?: number;
}

interface VideoSkeletonOverlayProps {
  videoId: string;
  realtimeKickRates?: Array<{
    timestamp: number;
    kickRateHz: number;
    kickRatePerMin: number;
    confidence: number;
  }>;
}

export function VideoSkeletonOverlay({ videoId, realtimeKickRates }: VideoSkeletonOverlayProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [frames, setFrames] = useState<FrameData[]>([]);
  const [playing, setPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [videoSize, setVideoSize] = useState({ width: 640, height: 360 });
  const [playbackSpeed, setPlaybackSpeed] = useState(1);
  const [currentFrameIndex, setCurrentFrameIndex] = useState(0);
  const [frameByFrameMode, setFrameByFrameMode] = useState(false);
  const [currentKickRate, setCurrentKickRate] = useState<{ kickRatePerMin: number; confidence: number } | null>(null);

  // Merge realtime kick rates into frames if provided
  useEffect(() => {
    if (realtimeKickRates && frames.length > 0) {
      const mergedFrames = frames.map(frame => {
        const kickRate = realtimeKickRates.find(r => r.timestamp === frame.timestamp);
        return {
          ...frame,
          kickRateHz: kickRate?.kickRateHz,
          kickRatePerMin: kickRate?.kickRatePerMin,
          kickRateConfidence: kickRate?.confidence,
        };
      });
      setFrames(mergedFrames);
    }
  }, [realtimeKickRates]);

  // Load video and landmarks
  useEffect(() => {
    setLoading(true);
    setError(null);

    Promise.all([
      fetch(`/api/videos/${videoId}`).then(res => {
        if (!res.ok) throw new Error('Video not found');
        return res.blob();
      }),
      fetch(`/api/videos/${videoId}/landmarks`).then(res => {
        if (!res.ok) return null;
        return res.json();
      }),
    ])
      .then(([videoBlob, landmarksData]) => {
        if (videoRef.current) {
          videoRef.current.src = URL.createObjectURL(videoBlob);
        }
        if (landmarksData?.landmarks) {
          setFrames(landmarksData.landmarks);
        }
      })
      .catch(err => {
        setError(err.message);
      })
      .finally(() => setLoading(false));
  }, [videoId]);

  // Get video dimensions when loaded
  const handleVideoLoaded = useCallback(() => {
    if (videoRef.current) {
      const { videoWidth, videoHeight, duration } = videoRef.current;
      setVideoSize({ width: videoWidth, height: videoHeight });
      setDuration(duration);
      videoRef.current.currentTime = 0;
    }
  }, []);

  // Interpolate between two landmark sets
  const interpolateLandmarks = useCallback((
    landmarks1: PoseLandmark[],
    landmarks2: PoseLandmark[],
    factor: number // 0 = landmarks1, 1 = landmarks2
  ): PoseLandmark[] => {
    if (landmarks1.length !== landmarks2.length) return landmarks1;

    return landmarks1.map((lm1, i) => {
      const lm2 = landmarks2[i];
      return {
        x: lm1.x + (lm2.x - lm1.x) * factor,
        y: lm1.y + (lm2.y - lm1.y) * factor,
        z: lm1.z + (lm2.z - lm1.z) * factor,
        visibility: lm1.visibility + (lm2.visibility - lm1.visibility) * factor,
      };
    });
  }, []);

  // Find and interpolate frame for current time
  const findInterpolatedFrame = useCallback((time: number): PoseLandmark[] | null => {
    if (frames.length === 0) return null;
    const timestamp = time * 1000; // Convert to ms

    // Find bracketing frames (frame before and frame after current time)
    let frameBefore: FrameData | null = null;
    let frameAfter: FrameData | null = null;

    for (let i = 0; i < frames.length; i++) {
      if (frames[i].timestamp <= timestamp) {
        frameBefore = frames[i];
      }
      if (frames[i].timestamp >= timestamp && !frameAfter) {
        frameAfter = frames[i];
        break;
      }
    }

    // Edge cases
    if (!frameBefore && !frameAfter) return null;
    if (!frameBefore) return frameAfter?.landmarks || null;
    if (!frameAfter) return frameBefore.landmarks;

    // Same frame (exact match)
    if (frameBefore.timestamp === frameAfter.timestamp) {
      return frameBefore.landmarks;
    }

    // Calculate interpolation factor
    const timeRange = frameAfter.timestamp - frameBefore.timestamp;
    const timeOffset = timestamp - frameBefore.timestamp;
    const factor = timeOffset / timeRange;

    // Interpolate between the two frames
    return interpolateLandmarks(frameBefore.landmarks, frameAfter.landmarks, factor);
  }, [frames, interpolateLandmarks]);

  // Draw skeleton on canvas
  const drawSkeleton = useCallback((landmarks: PoseLandmark[]) => {
    const canvas = canvasRef.current;
    const video = videoRef.current;
    if (!canvas || !video || landmarks.length === 0) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const { width, height } = videoSize;

    ctx.clearRect(0, 0, width, height);

    // Draw connections (skeleton lines)
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 3;
    ctx.shadowColor = '#00FF00';
    ctx.shadowBlur = 4;

    for (const [start, end] of CONNECTIONS) {
      const startLm = landmarks[start];
      const endLm = landmarks[end];

      if (startLm?.visibility > 0.5 && endLm?.visibility > 0.5) {
        ctx.beginPath();
        ctx.moveTo(startLm.x * width, startLm.y * height);
        ctx.lineTo(endLm.x * width, endLm.y * height);
        ctx.stroke();
      }
    }

    // Reset shadow for points
    ctx.shadowBlur = 0;

    // Draw landmark points
    for (let i = 0; i < landmarks.length; i++) {
      const lm = landmarks[i];
      if (lm.visibility > 0.5) {
        // Highlight elbows in orange
        ctx.fillStyle = i === 13 || i === 14 ? '#FF6B00' : '#FF3333';
        ctx.beginPath();
        ctx.arc(lm.x * width, lm.y * height, 6, 0, 2 * Math.PI);
        ctx.fill();

        // Add white border for visibility
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }
  }, [videoSize]);

  // Update skeleton on time change - uses interpolation for smooth animation
  useEffect(() => {
    const landmarks = findInterpolatedFrame(currentTime);
    if (landmarks) {
      drawSkeleton(landmarks);
    }
  }, [currentTime, findInterpolatedFrame, drawSkeleton]);

  // Handle time update during playback
  const handleTimeUpdate = useCallback(() => {
    if (videoRef.current) {
      setCurrentTime(videoRef.current.currentTime);
      // Update frame index based on current time
      if (frames.length > 0) {
        const timestamp = videoRef.current.currentTime * 1000;
        const closestIdx = frames.findIndex(f => f.timestamp >= timestamp);
        const frameIdx = closestIdx === -1 ? frames.length - 1 : Math.max(0, closestIdx - 1);
        setCurrentFrameIndex(frameIdx);

        // Update current kick rate
        const frame = frames[frameIdx];
        if (frame?.kickRatePerMin && frame?.kickRateConfidence) {
          setCurrentKickRate({
            kickRatePerMin: frame.kickRatePerMin,
            confidence: frame.kickRateConfidence,
          });
        }
      }
    }
  }, [frames]);

  // Set playback speed
  useEffect(() => {
    if (videoRef.current) {
      videoRef.current.playbackRate = playbackSpeed;
    }
  }, [playbackSpeed]);

  // Playback controls
  const togglePlay = useCallback(() => {
    if (videoRef.current) {
      if (playing) {
        videoRef.current.pause();
      } else {
        videoRef.current.play();
      }
      setPlaying(!playing);
    }
  }, [playing]);

  const skip = useCallback((seconds: number) => {
    if (videoRef.current) {
      videoRef.current.currentTime = Math.max(0, Math.min(duration, currentTime + seconds));
    }
  }, [currentTime, duration]);

  const seekTo = useCallback((time: number) => {
    if (videoRef.current) {
      videoRef.current.currentTime = time;
    }
  }, []);

  // Frame-by-frame navigation
  const prevFrame = useCallback(() => {
    if (frames.length === 0) return;
    const newIndex = Math.max(0, currentFrameIndex - 1);
    setCurrentFrameIndex(newIndex);
    const newTime = frames[newIndex].timestamp / 1000;
    if (videoRef.current) {
      videoRef.current.currentTime = newTime;
      videoRef.current.pause();
      setPlaying(false);
    }
  }, [frames, currentFrameIndex]);

  const nextFrame = useCallback(() => {
    if (frames.length === 0) return;
    const newIndex = Math.min(frames.length - 1, currentFrameIndex + 1);
    setCurrentFrameIndex(newIndex);
    const newTime = frames[newIndex].timestamp / 1000;
    if (videoRef.current) {
      videoRef.current.currentTime = newTime;
      videoRef.current.pause();
      setPlaying(false);
    }
  }, [frames, currentFrameIndex]);

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === ' ' || e.key === 'k') {
        togglePlay();
      } else if (e.key === 'ArrowLeft') {
        if (frameByFrameMode) {
          prevFrame();
        } else {
          skip(-1);
        }
      } else if (e.key === 'ArrowRight') {
        if (frameByFrameMode) {
          nextFrame();
        } else {
          skip(1);
        }
      } else if (e.key === ',' || e.key === '.') {
        // Comma/period for frame stepping (common in video editors)
        if (e.key === ',') prevFrame();
        else nextFrame();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [togglePlay, skip, prevFrame, nextFrame, frameByFrameMode]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 text-pool-mid animate-spin" />
        <span className="ml-3 text-pool-mid">Loading video...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-8 text-red-600">
        <p>Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="glass-card rounded-xl p-4">
      <h3 className="font-bold text-pool-dark mb-3 flex items-center gap-2">
        🎬 Video with Skeleton Overlay
        <span className="text-xs text-pool-mid font-normal">
          {frames.length > 0 ? `${frames.length} pose frames detected` : 'No pose data'}
        </span>
      </h3>

      {/* Video + Canvas container */}
      <div
        ref={containerRef}
        className="relative rounded-lg overflow-hidden bg-black"
        style={{ maxWidth: '100%' }}
      >
        <video
          ref={videoRef}
          onLoadedMetadata={handleVideoLoaded}
          onTimeUpdate={handleTimeUpdate}
          onEnded={() => setPlaying(false)}
          className="w-full"
          style={{ display: 'block' }}
          playsInline
        />

        {/* Skeleton overlay canvas */}
        <canvas
          ref={canvasRef}
          width={videoSize.width}
          height={videoSize.height}
          className="absolute inset-0 pointer-events-none w-full h-full"
          style={{ objectFit: 'contain' }}
        />
      </div>

      {/* Controls */}
      <div className="mt-3 space-y-3">
        {/* Row 1: Play controls + Timeline */}
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

          {/* Frame-by-frame buttons */}
          <button
            onClick={prevFrame}
            disabled={frames.length === 0}
            className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors disabled:opacity-50"
            title="Previous frame (,)"
          >
            <ChevronLeft className="w-4 h-4 text-pool-dark" />
          </button>
          <button
            onClick={nextFrame}
            disabled={frames.length === 0}
            className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors disabled:opacity-50"
            title="Next frame (.)"
          >
            <ChevronRight className="w-4 h-4 text-pool-dark" />
          </button>

          {/* Skip buttons */}
          <button
            onClick={() => skip(-1)}
            className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
            title="Skip -1s"
          >
            <SkipBack className="w-4 h-4 text-pool-dark" />
          </button>
          <button
            onClick={() => skip(1)}
            className="w-8 h-8 rounded-lg bg-pool-light/50 hover:bg-pool-light flex items-center justify-center transition-colors"
            title="Skip +1s"
          >
            <SkipForward className="w-4 h-4 text-pool-dark" />
          </button>

          {/* Timeline */}
          <div className="flex-1 flex items-center gap-2">
            <span className="text-xs text-pool-mid font-mono">
              {currentTime.toFixed(1)}s
            </span>
            <input
              type="range"
              min={0}
              max={duration || 100}
              step={0.01}
              value={currentTime}
              onChange={(e) => seekTo(parseFloat(e.target.value))}
              className="flex-1 accent-pool-mid"
            />
            <span className="text-xs text-pool-mid font-mono">
              {duration.toFixed(1)}s
            </span>
          </div>
        </div>

        {/* Row 2: Playback speed + Frame info */}
        <div className="flex items-center gap-4">
          {/* Playback speed */}
          <div className="flex items-center gap-2">
            <Gauge className="w-4 h-4 text-pool-mid" />
            <select
              value={playbackSpeed}
              onChange={(e) => setPlaybackSpeed(parseFloat(e.target.value))}
              className="rounded-lg border border-pool-light/50 px-2 py-1.5 text-xs font-semibold text-pool-dark
                bg-white/80 focus:border-pool-mid outline-none"
            >
              {PLAYBACK_SPEEDS.map(speed => (
                <option key={speed} value={speed}>
                  {speed}x
                </option>
              ))}
            </select>
          </div>

          {/* Frame info */}
          {frames.length > 0 && (
            <div className="text-xs text-pool-mid">
              Frame <span className="font-semibold text-pool-dark">{currentFrameIndex + 1}</span> / {frames.length}
              {frames[currentFrameIndex] && (
                <span className="ml-2">
                  ({frames[currentFrameIndex].timestamp}ms)
                </span>
              )}
            </div>
          )}

          {/* Real-time kick rate */}
          {currentKickRate && currentKickRate.confidence > 1 && (
            <div className="text-xs text-pool-mid flex items-center gap-1">
              <span className="font-semibold text-pool-dark">
                {Math.round(currentKickRate.kickRatePerMin)} kicks/min
              </span>
              <span className="opacity-60">
                (conf: {currentKickRate.confidence.toFixed(1)})
              </span>
            </div>
          )}

          {/* Estimated FPS */}
          {frames.length > 0 && duration > 0 && (
            <div className="text-xs text-pool-mid">
              ~{Math.round(frames.length / duration)} FPS captured
            </div>
          )}
        </div>
      </div>

      {/* Keyboard shortcuts hint */}
      <p className="mt-2 text-xs text-pool-mid/60 text-center">
        Space/K = play/pause • ←→ = skip 1s • ,/. = frame step • Speed: {playbackSpeed}x
      </p>
    </div>
  );
}