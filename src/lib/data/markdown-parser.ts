import fs from 'fs';
import path from 'path';
import { ParsedTechniqueContent, CompetitiveDrill } from '@/lib/types';

const MARKDOWN_DIR = path.join(process.cwd(), 'data', 'swimming-strokes');

/**
 * Parse a technique markdown file and extract structured content
 */
export function parseTechniqueFile(filename: string): ParsedTechniqueContent | null {
  const filePath = path.join(MARKDOWN_DIR, `${filename}.md`);

  if (!fs.existsSync(filePath)) {
    return null;
  }

  const rawContent = fs.readFileSync(filePath, 'utf-8');
  return parseMarkdownContent(filename, rawContent);
}

/**
 * Parse markdown content into structured data
 */
function parseMarkdownContent(filename: string, content: string): ParsedTechniqueContent {
  // Extract title from H1
  const titleMatch = content.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1] : filename;

  // Extract Prev/Next navigation links
  const prevMatch = content.match(/← Prev:\s*(?:—|none|\[\[swimming-strokes\/([^\]]+)\]\])/);
  const nextMatch = content.match(/Next:\s*\[\[swimming-strokes\/([^\]]+)\]\]/);
  const prevFile = prevMatch && prevMatch[1] ? prevMatch[1] : null;
  const nextFile = nextMatch ? nextMatch[1] : null;

  // Extract sections by headers
  const sections = extractSections(content);

  // Parse each section
  const overview = sections['Overview'] || '';
  const difficulty = extractDifficulty(overview);
  const keyPoints = parseBulletList(sections['Key Points to Remember'] || '');
  const commonMistakes = parseBulletList(sections['Common Mistakes to Avoid'] || '');
  const specificDrills = parseDrillsTable(sections['Specific Drills'] || '');
  const competitiveDrills = parseCompetitiveDrills(sections['Competitive Drills'] || '');
  const relatedTechniques = parseRelatedTechniques(sections['Related Techniques'] || '');

  return {
    filename,
    title,
    overview,
    difficulty,
    keyPoints,
    commonMistakes,
    specificDrills,
    competitiveDrills,
    relatedTechniques,
    prevFile,
    nextFile,
    rawContent: content,
  };
}

/**
 * Split content into sections by ## headers
 */
function extractSections(content: string): Record<string, string> {
  const sections: Record<string, string> = {};
  const parts = content.split(/^##\s+/m);

  // First part is header/metadata, skip it
  for (let i = 1; i < parts.length; i++) {
    const [header, ...bodyParts] = parts[i].split('\n');
    const sectionName = header.trim();
    sections[sectionName] = bodyParts.join('\n').trim();
  }

  return sections;
}

/**
 * Extract difficulty from overview section
 */
function extractDifficulty(overview: string): string {
  const match = overview.match(/\*\*Difficulty:\s*([^*]+)\*\*/);
  return match ? match[1].trim() : '';
}

/**
 * Parse bullet list into array of strings
 */
function parseBulletList(content: string): string[] {
  const lines = content.split('\n');
  const items: string[] = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('- ')) {
      // Remove the bullet and clean up
      const item = trimmed.slice(2).trim();
      if (item) items.push(item);
    }
  }

  return items;
}

/**
 * Parse markdown table into drill objects
 */
function parseDrillsTable(content: string): { name: string; description: string }[] {
  const drills: { name: string; description: string }[] = [];
  const lines = content.split('\n');

  // Find table rows (lines starting with |)
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('|') && !trimmed.includes('---')) {
      const cells = trimmed.split('|').map(c => c.trim()).filter(c => c);
      if (cells.length >= 2 && cells[0] !== 'Drill') {
        drills.push({
          name: cells[0].replace(/\*\*/g, ''), // Remove bold markers
          description: cells[1] || '',
        });
      }
    }
  }

  return drills;
}

/**
 * Parse competitive drills section with tiered targets
 */
function parseCompetitiveDrills(content: string): CompetitiveDrill[] {
  const drills: CompetitiveDrill[] = [];

  // Split by drill headers (#### Drill N:)
  const drillParts = content.split(/#### Drill \d+:/);

  for (let i = 1; i < drillParts.length; i++) {
    const drillContent = drillParts[i];
    const drillName = drillContent.split('\n')[0].trim();

    // Extract self-check
    const selfCheckMatch = drillContent.match(/\*\*Self-Check:\*\*\s*([^\n]+)/);
    const selfCheck = selfCheckMatch ? selfCheckMatch[1].trim() : '';

    // Extract tiered targets from callout block
    const tieredTargets = extractTieredTargets(drillContent);

    // Extract video checks
    const videoChecks = extractVideoChecks(drillContent);

    // Extract competitive impact
    const impactMatch = drillContent.match(/\*\*Competitive Impact:\*\*\s*([^\n]+)/);
    const competitiveImpact = impactMatch ? impactMatch[1].trim() : '';

    drills.push({
      name: drillName,
      selfCheck,
      tieredTargets,
      videoChecks,
      competitiveImpact,
    });
  }

  return drills;
}

/**
 * Extract tiered targets from callout block
 */
function extractTieredTargets(content: string): { beginner: string; intermediate: string; advanced: string; elite: string } {
  const defaults = { beginner: '', intermediate: '', advanced: '', elite: '' };

  // Find the callout block with tiered targets
  const calloutMatch = content.match(/>\s*\[!note\][^\n]*\n((?:>[^\n]*\n)+)/);
  if (!calloutMatch) return defaults;

  const calloutContent = calloutMatch[1];

  // Extract each tier
  const beginnerMatch = calloutContent.match(/>\s*-?\s*\*\*Beginner:\*\*\s*([^>\n]+)/);
  const intermediateMatch = calloutContent.match(/>\s*-?\s*\*\*Intermediate:\*\*\s*([^>\n]+)/);
  const advancedMatch = calloutContent.match(/>\s*-?\s*\*\*Advanced:\*\*\s*([^>\n]+)/);
  const eliteMatch = calloutContent.match(/>\s*-?\s*\*\*Elite:\*\*\s*([^>\n]+)/);

  return {
    beginner: beginnerMatch ? beginnerMatch[1].trim() : '',
    intermediate: intermediateMatch ? intermediateMatch[1].trim() : '',
    advanced: advancedMatch ? advancedMatch[1].trim() : '',
    elite: eliteMatch ? eliteMatch[1].trim() : '',
  };
}

/**
 * Extract video check bullet points
 */
function extractVideoChecks(content: string): string[] {
  const checks: string[] = [];
  const videoCheckMatch = content.match(/\*\*Video Check[^*]*\*\*:[^\n]*\n((?:-[^\n]*\n)+)/);

  if (videoCheckMatch) {
    const lines = videoCheckMatch[1].split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('- ')) {
        checks.push(trimmed.slice(2).trim());
      }
    }
  }

  return checks;
}

/**
 * Parse related techniques section for wikilinks
 */
function parseRelatedTechniques(content: string): string[] {
  const techniques: string[] = [];
  const wikilinkRegex = /\[\[swimming-strokes\/([^\]]+)\]\]/g;

  let match;
  while ((match = wikilinkRegex.exec(content)) !== null) {
    techniques.push(match[1]);
  }

  return techniques;
}

/**
 * Get all technique files for a stroke
 */
export function listTechniqueFiles(strokeId: string): string[] {
  const files = fs.readdirSync(MARKDOWN_DIR);

  // Filter for technique files (numbered), exclude main guide and dry-land
  const techniqueFiles = files
    .filter(f => f.startsWith(`${strokeId}-`) && f.endsWith('.md'))
    .filter(f => !f.includes('dry-land-training'))
    .filter(f => {
      // Exclude main guide (stroke.md without number)
      const pattern = new RegExp(`^${strokeId}-\\d+-`);
      return pattern.test(f);
    })
    .map(f => f.replace('.md', ''))
    .sort((a, b) => {
      // Sort by sequence number
      const numA = parseInt(a.match(/\d+/)?.[0] || '0');
      const numB = parseInt(b.match(/\d+/)?.[0] || '0');
      return numA - numB;
    });

  return techniqueFiles;
}

/**
 * Get file path for markdown directory
 */
export function getMarkdownDir(): string {
  return MARKDOWN_DIR;
}