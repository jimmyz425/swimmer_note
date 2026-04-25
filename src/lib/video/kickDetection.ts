// FFT-based kick rate detection
// Uses Fast Fourier Transform to find dominant frequency in ankle movement

import { PoseLandmark, FrameData, LANDMARKS } from './metrics';

/**
 * Simple FFT implementation for frequency analysis
 * Uses Cooley-Tukey algorithm for power-of-2 sizes
 */
function fft(signal: number[]): { frequencies: number[]; magnitudes: number[] } {
  const n = signal.length;

  // Pad to next power of 2 if needed
  const paddedN = Math.pow(2, Math.ceil(Math.log2(n)));
  const padded = [...signal, ...Array(paddedN - n).fill(0)];

  // Compute FFT
  const real = new Float64Array(padded);
  const imag = new Float64Array(paddedN);

  // Bit reversal permutation
  for (let i = 0; i < paddedN; i++) {
    const j = reverseBits(i, paddedN);
    if (j > i) {
      [real[i], real[j]] = [real[j], real[i]];
    }
  }

  // Cooley-Tukey iterative FFT
  for (let size = 2; size <= paddedN; size *= 2) {
    const halfSize = size / 2;
    const angle = -2 * Math.PI / size;

    for (let i = 0; i < paddedN; i += size) {
      for (let j = 0; j < halfSize; j++) {
        const cos = Math.cos(angle * j);
        const sin = Math.sin(angle * j);

        const idx1 = i + j;
        const idx2 = i + j + halfSize;

        const tReal = real[idx2] * cos - imag[idx2] * sin;
        const tImag = real[idx2] * sin + imag[idx2] * cos;

        real[idx2] = real[idx1] - tReal;
        imag[idx2] = imag[idx1] - tImag;
        real[idx1] = real[idx1] + tReal;
        imag[idx1] = imag[idx1] + tImag;
      }
    }
  }

  // Compute magnitudes and frequencies
  const magnitudes: number[] = [];
  const frequencies: number[] = [];
  const sampleRate = 30; // Default 30 fps, will be adjusted

  for (let i = 0; i < paddedN / 2; i++) {
    magnitudes.push(Math.sqrt(real[i] * real[i] + imag[i] * imag[i]));
    frequencies.push(i * sampleRate / paddedN);
  }

  return { frequencies, magnitudes };
}

function reverseBits(n: number, bits: number): number {
  let result = 0;
  for (let i = 0; i < Math.log2(bits); i++) {
    result = (result << 1) | (n & 1);
    n >>= 1;
  }
  return result;
}

/**
 * Apply Hamming window function to reduce spectral leakage
 * Hamming window: w(n) = 0.54 - 0.46 * cos(2*pi*n/(N-1))
 * Unlike Hann, Hamming doesn't zero the edges, preserving more signal
 */
function applyWindow(signal: number[]): number[] {
  const n = signal.length;
  if (n < 2) return signal;

  return signal.map((val, i) => {
    // Hamming window - doesn't zero the edges
    const windowVal = 0.54 - 0.46 * Math.cos(2 * Math.PI * i / (n - 1));
    return val * windowVal;
  });
}

/**
 * Apply temporal smoothing using forward-backward filtering
 * This prevents phase shift and handles zero values better
 */
function smoothSignal(values: number[], smoothFactor: number = 0.3): number[] {
  if (values.length < 2) return values;

  // Find first non-zero value to use as starting point
  let firstNonZeroIdx = 0;
  for (let i = 0; i < values.length; i++) {
    if (values[i] > 0) {
      firstNonZeroIdx = i;
      break;
    }
  }

  const initialVal = firstNonZeroIdx < values.length ? values[firstNonZeroIdx] : 0;

  // Forward pass
  const forward: number[] = [];
  let prev = initialVal;
  for (let i = 0; i < values.length; i++) {
    if (values[i] === 0 && i < firstNonZeroIdx) {
      forward.push(0);
    } else {
      prev = smoothFactor * prev + (1 - smoothFactor) * values[i];
      forward.push(prev);
    }
  }

  // Backward pass (removes phase shift)
  const backward: number[] = [];
  prev = forward[forward.length - 1];
  for (let i = forward.length - 1; i >= 0; i--) {
    if (forward[i] === 0 && i < firstNonZeroIdx) {
      backward.unshift(0);
    } else {
      prev = smoothFactor * prev + (1 - smoothFactor) * forward[i];
      backward.unshift(prev);
    }
  }

  return backward;
}

/**
 * Extract ankle Y position signal from frames
 */
function extractAnkleSignal(frames: FrameData[]): { left: number[]; right: number[]; timestamps: number[] } {
  const left: number[] = [];
  const right: number[] = [];
  const timestamps: number[] = [];

  for (const frame of frames) {
    const leftAnkle = frame.landmarks[LANDMARKS.LEFT_ANKLE];
    const rightAnkle = frame.landmarks[LANDMARKS.RIGHT_ANKLE];

    // Use Y position (vertical movement indicates kicks)
    // Normalize: subtract mean to center signal
    left.push(leftAnkle?.y || 0.5);
    right.push(rightAnkle?.y || 0.5);
    timestamps.push(frame.timestamp);
  }

  return { left, right, timestamps };
}

/**
 * Extract knee Y position signal from frames
 * Kicks also involve knee movement, so knees provide additional frequency signal
 */
function extractKneeSignal(frames: FrameData[]): { left: number[]; right: number[]; timestamps: number[] } {
  const left: number[] = [];
  const right: number[] = [];
  const timestamps: number[] = [];

  for (const frame of frames) {
    const leftKnee = frame.landmarks[LANDMARKS.LEFT_KNEE];
    const rightKnee = frame.landmarks[LANDMARKS.RIGHT_KNEE];

    left.push(leftKnee?.y || 0.5);
    right.push(rightKnee?.y || 0.5);
    timestamps.push(frame.timestamp);
  }

  return { left, right, timestamps };
}

/**
 * Remove mean from signal (center it)
 */
function centerSignal(signal: number[]): number[] {
  const mean = signal.reduce((a, b) => a + b, 0) / signal.length;
  return signal.map(x => x - mean);
}

/**
 * Find dominant frequency using FFT
 * Returns frequency in Hz (cycles per second)
 * Uses Hann window to reduce spectral leakage for smoother output
 */
function findDominantFrequency(
  signal: number[],
  fps: number,
  minFreq: number = 0.5, // Minimum 0.5 Hz (30 kicks/min)
  maxFreq: number = 6    // Maximum 6 Hz (360 kicks/min)
): { frequency: number; magnitude: number; confidence: number } {
  if (signal.length < 10) {
    return { frequency: 0, magnitude: 0, confidence: 0 };
  }

  // Center the signal
  const centered = centerSignal(signal);

  // Apply Hamming window for smoother frequency analysis
  const windowed = applyWindow(centered);

  // Compute FFT
  const n = windowed.length;
  const paddedN = Math.pow(2, Math.ceil(Math.log2(n)));
  const padded = [...windowed, ...Array(paddedN - n).fill(0)];

  // Simple DFT for small signals (more accurate than iterative FFT for this case)
  const magnitudes: number[] = [];
  const frequencies: number[] = [];

  for (let k = 0; k < paddedN / 2; k++) {
    let real = 0;
    let imag = 0;

    for (let t = 0; t < paddedN; t++) {
      const angle = -2 * Math.PI * k * t / paddedN;
      real += padded[t] * Math.cos(angle);
      imag += padded[t] * Math.sin(angle);
    }

    const magnitude = Math.sqrt(real * real + imag * imag) / paddedN;
    const frequency = k * fps / paddedN;

    magnitudes.push(magnitude);
    frequencies.push(frequency);
  }

  // Find peak in valid frequency range
  let maxMagnitude = 0;
  let dominantFreq = 0;
  let peakIdx = 0;

  for (let i = 0; i < frequencies.length; i++) {
    const freq = frequencies[i];
    const mag = magnitudes[i];

    if (freq >= minFreq && freq <= maxFreq && mag > maxMagnitude) {
      maxMagnitude = mag;
      dominantFreq = freq;
      peakIdx = i;
    }
  }

  // Compute confidence based on peak prominence
  // Compare peak to average magnitude
  const avgMagnitude = magnitudes.reduce((a, b) => a + b, 0) / magnitudes.length;
  const confidence = maxMagnitude > 0 ? maxMagnitude / (avgMagnitude + 0.001) : 0;

  return {
    frequency: dominantFreq,
    magnitude: maxMagnitude,
    confidence: Math.min(confidence, 10) // Cap at 10
  };
}

/**
 * Compute kick rate from a window of frames
 * Fuses ankle and knee frequencies for more accurate kick detection
 * @param frames - Array of frame data with landmarks
 * @param windowStart - Start time in ms
 * @param windowEnd - End time in ms (typically 1000ms window)
 * @returns Kick rate in Hz and kicks per minute with fused frequency
 */
export function computeKickRateInWindow(
  frames: FrameData[],
  windowStart: number,
  windowEnd: number
): {
  kickRateHz: number;
  kickRatePerMin: number;
  confidence: number;
  ankleHz: number;
  kneeHz: number;
  ankleConfidence: number;
  kneeConfidence: number;
} {
  // Filter frames in window
  const windowFrames = frames.filter(f =>
    f.timestamp >= windowStart && f.timestamp <= windowEnd
  );

  if (windowFrames.length < 10) {
    return {
      kickRateHz: 0,
      kickRatePerMin: 0,
      confidence: 0,
      ankleHz: 0,
      kneeHz: 0,
      ankleConfidence: 0,
      kneeConfidence: 0
    };
  }

  // Calculate actual FPS from timestamps
  const duration = windowEnd - windowStart;
  const fps = windowFrames.length / (duration / 1000);

  // Extract ankle signals
  const ankleSignals = extractAnkleSignal(windowFrames);

  // Extract knee signals (secondary source)
  const kneeSignals = extractKneeSignal(windowFrames);

  // Compute FFT for ankles (both feet)
  const leftAnkleResult = findDominantFrequency(ankleSignals.left, fps);
  const rightAnkleResult = findDominantFrequency(ankleSignals.right, fps);
  const bestAnkleResult = leftAnkleResult.confidence > rightAnkleResult.confidence ? leftAnkleResult : rightAnkleResult;

  // Compute FFT for knees (both legs)
  const leftKneeResult = findDominantFrequency(kneeSignals.left, fps);
  const rightKneeResult = findDominantFrequency(kneeSignals.right, fps);
  const bestKneeResult = leftKneeResult.confidence > rightKneeResult.confidence ? leftKneeResult : rightKneeResult;

  // Fuse ankle and knee frequencies
  // Weight by confidence - higher confidence gets more weight
  const ankleWeight = bestAnkleResult.confidence;
  const kneeWeight = bestKneeResult.confidence;
  const totalWeight = ankleWeight + kneeWeight;

  let fusedHz = 0;
  let fusedConfidence = 0;

  if (totalWeight > 0) {
    // Weighted average of frequencies
    fusedHz = (bestAnkleResult.frequency * ankleWeight + bestKneeResult.frequency * kneeWeight) / totalWeight;
    // Fused confidence is the average, scaled by agreement between the two
    const agreement = Math.abs(bestAnkleResult.frequency - bestKneeResult.frequency) < 0.5 ? 1.5 : 1.0;
    fusedConfidence = Math.max(bestAnkleResult.confidence, bestKneeResult.confidence) * agreement;
  } else if (bestAnkleResult.confidence > 0) {
    // Only ankle has valid data
    fusedHz = bestAnkleResult.frequency;
    fusedConfidence = bestAnkleResult.confidence;
  } else if (bestKneeResult.confidence > 0) {
    // Only knee has valid data
    fusedHz = bestKneeResult.frequency;
    fusedConfidence = bestKneeResult.confidence;
  }

  return {
    kickRateHz: fusedHz,
    kickRatePerMin: fusedHz * 60,
    confidence: Math.min(fusedConfidence, 10),
    ankleHz: bestAnkleResult.frequency,
    kneeHz: bestKneeResult.frequency,
    ankleConfidence: bestAnkleResult.confidence,
    kneeConfidence: bestKneeResult.confidence,
  };
}

/**
 * Extract wrist Y position signal from frames for stroke detection
 */
function extractWristSignal(frames: FrameData[]): { left: number[]; right: number[]; timestamps: number[] } {
  const left: number[] = [];
  const right: number[] = [];
  const timestamps: number[] = [];

  for (const frame of frames) {
    const leftWrist = frame.landmarks[LANDMARKS.LEFT_WRIST];
    const rightWrist = frame.landmarks[LANDMARKS.RIGHT_WRIST];

    left.push(leftWrist?.y || 0.5);
    right.push(rightWrist?.y || 0.5);
    timestamps.push(frame.timestamp);
  }

  return { left, right, timestamps };
}

/**
 * Compute stroke rate from a window of frames using FFT
 * @param frames - Array of frame data with landmarks
 * @param windowStart - Start time in ms
 * @param windowEnd - End time in ms (typically 3000ms window)
 * @param minAmplitude - Minimum motion amplitude to count (default 0.05 = 5% of frame height)
 * @returns Stroke rate in Hz and strokes per minute
 */
export function computeStrokeRateInWindow(
  frames: FrameData[],
  windowStart: number,
  windowEnd: number,
  minAmplitude: number = 0.05
): {
  strokeRateHz: number;
  strokeRatePerMin: number;
  confidence: number;
  amplitude: number;
} {
  // Filter frames in window
  const windowFrames = frames.filter(f =>
    f.timestamp >= windowStart && f.timestamp <= windowEnd
  );

  if (windowFrames.length < 15) {
    return { strokeRateHz: 0, strokeRatePerMin: 0, confidence: 0, amplitude: 0 };
  }

  // Calculate actual FPS from timestamps
  const duration = windowEnd - windowStart;
  const fps = windowFrames.length / (duration / 1000);

  // Extract wrist signals
  const { left, right } = extractWristSignal(windowFrames);

  // Calculate amplitude (range of motion)
  const leftMin = Math.min(...left);
  const leftMax = Math.max(...left);
  const leftAmplitude = leftMax - leftMin;

  const rightMin = Math.min(...right);
  const rightMax = Math.max(...right);
  const rightAmplitude = rightMax - rightMin;

  const maxAmplitude = Math.max(leftAmplitude, rightAmplitude);

  // If motion is too small, don't count
  if (maxAmplitude < minAmplitude) {
    return {
      strokeRateHz: 0,
      strokeRatePerMin: 0,
      confidence: 0,
      amplitude: maxAmplitude
    };
  }

  // Use the wrist with larger amplitude
  const bestSignal = leftAmplitude > rightAmplitude ? left : right;

  // Stroke frequency range: 0.3 Hz (18 spm) to 2 Hz (120 spm)
  const minFreq = 0.3;
  const maxFreq = 2;

  // Compute FFT
  const result = findDominantFrequency(bestSignal, fps, minFreq, maxFreq);

  return {
    strokeRateHz: result.frequency,
    strokeRatePerMin: result.frequency * 60,
    confidence: result.confidence,
    amplitude: maxAmplitude,
  };
}

/**
 * Compute real-time stroke rates for all frames
 * Uses 3-second sliding window for smoother results
 */
export function computeRealtimeStrokeRates(frames: FrameData[]): Array<{
  timestamp: number;
  strokeRateHz: number;
  strokeRatePerMin: number;
  confidence: number;
  amplitude: number;
}> {
  if (frames.length === 0) return [];

  const windowSize = 3000; // 3 second window for stroke
  const rawResults: Array<{
    timestamp: number;
    strokeRateHz: number;
    strokeRatePerMin: number;
    confidence: number;
    amplitude: number;
  }> = [];

  // Compute raw stroke rates for each frame with centered moving window
  for (const frame of frames) {
    const windowStart = Math.max(0, frame.timestamp - windowSize / 2);
    const windowEnd = frame.timestamp + windowSize / 2;

    const strokeRate = computeStrokeRateInWindow(frames, windowStart, windowEnd);

    rawResults.push({
      timestamp: frame.timestamp,
      strokeRateHz: strokeRate.strokeRateHz,
      strokeRatePerMin: strokeRate.strokeRatePerMin,
      confidence: strokeRate.confidence,
      amplitude: strokeRate.amplitude,
    });
  }

  // Apply temporal smoothing for smooth display
  const rawHz = rawResults.map(r => r.strokeRateHz);
  const smoothedHz = smoothSignal(rawHz, 0.25);

  const rawConf = rawResults.map(r => r.confidence);
  const smoothedConf = smoothSignal(rawConf, 0.2);

  return rawResults.map((r, i) => ({
    timestamp: r.timestamp,
    strokeRateHz: smoothedHz[i],
    strokeRatePerMin: smoothedHz[i] * 60,
    confidence: smoothedConf[i],
    amplitude: r.amplitude,
  }));
}

/**
 * Get average stroke rate from real-time data
 * Excludes windows with low amplitude or low frequency
 */
export function getAverageStrokeRate(realtimeRates: Array<{
  strokeRateHz: number;
  confidence: number;
  amplitude: number;
}>): {
  averageHz: number;
  averagePerMin: number;
  peakHz: number;
  validCount: number;
  totalCount: number;
} {
  const totalCount = realtimeRates.length;

  // Filter: amplitude > 0.05 AND strokeRateHz > 0
  const validRates = realtimeRates.filter(r =>
    r.amplitude >= 0.05 && r.strokeRateHz > 0 && r.confidence > 1
  );

  if (validRates.length === 0) {
    return { averageHz: 0, averagePerMin: 0, peakHz: 0, validCount: 0, totalCount };
  }

  // Find peak frequency
  const peakHz = Math.max(...validRates.map(r => r.strokeRateHz));
  const minValidHz = peakHz * 0.5;

  // Further filter by frequency threshold
  const goodRates = validRates.filter(r => r.strokeRateHz >= minValidHz);

  if (goodRates.length === 0) {
    return { averageHz: 0, averagePerMin: 0, peakHz, validCount: validRates.length, totalCount };
  }

  // Weighted average by confidence
  const totalWeight = goodRates.reduce((a, b) => a + b.confidence, 0);
  const weightedSum = goodRates.reduce((a, b) => a + b.strokeRateHz * b.confidence, 0);
  const averageHz = weightedSum / totalWeight;

  return {
    averageHz,
    averagePerMin: averageHz * 60,
    peakHz,
    validCount: goodRates.length,
    totalCount,
  };
}

/**
 * Compute real-time kick rates for all frames
 * Returns an array of kick rates for each frame based on 1-second moving window
 * Applies temporal smoothing for smooth frequency display
 */
export function computeRealtimeKickRates(frames: FrameData[]): Array<{
  timestamp: number;
  kickRateHz: number;
  kickRatePerMin: number;
  confidence: number;
}> {
  if (frames.length === 0) return [];

  const windowSize = 1000; // 1 second window
  const rawResults: Array<{
    timestamp: number;
    kickRateHz: number;
    kickRatePerMin: number;
    confidence: number;
  }> = [];

  // Compute raw kick rates for each frame with centered moving window
  for (const frame of frames) {
    const windowStart = Math.max(0, frame.timestamp - windowSize / 2);
    const windowEnd = frame.timestamp + windowSize / 2;

    const kickRate = computeKickRateInWindow(frames, windowStart, windowEnd);

    rawResults.push({
      timestamp: frame.timestamp,
      kickRateHz: kickRate.kickRateHz,
      kickRatePerMin: kickRate.kickRatePerMin,
      confidence: kickRate.confidence,
    });
  }

  // Apply temporal smoothing to kick rate Hz for smooth display
  const rawHz = rawResults.map(r => r.kickRateHz);
  const smoothedHz = smoothSignal(rawHz, 0.25); // 25% smoothing factor

  // Apply smoothing to confidence as well
  const rawConf = rawResults.map(r => r.confidence);
  const smoothedConf = smoothSignal(rawConf, 0.2);

  // Combine smoothed values with original results
  return rawResults.map((r, i) => ({
    timestamp: r.timestamp,
    kickRateHz: smoothedHz[i],
    kickRatePerMin: smoothedHz[i] * 60,
    confidence: smoothedConf[i],
  }));
}

/**
 * Get average kick rate from real-time data
 * Excludes low frequency blocks (below 50% of peak frequency)
 * and low confidence readings
 */
export function getAverageKickRate(realtimeRates: Array<{ kickRateHz: number; confidence: number }>): {
  averageHz: number;
  averagePerMin: number;
  peakHz: number;
  validCount: number;
  totalCount: number;
} {
  const totalCount = realtimeRates.length;

  // Filter out zero/invalid readings first
  const nonZeroRates = realtimeRates.filter(r => r.kickRateHz > 0);

  if (nonZeroRates.length === 0) {
    return { averageHz: 0, averagePerMin: 0, peakHz: 0, validCount: 0, totalCount };
  }

  // Find peak frequency across all readings
  const peakHz = Math.max(...nonZeroRates.map(r => r.kickRateHz));
  const minValidHz = peakHz * 0.5; // 50% threshold

  // Filter: confidence > 1 AND frequency >= 50% of peak
  const validRates = nonZeroRates.filter(r =>
    r.confidence > 1 && r.kickRateHz >= minValidHz
  );

  if (validRates.length === 0) {
    // Return peakHz even if no valid rates for average
    return { averageHz: 0, averagePerMin: 0, peakHz, validCount: 0, totalCount };
  }

  // Weighted average by confidence
  const totalWeight = validRates.reduce((a, b) => a + b.confidence, 0);
  const weightedSum = validRates.reduce((a, b) => a + b.kickRateHz * b.confidence, 0);
  const averageHz = weightedSum / totalWeight;

  return {
    averageHz,
    averagePerMin: averageHz * 60,
    peakHz,
    validCount: validRates.length,
    totalCount,
  };
}