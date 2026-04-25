import {
  computeKickRateInWindow,
  computeRealtimeKickRates,
  getAverageKickRate,
  computeStrokeRateInWindow,
  computeRealtimeStrokeRates,
  getAverageStrokeRate
} from './kickDetection';

// Pose landmark indices (MediaPipe standard)
export const LANDMARKS = {
  NOSE: 0,
  LEFT_EYE: 1,
  RIGHT_EYE: 2,
  LEFT_EAR: 7,
  RIGHT_EAR: 8,
  LEFT_SHOULDER: 11,
  RIGHT_SHOULDER: 12,
  LEFT_ELBOW: 13,
  RIGHT_ELBOW: 14,
  LEFT_WRIST: 15,
  RIGHT_WRIST: 16,
  LEFT_HIP: 23,
  RIGHT_HIP: 24,
  LEFT_KNEE: 25,
  RIGHT_KNEE: 26,
  LEFT_ANKLE: 27,
  RIGHT_ANKLE: 28,
};

export interface PoseLandmark {
  x: number; // 0-1 normalized
  y: number; // 0-1 normalized (0 = top, 1 = bottom)
  z: number; // depth
  visibility: number; // 0-1 confidence
}

export interface FrameData {
  timestamp: number; // ms from video start
  landmarks: PoseLandmark[];
}

export interface RealtimeKickRate {
  timestamp: number;
  kickRateHz: number;
  kickRatePerMin: number;
  confidence: number;
}

export interface RealtimeStrokeRate {
  timestamp: number;
  strokeRateHz: number;
  strokeRatePerMin: number;
  confidence: number;
  amplitude: number;
}

export interface AnalysisMetrics {
  strokeRate: number;
  strokeRateHz: number;
  strokeRatePeakHz: number;
  strokeRateValidWindows: number;
  strokeRateTotalWindows: number;
  realtimeStrokeRates: RealtimeStrokeRate[];
  kickRate: number;
  kickRateHz: number;
  kickRateConfidence: number;
  kickRatePeakHz: number;
  kickRateValidWindows: number;
  kickRateTotalWindows: number;
  realtimeKickRates: RealtimeKickRate[];
  bodyAngleAvg: number;
  bodyAngleMin: number;
  bodyAngleMax: number;
  armEntryAngleAvg: number;
  elbowHeightAvg: number;
}

// Calculate angle between two vectors
function angleBetween(v1: { x: number; y: number }, v2: { x: number; y: number }): number {
  const dot = v1.x * v2.x + v1.y * v2.y;
  const mag1 = Math.sqrt(v1.x * v1.x + v1.y * v1.y);
  const mag2 = Math.sqrt(v2.x * v2.x + v2.y * v2.y);
  return Math.acos(dot / (mag1 * mag2)) * (180 / Math.PI);
}

// Find peaks in a signal (for stroke/kick detection)
function findPeaks(signal: number[], minDistance: number = 5): number[] {
  const peaks: number[] = [];
  for (let i = 1; i < signal.length - 1; i++) {
    if (signal[i] > signal[i - 1] && signal[i] > signal[i + 1]) {
      // Check if far enough from previous peak
      if (peaks.length === 0 || i - peaks[peaks.length - 1] >= minDistance) {
        peaks.push(i);
      }
    }
  }
  return peaks;
}

// Detect stroke rate using FFT analysis of wrist movement
// Uses 3-second window, filters out small motion periods
export function detectStrokeRate(frames: FrameData[]): {
  strokeRateHz: number;
  strokeRatePerMin: number;
  peakHz: number;
  validWindowCount: number;
  totalWindowCount: number;
  realtimeStrokeRates: RealtimeStrokeRate[];
} {
  if (frames.length < 15) {
    return {
      strokeRateHz: 0,
      strokeRatePerMin: 0,
      peakHz: 0,
      validWindowCount: 0,
      totalWindowCount: 0,
      realtimeStrokeRates: []
    };
  }

  // Compute real-time stroke rates using 3-second window
  const realtimeStrokeRates = computeRealtimeStrokeRates(frames);

  // Get average stroke rate excluding low amplitude/low frequency windows
  const avgResult = getAverageStrokeRate(realtimeStrokeRates);

  return {
    strokeRateHz: avgResult.averageHz,
    strokeRatePerMin: avgResult.averagePerMin,
    peakHz: avgResult.peakHz,
    validWindowCount: avgResult.validCount,
    totalWindowCount: avgResult.totalCount,
    realtimeStrokeRates,
  };
}

// Detect kick rate using FFT analysis of ankle movement
// Returns kicks per second (Hz) using frequency analysis
// Excludes low frequency blocks (below 50% of peak) from statistics
export function detectKickRate(frames: FrameData[]): {
  kickRateHz: number;
  kickRatePerMin: number;
  confidence: number;
  peakHz: number;
  validWindowCount: number;
  totalWindowCount: number;
  realtimeKickRates: RealtimeKickRate[];
} {
  if (frames.length < 10) {
    return {
      kickRateHz: 0,
      kickRatePerMin: 0,
      confidence: 0,
      peakHz: 0,
      validWindowCount: 0,
      totalWindowCount: 0,
      realtimeKickRates: []
    };
  }

  // Compute real-time kick rates for all frames
  const realtimeKickRates = computeRealtimeKickRates(frames);

  // Get average kick rate weighted by confidence, excluding low frequency blocks
  const avgResult = getAverageKickRate(realtimeKickRates);

  return {
    kickRateHz: avgResult.averageHz,
    kickRatePerMin: avgResult.averagePerMin,
    confidence: realtimeKickRates.length > 0
      ? realtimeKickRates.reduce((a, b) => a + b.confidence, 0) / realtimeKickRates.length
      : 0,
    peakHz: avgResult.peakHz,
    validWindowCount: avgResult.validCount,
    totalWindowCount: avgResult.totalCount,
    realtimeKickRates,
  };
}

// Calculate body angle from shoulder-hip alignment
export function calculateBodyAngle(landmarks: PoseLandmark[]): number {
  const leftShoulder = landmarks[LANDMARKS.LEFT_SHOULDER];
  const rightShoulder = landmarks[LANDMARKS.RIGHT_SHOULDER];
  const leftHip = landmarks[LANDMARKS.LEFT_HIP];
  const rightHip = landmarks[LANDMARKS.RIGHT_HIP];

  // Calculate midpoint of shoulders and hips
  const shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
  const hipMidY = (leftHip.y + rightHip.y) / 2;

  // Calculate midpoint X for horizontal reference
  const shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2;
  const hipMidX = (leftHip.x + rightHip.x) / 2;

  // Vector from hip to shoulder
  const dx = shoulderMidX - hipMidX;
  const dy = shoulderMidY - hipMidY;

  // Angle from horizontal (0 = perfectly horizontal)
  // Positive = shoulders higher (good for backstroke)
  // Negative = hips lower (good for freestyle/butterfly)
  const angle = Math.atan2(dy, dx) * (180 / Math.PI);

  return angle;
}

// Calculate body angles across all frames
export function analyzeBodyAngles(frames: FrameData[]): { avg: number; min: number; max: number } {
  const angles = frames.map(f => calculateBodyAngle(f.landmarks)).filter(a => !isNaN(a));

  if (angles.length === 0) return { avg: 0, min: 0, max: 0 };

  return {
    avg: angles.reduce((a, b) => a + b, 0) / angles.length,
    min: Math.min(...angles),
    max: Math.max(...angles),
  };
}

// Calculate elbow height relative to wrist during catch phase
export function analyzeElbowHeight(frames: FrameData[]): number {
  // Track elbow vs wrist Y position difference
  const elbowHeights = frames.map(f => {
    const leftElbow = f.landmarks[LANDMARKS.LEFT_ELBOW];
    const leftWrist = f.landmarks[LANDMARKS.LEFT_WRIST];
    const rightElbow = f.landmarks[LANDMARKS.RIGHT_ELBOW];
    const rightWrist = f.landmarks[LANDMARKS.RIGHT_WRIST];

    // Higher elbow = elbow.y < wrist.y (lower Y value = higher position)
    // Calculate relative height (positive = elbow above wrist = good high elbow)
    const leftHeight = leftWrist.y - leftElbow.y;
    const rightHeight = rightWrist.y - rightElbow.y;

    // Use more visible side
    if (leftElbow.visibility > rightElbow.visibility) {
      return leftHeight;
    }
    return rightHeight;
  }).filter(h => h > -0.5 && h < 0.5); // Filter outliers

  if (elbowHeights.length === 0) return 0;
  return elbowHeights.reduce((a, b) => a + b, 0) / elbowHeights.length;
}

// Full analysis pipeline
export function analyzePoseData(frames: FrameData[]): AnalysisMetrics {
  const bodyAngles = analyzeBodyAngles(frames);
  const kickRateResult = detectKickRate(frames);
  const strokeRateResult = detectStrokeRate(frames);

  return {
    strokeRate: strokeRateResult.strokeRatePerMin,
    strokeRateHz: strokeRateResult.strokeRateHz,
    strokeRatePeakHz: strokeRateResult.peakHz,
    strokeRateValidWindows: strokeRateResult.validWindowCount,
    strokeRateTotalWindows: strokeRateResult.totalWindowCount,
    realtimeStrokeRates: strokeRateResult.realtimeStrokeRates,
    kickRate: kickRateResult.kickRatePerMin,
    kickRateHz: kickRateResult.kickRateHz,
    kickRateConfidence: kickRateResult.confidence,
    kickRatePeakHz: kickRateResult.peakHz,
    kickRateValidWindows: kickRateResult.validWindowCount,
    kickRateTotalWindows: kickRateResult.totalWindowCount,
    realtimeKickRates: kickRateResult.realtimeKickRates,
    bodyAngleAvg: bodyAngles.avg,
    bodyAngleMin: bodyAngles.min,
    bodyAngleMax: bodyAngles.max,
    armEntryAngleAvg: 0,
    elbowHeightAvg: analyzeElbowHeight(frames),
  };
}