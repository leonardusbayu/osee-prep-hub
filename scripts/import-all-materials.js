/**
 * Multi-source material importer — TOEFL ITP + TOEFL Simulator + CAE + IELTS
 * Reads SQL seed files and JSON data files, populates exam_questions via Supabase Management API.
 *
 * Sources:
 *  1. mat3-ToeflITPPractice — 356 TOEFL ITP questions (SQL INSERTs)
 *  2. mat3-SIMULASI-TES-TOEFL-GRATIS — 180 TOEFL questions (JSON)
 *  3. mat3-cae-question-bank — 148+ CAE questions (JSON)
 *  4. mat3-ielts-ai-dataset — already imported, check for any missed files
 */
const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_API = 'https://api.supabase.com/v1/projects/zrnencaixfwpswfpmliv/database/query';

const TOEFL_ITP_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-ToeflITPPractice\\supabase\\migrations';
const TOEFL_SIM_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-SIMULASI-TES-TOEFL-GRATIS\\data';
const CAE_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat3-cae-question-bank\\data';

let qCounter = 2300; // Start after existing 2,220 + buffer

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

async function getOrInsertPackage(packageCode, examType, productLine, cefr, source, metadata) {
  const fetchSql = `SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)};`;
  const r = await execSQL(fetchSql);
  try { const p = JSON.parse(r); if (p.length > 0) return p[0].id; } catch (_) {}
  const insSql = `INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata)
    VALUES (${esc(packageCode)}, '${examType}', '${productLine}', ${esc(cefr)}, '${source}', true, ${escJson(metadata)}) RETURNING id;`;
  const r2 = await execSQL(insSql);
  try { const p = JSON.parse(r2); if (p.length > 0) return p[0].id; } catch (_) {}
  return null;
}

async function batchInsert(packageId, examType, productLine, values) {
  if (values.length === 0) return;
  const CHUNK = 40;
  for (let i = 0; i < values.length; i += CHUNK) {
    const chunk = values.slice(i, i + CHUNK);
    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, options, correct_answer, explanation, cefr_level, skill_tags, topic, metadata)
      VALUES ${chunk.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
    try { await execSQL(sql); } catch (e) { console.log(`    Batch ${i}/${values.length} error: ${e.message.substring(0, 150)}`); }
  }
}

// ============================================================
// 1. TOEFL ITP — parse SQL INSERT statements
// ============================================================

async function importTOEFLITP() {
  console.log('\n=== TOEFL ITP (SQL seed) ===');
  if (!fs.existsSync(TOEFL_ITP_DIR)) { console.log('  Dir not found'); return; }

  // Create one package per section
  const pkgS1 = await getOrInsertPackage('TOEFL-ITP-S1', 'TOEFL_ITP', 'listening', 'B2', 'open_source_toeflitp', { section: 'Listening Comprehension' });
  const pkgS2 = await getOrInsertPackage('TOEFL-ITP-S2', 'TOEFL_ITP', 'structure', 'B2', 'open_source_toeflitp', { section: 'Structure & Written Expression' });
  const pkgS3 = await getOrInsertPackage('TOEFL-ITP-S3', 'TOEFL_ITP', 'reading', 'B2', 'open_source_toeflitp', { section: 'Reading Comprehension' });
  const pkgVocab = await getOrInsertPackage('TOEFL-ITP-VOCAB', 'TOEFL_ITP', 'vocabulary', 'B2', 'open_source_toeflitp', { section: 'Vocabulary' });
  if (!pkgS1 || !pkgS2 || !pkgS3) { console.log('  Failed to create packages'); return; }

  // Parse S2 questions (structure + written expression)
  const s2File = path.join(TOEFL_ITP_DIR, '002_seed_s2_questions.sql');
  if (fs.existsSync(s2File)) {
    const sql = fs.readFileSync(s2File, 'utf8');
    const values = [];
    const inserts = sql.match(/\((\d+),'(structure|written_expression)','([^']+)','([^']+)','([^']+)','([^']+)','([^']+)',(true|false)\)/g) || [];
    // More robust: parse line by line
    const lines = sql.split('\n');
    for (const line of lines) {
      // Match: (2,'structure','question','a','b','c','d','A','explanation',2,ARRAY[...],true)
      const m = line.match(/^\(\d+,'(structure|written_expression)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','([A-D])','((?:[^']|'')*)',(\d),ARRAY\[([^\]]*)\],(true|false)\)/);
      if (m) {
        qCounter++;
        const part = m[1] === 'structure' ? 'S2-Structure' : 'S2-WrittenExpression';
        const topic = m[1] === 'structure' ? 'Structure: Sentence Completion' : 'Written Expression: Error Identification';
        const tags = m[10] ? m[10].replace(/'/g, '').split(',').map(s => s.trim()).filter(Boolean) : [];
        values.push(`('${pkgS2}','TOEFL_ITP','structure','${part}',${qCounter},'${m[1]}','structure',
          ${esc(m[2])},${escJson({A: m[3], B: m[4], C: m[5], D: m[6]})},${esc(m[7])},${esc(m[8])},'B2',
          ${escArray(tags)},${esc(topic)},${escJson({difficulty: parseInt(m[9])})})`);
      }
    }
    console.log(`  S2: ${values.length} questions parsed`);
    await batchInsert(pkgS2, 'TOEFL_ITP', 'structure', values);
  }

  // Parse S3 passages + questions
  for (const file of ['003_seed_s3_passages_a.sql', '004_seed_s3_passages_b.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const sql = fs.readFileSync(fp, 'utf8');
    const values = [];
    const lines = sql.split('\n');
    for (const line of lines) {
      // Match reading questions: (3,'reading','question','a','b','c','d','A','explanation',2,ARRAY[...],true,'passage-uuid')
      const m = line.match(/^\(\d+,'reading','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','([A-D])','((?:[^']|'')*)',(\d),ARRAY\[([^\]]*)\],(true|false),\) values/);
      if (!m) {
        // Try simpler pattern
        const m2 = line.match(/^\(\d+,'reading','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','([A-D])','((?:[^']|'')*)'/);
        if (m2) {
          qCounter++;
          const tags = line.match(/ARRAY\[([^\]]*)\]/);
          const tagList = tags ? tags[1].replace(/'/g, '').split(',').map(s => s.trim()).filter(Boolean) : [];
          values.push(`('${pkgS3}','TOEFL_ITP','reading','S3-Reading',${qCounter},'reading','reading',
            ${esc(m2[1])},${escJson({A: m2[2], B: m2[3], C: m2[4], D: m2[5]})},${esc(m2[6])},${esc(m2[7])},'B2',
            ${escArray(tagList)},'Reading Comprehension',${escJson({})})`);
        }
      }
    }
    console.log(`  S3 (${file}): ${values.length} questions parsed`);
    await batchInsert(pkgS3, 'TOEFL_ITP', 'reading', values);
  }

  // Parse S1 listening questions
  for (const file of ['008_seed_s1_listening.sql', '009_seed_s1_listening_more.sql']) {
    const fp = path.join(TOEFL_ITP_DIR, file);
    if (!fs.existsSync(fp)) continue;
    const sql = fs.readFileSync(fp, 'utf8');
    const values = [];
    const lines = sql.split('\n');
    for (const line of lines) {
      const m = line.match(/^\(\d+,'listening','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','((?:[^']|'')*)','([A-D])','((?:[^']|'')*)'/);
      if (m) {
        qCounter++;
        const partMatch = line.match(/'(part_a|part_b|part_c)'/);
        const part = partMatch ? partMatch[1] : 'listening';
        const topic = part === 'part_a' ? 'Listening: Short Conversations' : part === 'part_b' ? 'Listening: Long Conversations' : 'Listening: Talks';
        values.push(`('${pkgS1}','TOEFL_ITP','listening','${part}',${qCounter},'listening','listening',
          ${esc(m[1])},${escJson({A: m[2], B: m[3], C: m[4], D: m[5]})},${esc(m[6])},${esc(m[7])},'B2',
          ${escArray(['listening'])},${esc(topic)},${escJson({})})`);
      }
    }
    console.log(`  S1 (${file}): ${values.length} questions parsed`);
    await batchInsert(pkgS1, 'TOEFL_ITP', 'listening', values);
  }

  // Parse vocabulary
  const vocabFile = path.join(TOEFL_ITP_DIR, '007_vocab_seed.sql');
  if (fs.existsSync(vocabFile)) {
    const sql = fs.readFileSync(vocabFile, 'utf8');
    const values = [];
    const lines = sql.split('\n');
    for (const line of lines) {
      const m = line.match(/^\('([a-zA-Z]+)','([^']+)','([^']+)','((?:[^']|'')*)'/);
      if (m) {
        qCounter++;
        values.push(`('${pkgVocab}','TOEFL_ITP','vocabulary','Vocab',${qCounter},'vocabulary','vocabulary',
          ${esc(`What does "${m[1]}" mean?`)},${escJson({A: m[2], B: 'N/A', C: 'N/A', D: 'N/A'})},'','${m[2]}','B2',
          ${escArray(['vocabulary'])},'Vocabulary',${escJson({word: m[1], definition: m[2], category: m[3]})})`);
      }
    }
    console.log(`  Vocab: ${values.length} words parsed`);
    await batchInsert(pkgVocab, 'TOEFL_ITP', 'vocabulary', values);
  }
}

// ============================================================
// 2. TOEFL Simulator — JSON files
// ============================================================

async function importTOEFLSim() {
  console.log('\n=== TOEFL Simulator (JSON) ===');
  if (!fs.existsSync(TOEFL_SIM_DIR)) { console.log('  Dir not found'); return; }

  const pkg = await getOrInsertPackage('TOEFL-SIM-01', 'TOEFL_ITP', 'listening_reading', 'B2', 'open_source_simulator', { source: 'SIMULASI-TES-TOEFL-GRATIS' });
  if (!pkg) { console.log('  Failed to create package'); return; }

  const files = fs.readdirSync(TOEFL_SIM_DIR).filter(f => f.endsWith('.json') && f !== 'manifest.json');
  const values = [];

  for (const file of files) {
    const data = JSON.parse(fs.readFileSync(path.join(TOEFL_SIM_DIR, file), 'utf8'));
    const section = data.meta?.section || file.split('-')[0];
    const items = data.items || data.passages || [];

    for (const item of items) {
      const questions = item.questions || [];
      const context = item.passage || item.ttsText || item.title || '';

      for (const q of questions) {
        qCounter++;
        const choices = q.choices || q.options || [];
        // answer is 0-indexed integer
        const answerIdx = typeof q.answer === 'number' ? q.answer : 0;
        const correctAnswer = String.fromCharCode(65 + answerIdx);
        const opts = {};
        choices.forEach((c, i) => { opts[String.fromCharCode(65 + i)] = c; });
        const qType = q.type || item.type || 'question';
        const part = section === 'listening' ? 'S1' : section === 'structure' ? 'S2' : 'S3';
        const topic = section === 'listening' ? 'Listening' : section === 'structure' ? (qType.includes('error') ? 'Written Expression' : 'Structure') : 'Reading Comprehension';
        const sectionClean = section === 'listening' ? 'listening' : section === 'structure' ? 'structure' : 'reading';

        values.push(`('${pkg}','TOEFL_ITP','listening_reading','${part}',${qCounter},'${qType}','${sectionClean}',
          ${esc(q.question || q.question_text || '')},${escJson(opts)},${esc(correctAnswer)},${esc(q.explanation || '')},'B2',
          ${escArray([qType])},${esc(topic)},${escJson({context: context.substring(0, 500), source_file: file})})`);
      }
    }
  }

  console.log(`  Total: ${values.length} questions`);
  await batchInsert(pkg, 'TOEFL_ITP', 'listening_reading', values);
}

// ============================================================
// 3. CAE Question Bank — JSON files
// ============================================================

async function importCAE() {
  console.log('\n=== CAE C1 Advanced (JSON) ===');
  if (!fs.existsSync(CAE_DIR)) { console.log('  Dir not found'); return; }

  const pkg = await getOrInsertPackage('CAE-C1-01', 'GENERAL', 'reading_listening', 'C1', 'open_source_cae', { source: 'cae-question-bank' });
  if (!pkg) { console.log('  Failed to create package'); return; }

  // Import cae_unified.json (main file with 148 questions)
  const unifiedFile = path.join(CAE_DIR, 'cae_unified.json');
  if (fs.existsSync(unifiedFile)) {
    const data = JSON.parse(fs.readFileSync(unifiedFile, 'utf8'));
    const values = [];

    // Parse structure — could be array of questions or nested by test/section
    const questions = Array.isArray(data) ? data : (data.questions || data.items || []);
    for (const q of questions) {
      qCounter++;
      const qText = q.question || q.question_text || q.text || '';
      const choices = q.choices || q.options || q.answers || [];
      const answerIdx = typeof q.answer === 'number' ? q.answer : (typeof q.correct === 'number' ? q.correct : 0);
      const correctAnswer = String.fromCharCode(65 + answerIdx);
      const opts = {};
      if (Array.isArray(choices)) {
        choices.forEach((c, i) => { opts[String.fromCharCode(65 + i)] = typeof c === 'string' ? c : (c.text || c.value || ''); });
      } else if (typeof choices === 'object') {
        Object.assign(opts, choices);
      }
      const section = q.section || q.type || 'reading';
      const part = q.part || section;
      const topic = q.topic || q.skill || 'Reading';

      values.push(`('${pkg}','GENERAL','reading_listening','${part}',${qCounter},'${q.question_type || q.type || 'multiple_choice'}','${section}',
        ${esc(qText)},${escJson(opts)},${esc(correctAnswer)},${esc(q.explanation || q.reasoning || '')},'C1',
        ${escArray([topic])},${esc(topic)},${escJson({source: 'cae_unified', test: q.test || 'unknown'})})`);
    }
    console.log(`  CAE unified: ${values.length} questions`);
    await batchInsert(pkg, 'GENERAL', 'reading_listening', values);
  }

  // Import cae_examenglish_test2.json
  const test2File = path.join(CAE_DIR, 'cae_examenglish_test2.json');
  if (fs.existsSync(test2File)) {
    const data = JSON.parse(fs.readFileSync(test2File, 'utf8'));
    const values = [];
    const questions = Array.isArray(data) ? data : (data.questions || data.items || []);
    for (const q of questions) {
      qCounter++;
      const qText = q.question || q.question_text || q.text || '';
      const choices = q.choices || q.options || [];
      const answerIdx = typeof q.answer === 'number' ? q.answer : 0;
      const correctAnswer = String.fromCharCode(65 + answerIdx);
      const opts = {};
      if (Array.isArray(choices)) {
        choices.forEach((c, i) => { opts[String.fromCharCode(65 + i)] = typeof c === 'string' ? c : (c.text || ''); });
      }
      values.push(`('${pkg}','GENERAL','reading_listening','${q.part || 'reading'}',${qCounter},'${q.type || 'mc'}','${q.section || 'reading'}',
        ${esc(qText)},${escJson(opts)},${esc(correctAnswer)},${esc(q.explanation || '')},'C1',
        ${escArray(['cae'])},'CAE ${q.section || 'Reading'}',${escJson({source: 'cae_test2'})})`);
    }
    console.log(`  CAE test2: ${values.length} questions`);
    await batchInsert(pkg, 'GENERAL', 'reading_listening', values);
  }
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log('=== Multi-Source Material Importer ===');
  console.log(`Time: ${new Date().toISOString()}`);

  try { await importTOEFLITP(); } catch (e) { console.log(`TOEFL ITP error: ${e.message}`); }
  try { await importTOEFLSim(); } catch (e) { console.log(`TOEFL Sim error: ${e.message}`); }
  try { await importCAE(); } catch (e) { console.log(`CAE error: ${e.message}`); }

  console.log('\n=== Import Complete ===');
  console.log(`Total question counter: ${qCounter}`);

  // Verify
  const r = await execSQL('SELECT exam_type, COUNT(*) as c FROM exam_questions GROUP BY exam_type ORDER BY c DESC;');
  console.log('Final counts:', r.substring(0, 500));
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });