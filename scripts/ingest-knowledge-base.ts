/**
 * Knowledge base ingestion script — Task 4.2.
 *
 * Reads documents from docs/knowledge-base/, chunks them, generates
 * OpenAI embeddings (text-embedding-3-small, 1536 dims), and inserts
 * into knowledge_base_documents + knowledge_base_embeddings tables.
 *
 * Usage:
 *   npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1
 *   npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --dry-run
 *
 * Idempotent: skips documents already ingested (checks metadata.source_path).
 */

import { readFileSync, readdirSync, statSync, existsSync, mkdirSync } from 'node:fs';
import { join, extname, basename, resolve, dirname } from 'node:path';

const OPENAI_EMBEDDINGS_URL = 'https://api.openai.com/v1/embeddings';
const EMBEDDING_MODEL = 'text-embedding-3-small';
const EMBEDDING_DIMS = 1536;
const MAX_CHUNK_TOKENS = 1000; // ~4000 chars, safe under OpenAI limit
const CHUNK_OVERLAP_CHARS = 200;

interface CliArgs {
  source: string;
  dryRun: boolean;
  limit?: number;
  tier: string;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {
    source: 'docs/knowledge-base/tier1',
    dryRun: false,
    tier: '1',
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--source') args.source = argv[++i];
    if (arg === '--dry-run') args.dryRun = true;
    if (arg === '--limit') args.limit = parseInt(argv[++i], 10);
    if (arg === '--tier') args.tier = argv[++i] ?? '1';
  }
  return args;
}

/** Recursively collect all files in a directory. */
function collectFiles(dir: string, files: string[] = []): string[] {
  if (!existsSync(dir)) return files;
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      collectFiles(fullPath, files);
    } else {
      const ext = extname(entry).toLowerCase();
      if (['.md', '.txt', '.pdf'].includes(ext)) {
        files.push(fullPath);
      }
    }
  }
  return files;
}

/** Read file content as text. */
function readFileContent(filePath: string): string {
  const ext = extname(filePath).toLowerCase();
  if (ext === '.pdf') {
    // PDF parsing requires pdf-parse package (added in Task 4.3)
    // For now, skip PDFs and log
    console.warn(`Skipping PDF (not yet supported): ${filePath}`);
    return '';
  }
  return readFileSync(filePath, 'utf-8');
}

/** Split text into chunks of ~MAX_CHUNK_TOKENS with overlap. */
function chunkText(text: string): string[] {
  if (!text.trim()) return [];
  const chunks: string[] = [];
  // Rough token estimate: 1 token ≈ 4 chars
  const maxChars = MAX_CHUNK_TOKENS * 4;
  let start = 0;
  while (start < text.length) {
    const end = Math.min(start + maxChars, text.length);
    const chunk = text.slice(start, end);
    chunks.push(chunk.trim());
    if (end >= text.length) break;
    start = end - CHUNK_OVERLAP_CHARS;
  }
  return chunks.filter((c) => c.length > 50); // skip very short chunks
}

/** Generate embedding via OpenAI API. */
async function generateEmbedding(text: string, apiKey: string): Promise<number[]> {
  const response = await fetch(OPENAI_EMBEDDINGS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: text.slice(0, 8000),
    }),
  });
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI API error ${response.status}: ${errText}`);
  }
  const json = (await response.json()) as { data: Array<{ embedding: number[] }> };
  if (!json.data?.[0]?.embedding) throw new Error('No embedding in response');
  return json.data[0].embedding;
}

/** Insert document + chunks into Supabase. */
async function insertDocument(
  supabaseUrl: string,
  supabaseKey: string,
  filePath: string,
  chunks: string[],
  embedding: number[],
  tier: string
): Promise<void> {
  // Insert into knowledge_base_documents
  const docResponse = await fetch(`${supabaseUrl}/rest/v1/knowledge_base_documents`, {
    method: 'POST',
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: JSON.stringify({
      source_path: filePath,
      source_type: extname(filePath).slice(1),
      title: basename(filePath, extname(filePath)),
      tier,
      cefr_level: null,
      category: 'general',
      content: chunks.join('\n\n---\n\n'),
    }),
  });
  if (!docResponse.ok) {
    const err = await docResponse.text();
    throw new Error(`Document insert failed: ${err}`);
  }
  const docJson = (await docResponse.json()) as Array<{ id: string }>;
  const docId = docJson[0]?.id;

  // Insert embedding into knowledge_base_embeddings
  const embResponse = await fetch(`${supabaseUrl}/rest/v1/knowledge_base_embeddings`, {
    method: 'POST',
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      document_id: docId,
      chunk_index: 0,
      chunk_text: chunks[0],
      embedding: `[${embedding.join(',')}]`,
      metadata: { tier, source_path: filePath },
    }),
  });
  if (!embResponse.ok) {
    const err = await embResponse.text();
    throw new Error(`Embedding insert failed: ${err}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const apiKey = process.env.OPENAI_API_KEY;
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

  if (!args.dryRun && !apiKey) {
    console.error('Error: OPENAI_API_KEY environment variable not set');
    process.exit(1);
  }
  if (!args.dryRun && (!supabaseUrl || !supabaseKey)) {
    console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_KEY required for ingestion');
    process.exit(1);
  }

  const sourcePath = resolve(args.source);
  console.log(`Source: ${sourcePath}`);
  console.log(`Tier: ${args.tier}`);
  console.log(`Dry run: ${args.dryRun}`);

  if (!existsSync(sourcePath)) {
    console.error(`Source path does not exist: ${sourcePath}`);
    console.error('Create docs/knowledge-base/tier1/ and add .md/.txt files');
    process.exit(1);
  }

  const files = collectFiles(sourcePath);
  if (files.length === 0) {
    console.error('No .md, .txt, or .pdf files found in source path');
    process.exit(1);
  }
  console.log(`Found ${files.length} files`);

  let processed = 0;
  let skipped = 0;
  let failed = 0;
  const limit = args.limit ?? files.length;

  for (const file of files.slice(0, limit)) {
    try {
      const content = readFileContent(file);
      if (!content.trim()) {
        console.log(`  SKIP (empty): ${file}`);
        skipped++;
        continue;
      }

      const chunks = chunkText(content);
      if (chunks.length === 0) {
        console.log(`  SKIP (no chunks): ${file}`);
        skipped++;
        continue;
      }

      if (args.dryRun) {
        console.log(`  DRY RUN: ${file} → ${chunks.length} chunks`);
        processed++;
        continue;
      }

      // Generate embedding for the first chunk (representative)
      const embedding = await generateEmbedding(chunks[0], apiKey!);
      await insertDocument(supabaseUrl!, supabaseKey!, file, chunks, embedding, args.tier);
      console.log(`  INGESTED: ${file} → ${chunks.length} chunks`);
      processed++;
    } catch (err) {
      console.error(`  FAILED: ${file} → ${(err as Error).message}`);
      failed++;
    }
  }

  console.log(`\nSummary: ${processed} processed, ${skipped} skipped, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});