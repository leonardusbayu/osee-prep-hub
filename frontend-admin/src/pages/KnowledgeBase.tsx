import { useState } from 'react';
import { apiFetch } from '../api/client';

interface KbDocument {
  id: string;
  title: string;
  source: string;
  category: string;
  cefr_level: string | null;
  content_chunk_count: number;
  is_active: boolean;
  created_at: string;
}

interface UploadBody {
  title: string;
  source: string;
  category: string;
  content: string;
  cefr_level?: string;
  metadata?: Record<string, unknown>;
}

const CATEGORIES = [
  'grammar',
  'vocabulary',
  'pronunciation',
  'rubrics',
  'question_templates',
  'error_patterns',
  'cultural',
  'general',
];

const CEFR_LEVELS = ['', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

export function KnowledgeBase() {
  const [documents, setDocuments] = useState<KbDocument[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showUpload, setShowUpload] = useState(false);

  // Upload form state
  const [title, setTitle] = useState('');
  const [source, setSource] = useState('');
  const [category, setCategory] = useState('grammar');
  const [cefr, setCefr] = useState('');
  const [content, setContent] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadMsg, setUploadMsg] = useState<string | null>(null);

  async function loadDocs() {
    setLoading(true);
    setError(null);
    const res = await apiFetch<{ documents?: KbDocument[] }>(
      '/admin/knowledge-base/documents'
    );
    if (res.error) {
      setError(res.error.message);
      setDocuments([]);
    } else {
      setDocuments(res.data?.documents ?? []);
    }
    setLoading(false);
  }

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !source.trim() || !content.trim()) {
      setUploadMsg('Title, source, and content are required');
      return;
    }
    setUploading(true);
    setUploadMsg(null);
    const body: UploadBody = {
      title: title.trim(),
      source: source.trim(),
      category,
      content: content.trim(),
    };
    if (cefr) body.cefr_level = cefr;

    const res = await apiFetch<{ document_id: string }>('/admin/knowledge-base/upload', {
      method: 'POST',
      body: JSON.stringify(body),
    });
    setUploading(false);
    if (res.error) {
      setUploadMsg(`Upload failed: ${res.error.message}`);
      return;
    }
    // Trigger embedding
    const docId = res.data?.document_id;
    if (docId) {
      setUploadMsg('Document uploaded. Generating embeddings...');
      const embedRes = await apiFetch<{ chunks: number }>(
        `/admin/knowledge-base/${docId}/embed`,
        { method: 'POST' }
      );
      if (embedRes.error) {
        setUploadMsg(`Uploaded, but embedding failed: ${embedRes.error.message}`);
      } else {
        setUploadMsg(`Uploaded + embedded ${embedRes.data?.chunks ?? 0} chunks ✓`);
      }
    }
    // Reset form
    setTitle('');
    setSource('');
    setContent('');
    setCefr('');
    loadDocs();
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-extrabold tracking-tight text-osee-900">Knowledge Base (RAG)</h2>
          <p className="mb-6 text-sm text-osee-400">Unggah dokumen untuk basis pengetahuan RAG dan lihat daftar dokumen.</p>
        </div>
        <div className="flex gap-2">
          <button
            className="btn-primary px-3 py-1.5 text-sm"
            onClick={loadDocs}
            disabled={loading}
          >
            {loading ? 'Loading...' : 'Refresh'}
          </button>
          <button
            className="btn-primary px-3 py-1.5 text-sm"
            onClick={() => setShowUpload(!showUpload)}
          >
            {showUpload ? 'Close' : 'Upload'}
          </button>
        </div>
      </div>

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      {showUpload && (
        <form
          onSubmit={handleUpload}
          className="mb-6 card p-5"
        >
          <h3 className="mb-3 text-lg font-semibold">Upload Document</h3>
          <div className="space-y-3">
            <input
              type="text"
              placeholder="Title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="input w-full"
              required
            />
            <input
              type="text"
              placeholder="Source (e.g. English Grammar in Use, Murphy)"
              value={source}
              onChange={(e) => setSource(e.target.value)}
              className="input w-full"
              required
            />
            <div className="flex gap-3">
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="input"
              >
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
              <select
                value={cefr}
                onChange={(e) => setCefr(e.target.value)}
                className="input"
              >
                {CEFR_LEVELS.map((l) => (
                  <option key={l} value={l}>
                    {l || 'Any level'}
                  </option>
                ))}
              </select>
            </div>
            <textarea
              placeholder="Document content (will be chunked + embedded)"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="input h-40 w-full font-mono text-sm"
              required
            />
            {uploadMsg && <p className="text-sm text-blue-600">{uploadMsg}</p>}
            <button
              type="submit"
              disabled={uploading}
              className="btn-primary disabled:opacity-60"
            >
              {uploading ? 'Uploading...' : 'Upload + Embed'}
            </button>
          </div>
        </form>
      )}

      {documents.length === 0 && !loading ? (
        <p className="text-gray-600">
          No documents loaded. Click <strong>Refresh</strong> to load, or <strong>Upload</strong> to add a new document.
        </p>
      ) : (
        <table className="w-full rounded-lg bg-white shadow">
          <thead className="bg-gray-100 text-left text-sm uppercase">
            <tr>
              <th className="px-3 py-2">Title</th>
              <th className="px-3 py-2">Source</th>
              <th className="px-3 py-2">Category</th>
              <th className="px-3 py-2">CEFR</th>
              <th className="px-3 py-2 text-right">Chunks</th>
              <th className="px-3 py-2">Created</th>
            </tr>
          </thead>
          <tbody>
            {documents.map((doc) => (
              <tr key={doc.id} className="border-t border-gray-100">
                <td className="px-3 py-2">{doc.title}</td>
                <td className="px-3 py-2 text-gray-600">{doc.source}</td>
                <td className="px-3 py-2">{doc.category}</td>
                <td className="px-3 py-2">{doc.cefr_level ?? '—'}</td>
                <td className="px-3 py-2 text-right">{doc.content_chunk_count}</td>
                <td className="px-3 py-2 text-gray-500">
                  {new Date(doc.created_at).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}