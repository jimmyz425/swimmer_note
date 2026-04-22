import { NextRequest, NextResponse } from 'next/server';
import { getTechniqueTree, getAllTechniqueTrees } from '@/lib/data/trees';
import { StrokeId } from '@/lib/types';

export async function GET(request: NextRequest) {
  const trees = getAllTechniqueTrees();
  return NextResponse.json({ trees });
}