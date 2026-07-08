/**
 * Multi-source material importer v2 — handles multiline SQL, nested JSON, etc.
 */
const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_API = 'https://api.supabase.com/v1/projects/zrnencaixfwpswfpmliv/database/query';

const TOEFL_ITP_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-ToeflITPPractice\\supabase\\migrations';
const TOEFL_SIM_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-SIMULASI-TES-TOEFL-GRATIS\\data';
const CAE_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-cae-question-bank\\data';

let qCounter = 2500;

async function execSQL(sql) {
  const res = await fetch(SUPABASE_API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${SUPABASE_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`SQL failed (${res.status}): ${text.substring(0, 300)}`);
  return text;
}

function esc(s) {
  if (s === null || s === undefined) return 'NULL';
  return `'${String(s).replace(/'/g, "''").substring(0, 5000)}'`;
}
function escJson(obj) {
  if (obj === null || obj === undefined) return 'NULL';
  return `'${JSON.stringify(obj).replace(/'/g, "''").substring(0, 10000)}'::jsonb`;
}
function escArray(arr) {
  if (!arr || !Array.isArray(arr) || arr.length === 0) return "'{}'";
  return `'{"${arr.map(s => String(s).replace(/"/g, '\\"')).join('","')}"}'`;
}

async function getOrInsertPackage(code, exam, pl, cefr, source, meta) {
  const r = await execSQL(`SELECT id FROM material_packages WHERE package_code = ${esc(code)};`);
  try { const p = JSON.parse(r); if (p.length > 0) return p[0].id; } catch (_) {}
  const r2 = await execSQL(`INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata) VALUES (${esc(code)},'${exam}','${pl}',${esc(cefr)},'${source}',true,${escJson(meta)}) RETURNING id;`);
  try { const p = JSON.parse(r2); if (p.length > 0) return p[0].id; } catch (_) {}
  return null;
}

async function batchInsert(values) {
  if (values.length === 0) return 0;
  const CHUNK = 30;
  let inserted = 0;
  for (let i = 0; i < values.length; i += CHUNK) {
    const chunk = values.slice(i, i + CHUNK);
    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, options, correct_answer, explanation, cefr_level, skill_tags, topic, metadata) VALUES ${chunk.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
    try { await execSQL(sql); inserted += chunk.length; } catch (e) { console.log(`    Batch error: ${e.message.substring(0, 100)}`); }
  }
  return inserted;
}

// ============================================================
// 1. TOEFL ITP — multiline SQL parsing
// ============================================================

function parseMultilineSQL(sql) {
  const lines = sql.split('\n');
  let inValues = false;
  let current = '';
  const tuples = [];
  for (const line of lines) {
    if (line.includes('VALUES')) { inValues = true; continue; }
    if (!inValues || line.trim().startsWith('--')) continue;
    if (line.trim().startsWith('(')) { current = line.trim(); }
    else if (current) { current += ' ' + line.trim(); }
    if (current && (current.endsWith('),') || current.endsWith(');'))) {
      // Extract fields using regex that handles escaped quotes
      const m = current.match(/\((\d+),\s*'(structure|written_expression|reading|listening)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)',\s*'([A-D])',\s*'((?:[^']|'')*)',\s*(\d+),\s*ARRAY\[([^\]]*)\],\s*(true|false)\)/);
      if (m) {
        const tags = m[11] ? m[11].replace(/'/g, '').split(',').map(s => s.trim()).filter(Boolean) : [];
        tuples.push({
          section: parseInt(m[1]), part: m[2], question: m[3],
          a: m[4], b: m[5], c: m[6], d: m[7], answer: m[8],
          explanation: m[9], difficulty: parseInt(m[10]), tags
        });
      }
      current = '';
    }
  }
  return tuples;
}

async function importTOEFLITP() {
  console.log('\n=== TOEFL ITP (SQL) ===');
  const pkgS1 = await getOrInsertPackage('TOEFL-ITP-S1', 'TOEFL_ITP', 'listening', 'B2', 'open_source_toeflitp', {});
  const pkgS2 = await getOrInsertPackage('TOEFL-ITP-S2', 'TOEFL_ITP', 'structure', 'B2', 'open_source_toeflitp', {});
  const pkgS3 = await getOrInsertPackage('TOEFL-ITP-S3', 'TOEFL_ITP', 'reading', 'B2', 'open_source_toeflitp', {});
  if (!pkgS1 || !pkgS2 || !pkgS3) { console.log('  Package creation failed'); return; }

  // S2
  const s2File = path.join(TOEFL_ITP_DIR, '002_seed_s2_questions.sql');
  if (fs.existsSync(s2File)) {
    const tuples = parseMultilineSQL(fs.readFileSync(s2File, 'utf8'));
    const values = tuples.map(t => {
      qCounter++;
      const topic = t.part === 'structure' ? 'Structure: Sentence Completion' : 'Written Expression: Error Identification';
      return `('${pkgS2}','TOEFL_ITP','structure','S2-${t.part}',${qCounter},'${t.part}','structure',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(t.tags)},${esc(topic)},${escJson({difficulty:t.difficulty})})`;
    });
    console.log(`  S2: ${tuples.length} questions`);
    await batchInsert(values);
  }

  // S3
  for (const file of ['003_seed_s3_passages_a.sql', '004_seed_s3_passages_b.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const tuples = parseMultilineSQL(fs.readFileSync(fp, 'utf8'));
    const values = tuples.map(t => {
      qCounter++;
      return `('${pkgS3}','TOEFL_ITP','reading','S3-Reading',${qCounter},'reading','reading',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(t.tags)},'Reading Comprehension',${escJson({difficulty:t.difficulty})})`;
    });
    console.log(`  S3 (${file}): ${tuples.length} questions`);
    await batchInsert(values);
  }

  // S1
  for (const file of ['008_seed_s1_listening.sql', '009_seed_s1_listening_more.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const tuples = parseMultilineSQL(fs.readFileSync(fp, 'utf8'));
    const values = tuples.map(t => {
      qCounter++;
      const part = t.tags.includes('part_a') ? 'part_a' : t.tags.includes('part_b') ? 'part_b' : 'part_c';
      const topic = part === 'part_a' ? 'Listening: Short Conversations' : part === 'part_b' ? 'Listening: Long Conversations' : 'Listening: Talks';
      return `('${pkgS1}','TOEFL_ITP','listening','${part}',${qCounter},'listening','listening',${esc(t.question)},${escJson({A:t.a,B:t.b,C:t.c,D:t.d})},${esc(t.answer)},${esc(t.explanation)},'B2',${escArray(['listening',...t.tags])},${esc(topic)},${escJson({difficulty:t.difficulty})})`;
    });
    console.log(`  S1 (${file}): ${tuples.length} questions`);
    await batchInsert(values);
  }
}

// ============================================================
// 2. CAE — nested JSON with sections
// ============================================================

async function importCAE() {
  console.log('\n=== CAE C1 Advanced (JSON) ===');
  const pkg = await getOrInsertPackage('CAE-C1-01', 'GENERAL', 'reading_listening', 'C1', 'open_source_cae', {});
  if (!pkg) return;
  const data = JSON.parse(fs.readFileSync(path.join(CAE_DIR, 'cae_unified.json'), 'utf8'));
  const values = [];
  for (const [sectionName, section] of Object.entries(data.sections || {})) {
    const questions = section.questions || [];
    for (const q of questions) {
      qCounter++;
      const qText = q.question || q.instruction || q.passage_title || q.gap_number ? `Gap ${q.gap_number}: ${q.passage_title || ''}` : '';
      const opts = {};
      let correctAnswer = '';
      if (q.options && Array.isArray(q.options)) {
        q.options.forEach((o, i) => {
          const label = o.label || String.fromCharCode(65 + i);
          opts[label] = o.text || '';
          if (o.correct) correctAnswer = label;
        });
      }
      const part = String(q.part || sectionName);
      const section = q.paper || sectionName;
      const topic = sectionName === 'listening' ? 'CAE Listening' : 'CAE Reading & Use of English';
      values.push(`('${pkg}','GENERAL','reading_listening','${part}',${qCounter},'${q.type || 'multiple_choice'}','${section}',
        ${esc(qText)},${escJson(opts)},${esc(correctAnswer)},${esc(q.explanation || '')},'C1',
        ${escArray([q.type || 'mc'])},${esc(topic)},${escJson({question_id:q.question_id,audio_file:q.audio_file,instruction:q.instruction})})`);
    }
  }
  console.log(`  CAE: ${values.length} questions`);
  await batchInsert(values);
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log('=== Material Importer v2 ===');
  try { await importTOEFLITP(); } catch (e) { console.log(`TOEFL ITP: ${e.message}`); }
  try { await importCAE(); } catch (e) { console.log(`CAE: ${e.message}`); }
  console.log(`\nCounter: ${qCounter}`);
  const r = await execSQL('SELECT exam_type, COUNT(*) as c FROM exam_questions GROUP BY exam_type ORDER BY c DESC;');
  console.log('Final:', r.substring(0, 500));
}
main().catch(e => console.error('Fatal:', e));