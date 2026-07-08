const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_API = 'https://api.supabase.com/v1/projects/zrnencaixfwpswfpmliv/database/query';
const TOEFL_ITP_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-ToeflITPPractice\\supabase\\migrations';

let qCounter = 2960;

async function execSQL(sql) {
  const res = await fetch(SUPABASE_API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${SUPABASE_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`SQL: ${text.substring(0, 200)}`);
  return text;
}
function esc(s) { if (s == null) return 'NULL'; return `'${String(s).replace(/'/g, "''").substring(0, 5000)}'`; }
function escJson(o) { if (o == null) return 'NULL'; return `'${JSON.stringify(o).replace(/'/g, "''").substring(0, 10000)}'::jsonb`; }
function escArray(a) { if (!a || a.length === 0) return "'{}'"; return `'{"${a.map(s=>String(s).replace(/"/g,'\\"')).join('","')}"}'`; }

async function getPackageId(code) {
  const r = await execSQL(`SELECT id FROM material_packages WHERE package_code = ${esc(code)};`);
  try { return JSON.parse(r)[0]?.id; } catch (_) { return null; }
}

function parseTuples(sql) {
  const inserts = sql.split('INSERT INTO');
  const allTuples = [];
  for (let bi = 1; bi < inserts.length; bi++) {
    const block = inserts[bi];
    if (!block.includes('questions') || !block.includes('VALUES')) continue;
    const vIdx = block.indexOf('VALUES');
    const data = block.substring(vIdx + 6);
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
      const clean = (f) => f.replace(/^E?'/, '').replace(/'$/, '').replace(/''/g, "'").replace(/^E'/, '');
      // S1 format: id(uuid), section(1), part(A/B/C), question, a, b, c, d, answer, explanation, difficulty, ARRAY[...], conversation_id, is_active
      if (fields.length >= 9 && fields[0] && fields[0].startsWith("'")) {
        const section = parseInt(fields[1]) || 0;
        const part = clean(fields[2] || '');
        if (section === 1 && (part === 'A' || part === 'B' || part === 'C')) {
          allTuples.push({
            section: 1, part,
            question: clean(fields[3] || ''),
            a: clean(fields[4] || ''), b: clean(fields[5] || ''),
            c: clean(fields[6] || ''), d: clean(fields[7] || ''),
            answer: clean(fields[8] || ''),
            explanation: clean(fields[9] || ''),
            difficulty: parseInt(fields[10]) || 2,
            tags: (fields[11] || '').replace(/ARRAY\[/, '').replace(/\]/, '').replace(/'/g, '').split(',').map(s => s.trim()).filter(Boolean),
          });
        }
      }
    }
  }
  return allTuples;
}

async function main() {
  console.log('=== TOEFL ITP Listening Import ===');
  const pkgS1 = await getPackageId('TOEFL-ITP-S1');
  if (!pkgS1) { console.log('Package not found'); return; }

  for (const file of ['008_seed_s1_listening.sql', '009_seed_s1_listening_more.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const tuples = parseTuples(fs.readFileSync(fp, 'utf8'));
    console.log(`  ${file}: ${tuples.length} questions`);
    const values = tuples.map(t => {
      qCounter++;
      const partName = t.part === 'A' ? 'part_a' : t.part === 'B' ? 'part_b' : 'part_c';
      const topic = t.part === 'A' ? 'Listening: Short Conversations' : t.part === 'B' ? 'Listening: Long Conversations' : 'Listening: Talks';
      return `('${pkgS1}','TOEFL_ITP','listening','${partName}',${qCounter},'listening','listening',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(['listening',...t.tags])},${esc(topic)},${escJson({difficulty:t.difficulty})})`;
    });
    // Batch insert
    const CHUNK = 25;
    for (let i = 0; i < values.length; i += CHUNK) {
      const chunk = values.slice(i, i + CHUNK);
      const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, options, correct_answer, explanation, cefr_level, skill_tags, topic, metadata) VALUES ${chunk.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
      try { await execSQL(sql); } catch (e) { console.log(`    Error: ${e.message.substring(0, 100)}`); }
    }
  }

  const r = await execSQL('SELECT exam_type, COUNT(*) as c FROM exam_questions GROUP BY exam_type ORDER BY c DESC;');
  console.log('\nFinal:', r.substring(0, 500));
}
main().catch(e => console.error('Fatal:', e));