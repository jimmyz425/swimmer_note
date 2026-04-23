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

export interface AnalysisMetrics {
  strokeRate: number;
  kickRate: number;
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

// Detect stroke rate from wrist position cycles
export function detectStrokeRate(frames: FrameData[]): number {
  // Track wrist Y position (vertical movement indicates stroke cycle)
  const wristYPositions = frames.map(f => {
    const leftWrist = f.landmarks[LANDMARKS.LEFT_WRIST];
    const rightWrist = f.landmarks[LANDMARKS.RIGHT_WRIST];
    // Use average of both wrists, weighted by visibility
    const leftWeight = leftWrist.visibility || 0;
    const rightWeight = rightWrist.visibility || 0;
    const totalWeight = leftWeight + rightWeight;
    if (totalWeight === 0) return 0.5; // fallback
    return (leftWrist.y * leftWeight + rightWrist.y * rightWeight) / totalWeight;
  });

  // Find peaks in wrist movement (stroke cycles)
  const peaks = findPeaks(wristYPositions, 10);

  if (peaks.length < 2) return 0;

  // Calculate average time between strokes
  const totalTimeMs = frames[frames.length - 1].timestamp - frames[0].timestamp;
  const strokeCount = peaks.length;

  // strokes per minute = (strokes / total time in seconds) * 60
  const totalTimeSec = totalTimeMs / 1000;
  return (strokeCount / totalTimeSec) * 60;
}

// Detect kick rate from ankle vertical oscillation
export function detectKickRate(frames: FrameData[]): number {
  // Track ankle Y position
  const ankleYPositions = frames.map(f => {
    const leftAnkle = f.landmarks[LANDMARKS.LEFT_ANKLE];
    const rightAnkle = f.landmarks[LANDMARKS.RIGHT_ANKLE];
    const avgY = (leftAnkle.y + rightAnkle.y) / 2;
    return avgY;
  });

  // Calculate oscillation amplitude to determine if valid kick data
  const minY = Math.min(...ankleYPositions);
  const maxY = Math.max(...ankleYPositions);
  const amplitude = maxY - minY;

  // Need at least 5% variation to detect kicks
  if (amplitude < 0.05) return 0;

  // Find peaks in ankle movement (kick cycles)
  // For flutter kick, peaks should be closer together
  const peaks = findPeaks(ankleYPositions, 3);

  if (peaks.length < 2) return 0;

  // kicks per second
  const totalTimeMs = frames[frames.length - 1].timestamp - frames[0].timestamp;
  const totalTimeSec = totalTimeMs / 1000;
  const kickCount = peaks.length;

  return kickCount / totalTimeSec;
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

  return {
    strokeRate: detectStrokeRate(frames),
    kickRate: detectKickRate(frames),
    bodyAngleAvg: bodyAngles.avg,
    bodyAngleMin: bodyAngles.min,
    bodyAngleMax: bodyAngles.max,
    armEntryAngleAvg: 0, // TODO: implement arm entry tracking
    elbowHeightAvg: analyzeElbowHeight(frames),
  };
}