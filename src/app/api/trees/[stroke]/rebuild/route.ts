import { NextRequest, NextResponse } from 'next/server';
import { rebuildTreeFromMarkdown, updateTreeWithSourceFiles } from '@/lib/data/tree-builder';
import { buildTreeHierarchy } from '@/lib/data/trees';

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ stroke: string }> }
) {
  const { stroke } = await params;
  const strokeId = stroke as 'freestyle' | 'backstroke' | 'breaststroke' | 'butterfly';

  try {
    // Check if tree already exists and is customized
    const body = await request.json().catch(() => ({}));
    const preserveCustomized = body.preserveCustomized ?? true;

    const tree = preserveCustomized
      ? updateTreeWithSourceFiles(strokeId)
      : rebuildTreeFromMarkdown(strokeId);

    if (!tree) {
      return NextResponse.json(
        { error: `Failed to rebuild tree for stroke: ${strokeId}` },
        { status: 500 }
      );
    }

    const hierarchy = buildTreeHierarchy(tree);

    return NextResponse.json({
      success: true,
      tree,
      hierarchy,
      message: `Tree rebuilt from markdown files for ${strokeId}`,
    });
  } catch (error) {
    console.error('Error rebuilding tree:', error);
    return NextResponse.json(
      { error: 'Failed to rebuild tree from markdown' },
      { status: 500 }
    );
  }
}