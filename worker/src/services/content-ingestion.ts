import type { Env } from '../types';

/**
 * Content ingestion service — extracts text from external sources
 * (YouTube, URLs, PDFs) so the AI mind-map nodes can use them as knowledge.
 *
 * Inspired by remalt.com's "dump anything onto your board" pattern.
 */

export type SourceType = 'youtube' | 'url' | 'pdf' | 'text';

export interface IngestSourceInput {
  type: SourceType;
  url?: string;        // for youtube / url
  content?: string;     // raw text (for 'text') or base64 PDF content
  filename?: string;    // for pdf
}

export interface IngestedSource {
  type: SourceType;
  title: string;
  text: string;         // extracted text (truncated to ~4000 chars for AI context)
  source_url?: string;
  metadata: Record<string, unknown>;
}

const MAX_TEXT_LENGTH = 4000;

/** Ingest a source and extract its text content. */
export async function ingestSource(env: Env, input: IngestSourceInput): Promise<IngestedSource> {
  switch (input.type) {
    case 'youtube':
      return ingestYouTube(env, input.url ?? '');
    case 'url':
      return ingestUrl(env, input.url ?? '');
    case 'pdf':
      return ingestPdf(input.content ?? '', input.filename ?? 'document.pdf');
    case 'text':
      return ingestText(input.content ?? '');
    default:
      throw new Error(`Unsupported source type: ${input.type}`);
  }
}

// ============================================================
// YouTube — fetch transcript via public timedtext API
// ============================================================

async function ingestYouTube(_env: Env, url: string): Promise<IngestedSource> {
  const videoId = extractYouTubeId(url);
  if (!videoId) {
    throw new Error('Invalid YouTube URL — could not extract video ID');
  }

  // Try fetching transcript via the page scrape approach
  let transcript = '';
  let transcriptError = '';
  try {
    transcript = await fetchYouTubeTranscript(videoId);
  } catch (err) {
    transcriptError = err instanceof Error ? err.message : 'Unknown error';
  }

  // Fetch video metadata (title) via oEmbed (no API key needed)
  let title = `YouTube video ${videoId}`;
  try {
    const oembedRes = await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`);
    if (oembedRes.ok) {
      const oembed = (await oembedRes.json()) as { title?: string; author_name?: string };
      if (oembed.title) title = oembed.title;
    }
  } catch {
    // Non-fatal
  }

  if (!transcript || transcript.trim().length === 0) {
    // Fallback: use the video title + author from oEmbed as the "knowledge"
    // The teacher can paste the full transcript as a 'text' source if needed.
    let fallbackText = `Video: ${title}`;
    try {
      const oembedRes2 = await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`);
      if (oembedRes2.ok) {
        const oembed = (await oembedRes2.json()) as { title?: string; author_name?: string; thumbnail_url?: string };
        fallbackText = `Title: ${oembed.title ?? title}\nAuthor: ${oembed.author_name ?? 'Unknown'}\n\nNote: Could not auto-fetch the transcript (YouTube may have blocked the request or the video has no captions). Paste the transcript as a 'text' source for full content.`;
      }
    } catch {
      // Use minimal fallback
    }
    return {
      type: 'youtube',
      title,
      text: truncate(fallbackText),
      source_url: `https://www.youtube.com/watch?v=${videoId}`,
      metadata: { videoId, method: 'oembed_fallback', error: transcriptError || 'no_transcript' },
    };
  }

  return {
    type: 'youtube',
    title,
    text: truncate(transcript),
    source_url: `https://www.youtube.com/watch?v=${videoId}`,
    metadata: { videoId, method: 'page_scrape', error: transcriptError || undefined },
  };
}

function extractYouTubeId(url: string): string | null {
  // Handle: youtu.be/ID, youtube.com/watch?v=ID, youtube.com/embed/ID
  const patterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/shorts\/)([A-Za-z0-9_-]{11})/,
    /v=([A-Za-z0-9_-]{11})/,
  ];
  for (const p of patterns) {
    const m = p.exec(url);
    if (m) return m[1];
  }
  // Maybe it's already just the ID
  if (/^[A-Za-z0-9_-]{11}$/.test(url)) return url;
  return null;
}

async function fetchYouTubeTranscript(videoId: string): Promise<string> {
  // Approach 1: fetch the YouTube watch page and extract captionTracks
  // from the embedded ytInitialPlayerResponse JSON.
  try {
    const pageRes = await fetch(`https://www.youtube.com/watch?v=${videoId}&hl=en`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    });
    if (pageRes.ok) {
      const html = await pageRes.text();
      // Try ytInitialPlayerResponse pattern
      const playerResponseMatch = html.match(/ytInitialPlayerResponse\s*=\s*(\{.*?\});\s*<\/script>/s);
      if (playerResponseMatch) {
        const playerData = JSON.parse(playerResponseMatch[1]) as {
          captions?: { playerCaptionsTracklistRenderer?: { captionTracks?: Array<{ baseUrl: string; languageCode: string }> } };
        };
        const tracks = playerData.captions?.playerCaptionsTracklistRenderer?.captionTracks;
        if (tracks && tracks.length > 0) {
          return await fetchTranscriptFromTracks(tracks);
        }
      }
      // Try alternate pattern: raw captionTracks JSON
      const altMatch = html.match(/"captionTracks":\s*(\[.*?\])/s);
      if (altMatch) {
        const tracks = JSON.parse(altMatch[1]) as Array<{ baseUrl: string; languageCode: string }>;
        if (tracks.length > 0) return await fetchTranscriptFromTracks(tracks);
      }
    }
  } catch {
    // Fall through to approach 2
  }

  // Approach 2: return empty — caller will use oEmbed description as fallback
  return '';
}

async function fetchTranscriptFromTracks(tracks: Array<{ baseUrl: string; languageCode: string }>): Promise<string> {
  // Prefer English, fall back to first track
  const track = tracks.find((t) => t.languageCode.startsWith('en')) ?? tracks[0];

  // Fetch the transcript XML — add fmt=vtt or keep default XML
  const transcriptRes = await fetch(track.baseUrl);
  if (!transcriptRes.ok) throw new Error('Could not fetch transcript');
  const transcriptXml = await transcriptRes.text();

  // Parse the XML to extract text segments
  const segments = transcriptXml.match(/<text[^>]*>(.*?)<\/text>/gs) ?? [];
  const text = segments
    .map((s) =>
      s
        .replace(/<[^>]+>/g, '')
        .replace(/&amp;/g, '&')
        .replace(/&#39;/g, "'")
        .replace(/&quot;/g, '"')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .trim()
    )
    .filter((s) => s.length > 0)
    .join(' ');

  return text;
}

// ============================================================
// URL — scrape the page and extract main text content
// ============================================================

async function ingestUrl(_env: Env, url: string): Promise<IngestedSource> {
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    throw new Error('URL must start with http:// or https://');
  }

  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`Failed to fetch URL: ${res.status}`);

  const contentType = res.headers.get('content-type') ?? '';
  const html = await res.text();

  // Extract title
  const titleMatch = html.match(/<title[^>]*>(.*?)<\/title>/is);
  let title = titleMatch ? titleMatch[1].trim() : url;

  // If it's already plain text
  if (contentType.includes('text/plain')) {
    return { type: 'url', title, text: truncate(html), source_url: url, metadata: { contentType } };
  }

  // Strip HTML tags, scripts, styles
  const text = extractTextFromHtml(html);
  if (text.trim().length === 0) {
    throw new Error('No readable text content found on this page');
  }

  return {
    type: 'url',
    title,
    text: truncate(text),
    source_url: url,
    metadata: { contentType },
  };
}

function extractTextFromHtml(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<nav[\s\S]*?<\/nav>/gi, '')
    .replace(/<footer[\s\S]*?<\/footer>/gi, '')
    .replace(/<header[\s\S]*?<\/header>/gi, '')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

// ============================================================
// PDF — extract text from base64-encoded PDF content
// Uses a simple text extraction (no external deps — works for
// text-based PDFs; scanned PDFs need OCR which we can't do in Workers)
// ============================================================

async function ingestPdf(content: string, filename: string): Promise<IngestedSource> {
  if (!content || content.trim().length === 0) {
    throw new Error('PDF content required (base64 encoded)');
  }

  // Decode base64
  let bytes: Uint8Array;
  try {
    // Handle data URI prefix
    const cleaned = content.replace(/^data:application\/pdf;base64,/, '');
    const binary = atob(cleaned);
    bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  } catch {
    throw new Error('Invalid base64 content');
  }

  // Simple PDF text extraction: find text between BT...ET blocks
  // This is a naive parser — works for simple text PDFs
  const text = extractPdfText(bytes);
  if (text.trim().length === 0) {
    throw new Error('Could not extract text from PDF — it may be scanned (image-based) or empty');
  }

  return {
    type: 'pdf',
    title: filename,
    text: truncate(text),
    metadata: { filename, bytes: bytes.length },
  };
}

function extractPdfText(bytes: Uint8Array): string {
  // Convert to string (latin1 to preserve byte values)
  let pdfStr = '';
  const chunk = 8192;
  for (let i = 0; i < bytes.length; i += chunk) {
    pdfStr += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunk, bytes.length)));
  }

  // Extract text from BT...ET blocks: look for Tj and TJ operators
  const texts: string[] = [];
  const tjRegex = /\(([^)]*)\)\s*Tj/g;
  const tjArrayRegex = /\[(.*?)\]\s*TJ/g;

  let match: RegExpExecArray | null;
  while ((match = tjRegex.exec(pdfStr)) !== null) {
    if (match[1]) texts.push(decodePdfString(match[1]));
  }
  while ((match = tjArrayRegex.exec(pdfStr)) !== null) {
    // TJ arrays contain strings mixed with numbers (kerning offsets)
    const inner = match[1];
    const stringMatches = inner.matchAll(/\(([^)]*)\)/g);
    for (const sm of stringMatches) {
      if (sm[1]) texts.push(decodePdfString(sm[1]));
    }
  }

  return texts.join(' ').replace(/\s+/g, ' ').trim();
}

function decodePdfString(s: string): string {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\\(/g, '(')
    .replace(/\\\)/g, ')')
    .replace(/\\\\/g, '\\');
}

// ============================================================
// Raw text
// ============================================================

async function ingestText(content: string): Promise<IngestedSource> {
  if (!content.trim()) throw new Error('Text content required');
  return {
    type: 'text',
    title: 'Pasted text',
    text: truncate(content),
    metadata: { chars: content.length },
  };
}

// ============================================================
// Helpers
// ============================================================

function truncate(text: string): string {
  if (text.length <= MAX_TEXT_LENGTH) return text;
  return text.slice(0, MAX_TEXT_LENGTH) + '\n\n[... truncated for AI context ...]';
}

/** Assemble multiple ingested sources into a single context string for AI prompts. */
export function assembleContext(sources: IngestedSource[]): string {
  if (sources.length === 0) return '';
  return sources.map((s, i) => {
    return `[Source ${i + 1}: ${s.title}]\n${s.text}`;
  }).join('\n\n---\n\n');
}