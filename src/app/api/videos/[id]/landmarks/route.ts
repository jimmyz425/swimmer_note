import { NextRequest, NextResponse } from 'next/server';
import { getLandmarks } from '@/lib/video/storage';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  const landmarks = getLandmarks(id);

  if (!landmarks) {
    return NextResponse.json({ error: 'Landmarks not found' }, { status: 404 });
  }

  return NextResponse.json({ landmarks });
}