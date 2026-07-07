/**
 * Fast batch material importer — inserts all questions for a package in a single SQL call.
 * Run after the initial importer to fill in the remaining TOEIC packages.
 */
const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_PROJECT = process.env.SUPABASE_PROJECT_REF || 'zrnencaixfwpswfpmliv';
const SUPABASE_API = `https://api.supabase.com/v1/projects/${SUPABASE_PROJECT}/database/query`;

const TOEIC_LR_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat-toeic\\content\\generated\\toeic_packages';
const TOEIC_SW_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat-toeic\\content\\generated\\toeic_sw';

let qCounter = 0;

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
  // Try fetch first
  const fetchSql = `SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)};`;
  const r = await execSQL(fetchSql);
  try { const p = JSON.parse(r); if (p.length > 0) return p[0].id; } catch (_) {}
  // Insert
  const insSql = `INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata)
    VALUES (${esc(packageCode)}, '${examType}', '${productLine}', ${esc(cefr)}, '${source}', true, ${escJson(metadata)}) RETURNING id;`;
  const r2 = await execSQL(insSql);
  try { const p = JSON.parse(r2); if (p.length > 0) return p[0].id; } catch (_) {}
  return null;
}

async function importTOEICLRBatch() {
  console.log('\n=== TOEIC LR Batch Import ===');
  if (!fs.existsSync(TOEIC_LR_DIR)) { console.log('Dir not found'); return; }

  // Get current max question_number to avoid conflicts
  const maxSql = 'SELECT COALESCE(MAX(question_number), 0) as max_q FROM exam_questions;';
  const r = await execSQL(maxSql);
  try { const p = JSON.parse(r); qCounter = p[0]?.max_q || 0; } catch (_) {}
  console.log(`Starting question counter at: ${qCounter}`);

  const packages = fs.readdirSync(TOEIC_LR_DIR).filter(d => d.startsWith('package_'));
  for (const pkgDir of packages) {
    const pkgPath = path.join(TOEIC_LR_DIR, pkgDir);
    if (!fs.existsSync(path.join(pkgPath, 'manifest.json'))) continue;
    const manifest = JSON.parse(fs.readFileSync(path.join(pkgPath, 'manifest.json'), 'utf8'));
    const pkgNum = manifest.package || pkgDir.replace('package_', '');
    const packageCode = `TOEIC-LR-${String(pkgNum).padStart(2, '0')}`;

    // Check if already imported
    const checkSql = `SELECT COUNT(*) as cnt FROM exam_questions WHERE package_id IN (SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)});`;
    const checkR = await execSQL(checkSql);
    let existingCount = 0;
    try { const p = JSON.parse(checkR); existingCount = p[0]?.cnt || 0; } catch (_) {}
    if (existingCount > 0) { console.log(`  ${packageCode}: already has ${existingCount} questions, skipping`); continue; }

    console.log(`  Importing ${packageCode}...`);
    const packageId = await getOrInsertPackage(packageCode, 'TOEIC', 'listening_reading', manifest.target_cefr || 'C2', 'ai_generated_minimax', { package: pkgNum, counts: manifest.counts });
    if (!packageId) { console.log(`    Failed to get package ID`); continue; }

    // Build all questions for this package in one SQL
    const values = [];
    for (let part = 1; part <= 7; part++) {
      const partFile = path.join(pkgPath, `part${part}.json`);
      if (!fs.existsSync(partFile)) continue;
      const partData = JSON.parse(fs.readFileSync(partFile, 'utf8'));
      const section = part <= 4 ? 'listening' : 'reading';

      if (part === 1 || part === 2 || part === 5) {
        for (const item of (partData.items || [])) {
          qCounter++;
          const qType = part === 1 ? 'photo_description' : part === 2 ? 'question_response' : 'incomplete_sentence';
          const qText = part === 5 ? (item.sentence || '') : (item.prompt_text || item.title || (typeof item.audio_script === 'string' ? item.audio_script : ''));
          const opts = item.options || {};
          const ans = item.correct_answer || '';
          const exp = item.explanation || '';
          values.push(`('${packageId}','TOEIC','listening_reading','${part}',${qCounter},'${qType}','${section}',NULL,${esc(qText)},${escJson(opts)},${esc(ans)},${esc(exp)},${esc(manifest.target_cefr || 'C2')},${escArray([qType])},${escJson({item_id:item.item_id,audio_file:item.audio_file,image_file:item.image_file})})`);
        }
      }
      if (part === 3 || part === 4) {
        for (const set of (partData.sets || [])) {
          const qType = part === 3 ? 'conversation' : 'talk';
          for (const q of (set.questions || [])) {
            qCounter++;
            const qText = q.question_text || '';
            const opts = q.options || {};
            const ans = q.correct_answer || '';
            const exp = q.explanation || '';
            values.push(`('${packageId}','TOEIC','listening_reading','${part}',${qCounter},'${qType}','${section}',NULL,${esc(qText)},${escJson(opts)},${esc(ans)},${esc(exp)},${esc(manifest.target_cefr || 'C2')},${escArray([qType])},${escJson({set_id:set.set_id,audio_file:set.audio_file})})`);
          }
        }
      }
      if (part === 6) {
        for (const set of (partData.sets || [])) {
          for (const q of (set.questions || [])) {
            qCounter++;
            values.push(`('${packageId}','TOEIC','listening_reading','${part}',${qCounter},'text_completion','reading',NULL,${esc(q.question_text || '')},${escJson(q.options || {})},${esc(q.correct_answer || '')},${esc(q.explanation || '')},${esc(manifest.target_cefr || 'C2')},${escArray(['text_completion'])},${escJson({set_id:set.set_id,blank_number:q.blank_number})})`);
          }
        }
      }
      if (part === 7) {
        const allSets = [...(partData.single_sets || []), ...(partData.double_sets || [])];
        for (const set of allSets) {
          for (const q of (set.questions || [])) {
            qCounter++;
            const qText = q.question_text || q.question || '';
            let opts = q.options || {};
            const ans = q.correct_answer || (q.correct_index !== undefined ? String.fromCharCode(65 + q.correct_index) : '') || q.correct_option || '';
            if (Array.isArray(opts) && opts.length > 0 && typeof opts[0] === 'string') {
              const norm = {}; opts.forEach((v, i) => { norm[String.fromCharCode(65 + i)] = v; }); opts = norm;
            }
            values.push(`('${packageId}','TOEIC','listening_reading','${part}',${qCounter},'reading_comprehension','reading',NULL,${esc(qText)},${escJson(opts)},${esc(ans)},${esc(q.explanation || '')},${esc(manifest.target_cefr || 'C2')},${escArray(['reading_comprehension'])},${escJson({set_id:set.set_id})})`);
          }
        }
      }
    }

    // Batch insert (chunk if too large)
    const CHUNK = 50;
    for (let i = 0; i < values.length; i += CHUNK) {
      const chunk = values.slice(i, i + CHUNK);
      const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, options, correct_answer, explanation, cefr_level, skill_tags, metadata) VALUES ${chunk.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
      try { await execSQL(sql); } catch (e) { console.log(`    Chunk ${i}/${values.length} error: ${e.message.substring(0, 100)}`); }
    }
    console.log(`    Inserted ${values.length} questions`);
  }
}

async function importTOEICSWBatch() {
  console.log('\n=== TOEIC SW Batch Import ===');
  if (!fs.existsSync(TOEIC_SW_DIR)) { console.log('Dir not found'); return; }
  const packages = fs.readdirSync(TOEIC_SW_DIR).filter(d => d.startsWith('package_'));
  for (const pkgDir of packages) {
    const manifestPath = path.join(TOEIC_SW_DIR, pkgDir, 'manifest.json');
    if (!fs.existsSync(manifestPath)) continue;
    const data = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const packageCode = data.package_code || `TOEIC-SW-${pkgDir.replace('package_', '')}`;

    const checkSql = `SELECT COUNT(*) as cnt FROM exam_questions WHERE package_id IN (SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)});`;
    const checkR = await execSQL(checkSql);
    let existingCount = 0;
    try { const p = JSON.parse(checkR); existingCount = p[0]?.cnt || 0; } catch (_) {}
    if (existingCount > 0) { console.log(`  ${packageCode}: already has ${existingCount} items, skipping`); continue; }

    console.log(`  Importing ${packageCode}...`);
    const packageId = await getOrInsertPackage(packageCode, 'TOEIC', 'speaking_writing', 'C2', 'ai_generated_minimax', { format: data.format });
    if (!packageId) continue;

    const values = [];
    for (const item of (data.speaking || [])) {
      qCounter++;
      values.push(`('${packageId}','TOEIC','speaking_writing','S${item.question_number || 1}',${qCounter},${esc(item.type || 'speaking')},'speaking',NULL,${esc(item.prompt_text || '')},${esc(item.scoring_rubric || '')},${esc(item.sample_response || '')},${esc(item.difficulty || 'C2')},${esc(item.cefr_level || 'C2')},${escArray([item.type?.replace(/-/g,'_') || 'speaking'])},${escJson({question_number:item.question_number,title:item.title,information_card:item.information_card,audio_path:item.audio_path,image_path:item.image_path})})`);
    }
    for (const item of (data.writing || [])) {
      qCounter++;
      values.push(`('${packageId}','TOEIC','speaking_writing','W${item.question_number || 1}',${qCounter},${esc(item.type || 'writing')},'writing',NULL,${esc(item.prompt_text || '')},${esc(item.scoring_rubric || '')},${esc(item.sample_response || '')},${esc(item.difficulty || 'C2')},${esc(item.cefr_level || 'C2')},${escArray([item.type?.replace(/-/g,'_') || 'writing'])},${escJson({question_number:item.question_number,title:item.title,image_path:item.image_path,required_words_json:item.required_words_json})})`);
    }

    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, scoring_rubric, sample_response, difficulty, cefr_level, skill_tags, metadata) VALUES ${values.join(',')} ON CONFLICT (package_id, question_number) DO NOTHING;`;
    try { await execSQL(sql); console.log(`    Inserted ${values.length} items`); } catch (e) { console.log(`    Error: ${e.message.substring(0, 200)}`); }
  }
}

async function main() {
  console.log('=== Fast Batch Material Importer ===');
  try { await importTOEICLRBatch(); } catch (e) { console.log(`LR error: ${e.message}`); }
  try { await importTOEICSWBatch(); } catch (e) { console.log(`SW error: ${e.message}`); }
  console.log(`\nDone. Total questions counter: ${qCounter}`);
}
main().catch(e => { console.error('Fatal:', e); process.exit(1); });