import { NextRequest, NextResponse } from 'next/server';
import { parseTechniqueFile } from '@/lib/data/markdown-parser';

// Simple in-memory cache for parsed content
const cache = new Map<string, { content: any; timestamp: number }>();
const CACHE_TTL = 60 * 1000; // 1 minute

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ stroke: string; filename: string }> }
) {
  const { stroke, filename } = await params;

  try {
    // Check cache first
    const cacheKey = `${stroke}/${filename}`;
    const cached = cache.get(cacheKey);

    if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
      return NextResponse.json(cached.content);
    }

    // Parse the markdown file
    const content = parseTechniqueFile(filename);

    if (!content) {
      return NextResponse.json(
        { error: `Markdown file not found: ${filename}` },
        { status: 404 }
      );
    }

    // Cache the result
    cache.set(cacheKey, { content, timestamp: Date.now() });

    return NextResponse.json(content);
  } catch (error) {
    console.error('Error parsing markdown:', error);
    return NextResponse.json(
      { error: 'Failed to parse markdown file' },
      { status: 500 }
    );
  }
}