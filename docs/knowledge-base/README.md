# OSEE Prep Hub — RAG Knowledge Base

This directory contains reference documents for the RAG (Retrieval-Augmented Generation) knowledge base.

## Structure

```
docs/knowledge-base/
├── tier1/           # Tier 1: Core reference materials
│   ├── cefr-b1-writing.md
│   ├── cefr-b2-writing.md
│   ├── ielts-writing-task2.md
│   ├── toefl-ibt-writing.md
│   └── kurikulum-merdeka-english.md
├── tier2/           # Tier 2: EduBot error patterns (added in Task 4.4)
└── README.md        # This file
```

## Tier 1: Core Reference Materials

Tier 1 contains authoritative reference documents that inform AI grading and material generation:
- **CEFR descriptors**: A1-C2 writing/speaking/reading/listening standards
- **Test specifications**: IELTS, TOEFL iBT, TOEFL ITP, TOEIC official criteria
- **Kurikulum Merdeka**: Indonesian national curriculum for English

## Ingestion

To ingest documents into the RAG knowledge base:

```bash
# Dry run (no database writes)
npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --dry-run

# Real ingestion (requires OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY)
npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --tier 1

# Limit to first N files
npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --limit 3
```

The ingestion script:
1. Reads .md, .txt files recursively from the source directory
2. Chunks each document into ~1000-token segments with 200-char overlap
3. Generates OpenAI embeddings (text-embedding-3-small, 1536 dims) for each chunk
4. Inserts into `knowledge_base_documents` + `knowledge_base_embeddings` tables
5. Idempotent: re-running skips documents with existing source_path

## Adding New Materials

1. Create a new .md file in the appropriate tier directory
2. Use clear headings (H1, H2, H3) — the chunker splits on paragraphs
3. Include specific assessment criteria, score bands, examples
4. Run the ingestion script

## Source Attribution

All Tier 1 materials are:
- Public domain (CEFR descriptors — Council of Europe)
- Official test specifications (ETS, IELTS Partners)
- Indonesian Ministry of Education (Kurikulum Merdeka)

No copyrighted material is included without permission.