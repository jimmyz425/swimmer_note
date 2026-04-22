import { NextRequest, NextResponse } from 'next/server';
import { getTechniqueTree, saveTechniqueTree, buildTreeHierarchy } from '@/lib/data/trees';
import { StrokeId, TechniqueTree } from '@/lib/types';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ stroke: string }> }
) {
  const { stroke } = await params;
  const tree = getTechniqueTree(stroke as StrokeId | 'master');

  if (!tree) {
    return NextResponse.json({ error: 'Tree not found' }, { status: 404 });
  }

  // Return tree with hierarchy built
  const hierarchy = buildTreeHierarchy(tree);

  return NextResponse.json({ tree, hierarchy });
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ stroke: string }> }
) {
  const { stroke } = await params;
  const body = await request.json() as TechniqueTree;

  // Validate stroke ID matches
  if (body.strokeId !== stroke) {
    return NextResponse.json({ error: 'Stroke ID mismatch' }, { status: 400 });
  }

  // Save the tree
  const savedTree = saveTechniqueTree(body);

  // Return saved tree with hierarchy
  const hierarchy = buildTreeHierarchy(savedTree);

  return NextResponse.json({ tree: savedTree, hierarchy, success: true });
}