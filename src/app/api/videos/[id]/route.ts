import { NextRequest, NextResponse } from 'next/server';
import { getVideoPath, deleteVideo, getAnalysis } from '@/lib/video/storage';
import fs from 'fs';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const videoPath = getVideoPath(id);

  if (!videoPath) {
    return NextResponse.json({ error: 'Video not found' }, { status: 404 });
  }

  const fileBuffer = fs.readFileSync(videoPath);
  const extension = videoPath.split('.').pop() || 'mp4';
  const mimeType = extension === 'webm' ? 'video/webm' : extension === 'mov' ? 'video/quicktime' : 'video/mp4';

  return new NextResponse(fileBuffer, {
    headers: {
      'Content-Type': mimeType,
      'Content-Length': fileBuffer.length.toString(),
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  // Check if analysis exists
  const analysis = getAnalysis(id);
  if (!analysis) {
    return NextResponse.json({ error: 'Analysis not found' }, { status: 404 });
  }

  // Delete all associated files (video, analysis JSON, landmarks)
  const deleted = deleteVideo(id);

  if (!deleted) {
    return NextResponse.json({ error: 'Failed to delete files' }, { status: 500 });
  }

  return NextResponse.json({ success: true, deletedId: id });
}