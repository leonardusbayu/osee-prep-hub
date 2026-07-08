/**
 * Final importer — TOEFL ITP S1+S3 (state machine parser) + already imported S2, CAE
 */
const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_API = 'https://api.supabase.com/v1/projects/zrnencaixfwpswfpmliv/database/query';
const TOEFL_ITP_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-ToeflITPPractice\\supabase\\migrations';

let qCounter = 2800;

async function execSQL(sql) {
  const res = await fetch(SUPABASE_API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${SUPABASE_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`SQL failed: ${text.substring(0, 200)}`);
  return text;
}

function esc(s) { if (s == null) return 'NULL'; return `'${String(s).replace(/'/g, "''").substring(0, 5000)}'`; }
function escJson(obj) { if (obj == null) return 'NULL'; return `'${JSON.stringify(obj).replace(/'/g, "''").substring(0, 10000)}'::jsonb`; }
function escArray(arr) { if (!arr || arr.length === 0) return "'{}'"; return `'{"${arr.map(s=>String(s).replace(/"/g,'\\"')).join('","')}"}'`; }

async function getPackageId(code) {
  const r = await execSQL(`SELECT id FROM material_packages WHERE package_code = ${esc(code)};`);
  try { const p = JSON.parse(r); return p[0]?.id; } catch (_) { return null; }
}

function parseSQLTuples(sql) {
  // Find the LAST INSERT INTO questions block (not passages)
  const inserts = sql.split('INSERT INTO');
  for (let i = inserts.length - 1; i >= 0; i--) {
    if (inserts[i].includes('questions') && inserts[i].includes('VALUES')) {
      const vIdx = inserts[i].indexOf('VALUES');
      const data = inserts[i].substring(vIdx + 6);
      // State machine extraction
      const tuples = [];
      let depth = 0, inQuote = false, start = -1;
      for (let j = 0; j < data.length; j++) {
        const c = data[j];
        if (c === "'" && data[j-1] !== '\\') { inQuote = !inQuote; continue; }
        if (!inQuote) {
          if (c === '(' && depth === 0) { start = j; }
          if (c === '(') depth++;
          if (c === ')') { depth--; if (depth === 0 && start >= 0) { tuples.push(data.substring(start, j+1)); start = -1; } }
        }
      }
      // Parse fields from each tuple
      const results = [];
      for (const t of tuples) {
        const fields = [];
        let field = '', q = false, d = 0;
        for (let k = 1; k < t.length - 1; k++) {
          const c = t[k];
          if (c === "'" && t[k-1] !== '\\') { q = !q; field += c; continue; }
          if (!q) {
            if (c === '(') { d++; field += c; continue; }
            if (c === ')') { d--; field += c; continue; }
            if (c === ',' && d === 0) { fields.push(field.trim()); field = ''; continue; }
          }
          field += c;
        }
        fields.push(field.trim());
        // Clean string fields
        const clean = (f) => f.replace(/^'/, '').replace(/'$/, '').replace(/''/g, "'");
        results.push({
          section: parseInt(fields[0]) || 0,
          part: clean(fields[1] || ''),
          question: clean(fields[2] || ''),
          a: clean(fields[3] || ''), b: clean(fields[4] || ''),
          c: clean(fields[5] || ''), d: clean(fields[6] || ''),
          answer: clean(fields[7] || ''),
          explanation: clean(fields[8] || ''),
          difficulty: parseInt(fields[9]) || 2,
          tags: (fields[10] || '').replace(/ARRAY\[/, '').replace(/\]/, '').replace(/'/g, '').split(',').map(s => s.trim()).filter(Boolean),
        });
      }
      return results;
    }
  }
  return [];
}

async function batchInsert(packageId, examType, productLine, values) {
  if (values.length === 0) return;
  const CHUNK = 25;
  for (let i = 0; i < values.length; i += CHUNK) {
    const chunk = values.slice(i, i + CHUNK);
    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, options, correct_answer, explanation, cefr_level, skill_tags, topic, metadata) VALUES ${chunk.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
    try { await execSQL(sql); } catch (e) { console.log(`    Error: ${e.message.substring(0, 100)}`); }
  }
}

async function main() {
  console.log('=== TOEFL ITP S1+S3 Importer ===');
  const pkgS1 = await getPackageId('TOEFL-ITP-S1');
  const pkgS3 = await getPackageId('TOEFL-ITP-S3');
  if (!pkgS1 || !pkgS3) { console.log('Packages not found'); return; }

  // S3 — reading
  for (const file of ['003_seed_s3_passages_a.sql', '004_seed_s3_passages_b.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const tuples = parseSQLTuples(fs.readFileSync(fp, 'utf8'));
    const readingTuples = tuples.filter(t => t.part === 'reading');
    const values = readingTuples.map(t => {
      qCounter++;
      return `('${pkgS3}','TOEFL_ITP','reading','S3-Reading',${qCounter},'reading','reading',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(t.tags)},'Reading Comprehension',${escJson({difficulty:t.difficulty})})`;
    });
    console.log(`  S3 (${file}): ${readingTuples.length} questions`);
    await batchInsert(pkgS3, 'TOEFL_ITP', 'reading', values);
  }

  // S1 — listening
  for (const file of ['008_seed_s1_listening.sql', '009_seed_s1_listening_more.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const tuples = parseSQLTuples(fs.readFileSync(fp, 'utf8'));
    const listenTuples = tuples.filter(t => t.part === 'listening' || t.section === 1);
    const values = listenTuples.map(t => {
      qCounter++;
      const part = t.tags.includes('part_a') ? 'part_a' : t.tags.includes('part_b') ? 'part_b' : 'part_c';
      const topic = part === 'part_a' ? 'Listening: Short Conversations' : part === 'part_b' ? 'Listening: Long Conversations' : 'Listening: Talks';
      return `('${pkgS1}','TOEFL_ITP','listening','${part}',${qCounter},'listening','listening',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(['listening',...t.tags])},${esc(topic)},${escJson({difficulty:t.difficulty})})`;
    });
    console.log(`  S1 (${file}): ${listenTuples.length} questions`);
    await batchInsert(pkgS1, 'TOEFL_ITP', 'listening', values);
  }

  // Final count
  const r = await execSQL('SELECT exam_type, COUNT(*) as c FROM exam_questions GROUP BY exam_type ORDER BY c DESC;');
  console.log('\nFinal counts:', r.substring(0, 500));
}
main().catch(e => console.error('Fatal:', e));