'use client';

import { useState, useRef, useCallback } from 'react';
import { Upload, Video, X, Loader2, Play, Pause, CheckCircle2 } from 'lucide-react';

interface VideoUploadProps {
  onUpload: (file: File, strokeType: string) => Promise<void>;
  disabled?: boolean;
}

export function VideoUpload({ onUpload, disabled }: VideoUploadProps) {
  const [file, setFile] = useState<File | null>(null);
  const [strokeType, setStrokeType] = useState<string>('freestyle');
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    const files = e.dataTransfer.files;
    if (files && files[0]) {
      const videoFile = files[0];
      if (videoFile.type.startsWith('video/')) {
        setFile(videoFile);
        setPreviewUrl(URL.createObjectURL(videoFile));
      }
    }
  }, []);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (files && files[0]) {
      const videoFile = files[0];
      if (videoFile.type.startsWith('video/')) {
        setFile(videoFile);
        setPreviewUrl(URL.createObjectURL(videoFile));
      }
    }
  }, []);

  const handleUpload = useCallback(async () => {
    if (!file || uploading || disabled) return;

    setUploading(true);
    try {
      await onUpload(file, strokeType);
      // Reset after successful upload
      if (previewUrl) URL.revokeObjectURL(previewUrl);
      setFile(null);
      setPreviewUrl(null);
    } catch (err) {
      console.error('Upload failed:', err);
    } finally {
      setUploading(false);
    }
  }, [file, strokeType, uploading, disabled, onUpload, previewUrl]);

  const handleClear = useCallback(() => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setFile(null);
    setPreviewUrl(null);
  }, [previewUrl]);

  return (
    <div className="glass-card rounded-xl p-6">
      {/* Upload zone */}
      <div
        className={`relative border-2 rounded-xl p-8 transition-colors ${
          dragActive
            ? 'border-pool-mid bg-pool-mid/10'
            : 'border-pool-light/50 bg-pool-surface/50'
        }`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          ref={inputRef}
          type="file"
          accept="video/*"
          onChange={handleFileSelect}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          disabled={disabled || uploading}
        />

        <div className="flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 rounded-full bg-pool-mid/20 flex items-center justify-center mb-4">
            <Upload className="w-8 h-8 text-pool-mid" />
          </div>
          <p className="text-pool-dark font-semibold mb-1">
            Drag and drop your video here
          </p>
          <p className="text-pool-mid text-sm">
            or click to select a file (MP4, MOV, WebM)
          </p>
        </div>
      </div>

      {/* Preview */}
      {previewUrl && (
        <div className="mt-4 relative rounded-xl overflow-hidden bg-pool-dark/5">
          <video
            src={previewUrl}
            controls
            className="w-full max-h-[400px]"
            muted
          />
          <button
            onClick={handleClear}
            className="absolute top-2 right-2 bg-white/90 rounded-lg p-2 text-pool-mid hover:text-pool-deep transition-colors shadow-lg"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Stroke type selector */}
      {file && (
        <div className="mt-4">
          <label className="block text-sm font-semibold text-pool-dark mb-2">
            Stroke Type
          </label>
          <select
            value={strokeType}
            onChange={(e) => setStrokeType(e.target.value)}
            className="w-full rounded-xl border border-pool-light/50 px-4 py-3 text-sm font-semibold text-pool-dark
              bg-white/80 focus:border-pool-mid focus:ring-2 focus:ring-pool-mid/20 outline-none"
          >
            <option value="freestyle">Freestyle</option>
            <option value="backstroke">Backstroke</option>
            <option value="breaststroke">Breaststroke</option>
            <option value="butterfly">Butterfly</option>
            <option value="im">Individual Medley</option>
          </select>
        </div>
      )}

      {/* Upload button */}
      {file && (
        <button
          onClick={handleUpload}
          disabled={uploading || disabled}
          className="mt-4 w-full flex items-center justify-center gap-2 bg-pool-mid text-white rounded-xl px-6 py-3
            font-semibold hover:bg-pool-deep transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {uploading ? (
            <>
              <Loader2 className="w-5 h-5 animate-spin" />
              Uploading...
            </>
          ) : (
            <>
              <Video className="w-5 h-5" />
              Upload & Analyze
            </>
          )}
        </button>
      )}
    </div>
  );
}