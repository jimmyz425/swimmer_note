'use client';

import { useRef, useEffect, useMemo } from 'react';
import { TrendingUp } from 'lucide-react';

interface RateGraphProps {
  realtimeRates: Array<{
    timestamp: number;
    rateHz: number;
    ratePerMin: number;
    confidence: number;
  }>;
  peakHz?: number;
  minConfidence?: number;
  title?: string;
  unit?: string;
  width?: number;
  height?: number;
}

export function RateGraph({
  realtimeRates,
  peakHz,
  minConfidence = 1.5,
  title = 'Rate Over Time',
  unit = 'kpm',
  width = 600,
  height = 120,
}: RateGraphProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Calculate peak from data if not provided
  const calculatedPeakHz = useMemo(() => {
    const nonZeroRates = realtimeRates.filter(r => r.rateHz > 0);
    return nonZeroRates.length > 0 ? Math.max(...nonZeroRates.map(r => r.rateHz)) : 0;
  }, [realtimeRates]);

  const effectivePeakHz = peakHz || calculatedPeakHz;
  const minValidHz = effectivePeakHz * 0.5;

  // Filter out low confidence AND low frequency readings
  const filteredData = useMemo(() => {
    return realtimeRates.filter(r =>
      r.confidence >= minConfidence &&
      r.rateHz > 0 &&
      r.rateHz >= minValidHz
    );
  }, [realtimeRates, minConfidence, minValidHz]);

  // Calculate stats
  const stats = useMemo(() => {
    if (filteredData.length === 0) {
      return { avg: 0, min: 0, max: 0, coverage: 0 };
    }
    const rates = filteredData.map(r => r.ratePerMin);
    const avg = rates.reduce((a, b) => a + b, 0) / rates.length;
    const min = Math.min(...rates);
    const max = Math.max(...rates);
    const coverage = filteredData.length / realtimeRates.length * 100;
    return { avg, min, max, coverage };
  }, [filteredData, realtimeRates]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, width, height);

    if (filteredData.length === 0) {
      ctx.fillStyle = '#888';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('No valid data (low confidence/amplitude)', width / 2, height / 2);
      return;
    }

    const timeMin = filteredData[0].timestamp;
    const timeMax = filteredData[filteredData.length - 1].timestamp;
    const timeRange = timeMax - timeMin || 1000;
    const rateMin = Math.min(stats.min, 10);
    const rateMax = Math.max(stats.max, 150);
    const rateRange = rateMax - rateMin;

    // Grid
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    for (let y = 0; y <= 4; y++) {
      const yPos = (height - 20) * (y / 4) + 10;
      ctx.beginPath();
      ctx.moveTo(40, yPos);
      ctx.lineTo(width - 10, yPos);
      ctx.stroke();
    }

    // Y labels
    ctx.fillStyle = '#aaa';
    ctx.font = '10px monospace';
    ctx.textAlign = 'right';
    for (let y = 0; y <= 4; y++) {
      const yPos = (height - 20) * (y / 4) + 10 + 4;
      const rateValue = rateMax - (rateRange * y / 4);
      ctx.fillText(`${Math.round(rateValue)}`, 35, yPos);
    }

    // Draw rate line
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 2;
    ctx.shadowColor = '#00FF00';
    ctx.shadowBlur = 3;
    ctx.beginPath();

    const validPoints: { x: number; y: number }[] = [];
    for (let i = 0; i < filteredData.length; i++) {
      const data = filteredData[i];
      const x = 40 + ((data.timestamp - timeMin) / timeRange) * (width - 50);
      const y = 10 + ((rateMax - data.ratePerMin) / rateRange) * (height - 20);
      validPoints.push({ x, y });
    }

    if (validPoints.length > 0) {
      ctx.moveTo(validPoints[0].x, validPoints[0].y);
      for (let i = 1; i < validPoints.length; i++) {
        ctx.lineTo(validPoints[i].x, validPoints[i].y);
      }
      ctx.stroke();
    }
    ctx.shadowBlur = 0;

    // Average line
    if (stats.avg > 0) {
      const avgY = 10 + ((rateMax - stats.avg) / rateRange) * (height - 20);
      ctx.strokeStyle = '#FF6B00';
      ctx.lineWidth = 1;
      ctx.setLineDash([5, 5]);
      ctx.beginPath();
      ctx.moveTo(40, avgY);
      ctx.lineTo(width - 10, avgY);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#FF6B00';
      ctx.font = 'bold 10px sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(`avg: ${Math.round(stats.avg)}`, width - 100, avgY - 2);
    }

    // 50% threshold
    if (effectivePeakHz > 0) {
      const thresholdY = 10 + ((rateMax - minValidHz * 60) / rateRange) * (height - 20);
      ctx.strokeStyle = '#FF4444';
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(40, thresholdY);
      ctx.lineTo(width - 10, thresholdY);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Coverage
    ctx.fillStyle = stats.coverage > 50 ? '#4CAF50' : stats.coverage > 20 ? '#FFC107' : '#F44336';
    ctx.font = 'bold 10px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(`${stats.coverage.toFixed(0)}% valid`, width - 5, 15);

    // Duration
    ctx.fillStyle = '#aaa';
    ctx.font = '10px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(`${(timeRange / 1000).toFixed(1)}s`, width / 2, height - 2);

  }, [filteredData, stats, width, height, effectivePeakHz, minValidHz, unit]);

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-pool-deep" />
          <span className="text-sm font-bold text-pool-dark">{title}</span>
        </div>
        <div className="flex items-center gap-2 text-xs text-pool-mid">
          {effectivePeakHz > 0 && (
            <>
              <span>Peak: {effectivePeakHz.toFixed(2)} Hz</span>
              <span>•</span>
            </>
          )}
          <span>{filteredData.length} valid</span>
        </div>
      </div>

      <canvas
        ref={canvasRef}
        width={width}
        height={height}
        className="rounded-lg w-full"
        style={{ maxWidth: '100%', aspectRatio: `${width}/${height}` }}
      />

      {filteredData.length > 0 && (
        <div className="flex items-center justify-center gap-4 text-xs text-pool-mid">
          <span>
            <span className="inline-block w-3 h-0.5 bg-green-500 mr-1" />
            Rate
          </span>
          <span>
            <span className="inline-block w-3 h-0.5 bg-orange-500 mr-1" style={{ borderStyle: 'dashed' }} />
            Avg ({Math.round(stats.avg)} {unit})
          </span>
          <span>
            Range: {Math.round(stats.min)} - {Math.round(stats.max)} {unit}
          </span>
        </div>
      )}
    </div>
  );
}

// Kick-specific wrapper
interface KickRateGraphProps {
  realtimeKickRates: Array<{
    timestamp: number;
    kickRateHz: number;
    kickRatePerMin: number;
    confidence: number;
  }>;
  peakHz?: number;
  minConfidence?: number;
  width?: number;
  height?: number;
}

export function KickRateGraph({ realtimeKickRates, peakHz, minConfidence = 1.5, width = 600, height = 120 }: KickRateGraphProps) {
  const convertedRates = realtimeKickRates.map(r => ({
    timestamp: r.timestamp,
    rateHz: r.kickRateHz,
    ratePerMin: r.kickRatePerMin,
    confidence: r.confidence,
  }));

  return (
    <RateGraph
      realtimeRates={convertedRates}
      peakHz={peakHz}
      minConfidence={minConfidence}
      title="Kick Rate Over Time"
      unit="kpm"
      width={width}
      height={height}
    />
  );
}

// Stroke-specific wrapper
interface StrokeRateGraphProps {
  realtimeStrokeRates: Array<{
    timestamp: number;
    strokeRateHz: number;
    strokeRatePerMin: number;
    confidence: number;
    amplitude: number;
  }>;
  peakHz?: number;
  minConfidence?: number;
  width?: number;
  height?: number;
}

export function StrokeRateGraph({ realtimeStrokeRates, peakHz, minConfidence = 1.5, width = 600, height = 120 }: StrokeRateGraphProps) {
  const convertedRates = realtimeStrokeRates.map(r => ({
    timestamp: r.timestamp,
    rateHz: r.strokeRateHz,
    ratePerMin: r.strokeRatePerMin,
    confidence: r.confidence,
  }));

  return (
    <RateGraph
      realtimeRates={convertedRates}
      peakHz={peakHz}
      minConfidence={minConfidence}
      title="Stroke Rate Over Time"
      unit="spm"
      width={width}
      height={height}
    />
  );
}