/**
 * Material Importer — reads IELTS + TOEIC JSON content from cloned repos
 * and populates material_packages, material_assets, exam_questions in Supabase
 * via the Supabase Management API (SQL execution).
 *
 * Usage: node scripts/import-materials.js
 *
 * Sources:
 *  - IELTS: C:\Users\HONOR\AppData\Local\Temp\opencode\mat2-ielts-ai-dataset
 *  - TOEIC LR: C:\Users\HONOR\AppData\Local\Temp\opencode\mat-toeic\content\generated\toeic_packages
 *  - TOEIC SW: C:\Users\HONOR\AppData\Local\Temp\opencode\mat-toeic\content\generated\toeic_sw
 *  - TOEIC standalone: C:\Users\HONOR\AppData\Local\Temp\opencode\mat-toeic\content\generated\toeic
 */

const fs = require('fs');
const path = require('path');

const SUPABASE_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const SUPABASE_PROJECT = process.env.SUPABASE_PROJECT_REF || 'zrnencaixfwpswfpmliv';
const SUPABASE_API = `https://api.supabase.com/v1/projects/${SUPABASE_PROJECT}/database/query`;

const IELTS_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat2-ielts-ai-dataset';
const TOEIC_LR_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat-toeic\\content\\generated\\toeic_packages';
const TOEIC_SW_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat-toeic\\content\\generated\\toeic_sw';
const TOEIC_STANDALONE_DIR = 'C:\\Users\\HONOR\\AppData\\Local\\Temp\\opencode\\mat-toeic\\content\\generated\\toeic';

let questionCounter = 0;
let packageCounter = 0;
let assetCounter = 0;

async function execSQL(sql) {
  const res = await fetch(SUPABASE_API, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`SQL failed (${res.status}): ${text.substring(0, 500)}`);
  }
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

// ============================================================
// IMPORT: IELTS Reading/Listening/Writing
// ============================================================

async function importIELTS() {
  console.log('\n=== Importing IELTS materials ===');
  const drillReadingDir = path.join(IELTS_DIR, 'practice_drills', 'reading');
  const drillListeningDir = path.join(IELTS_DIR, 'practice_drills', 'listening');
  const drillWritingDir = path.join(IELTS_DIR, 'practice_drills', 'writing');
  const mockReadingDir = path.join(IELTS_DIR, 'synthetic_official_mocks', 'reading');
  const mockListeningDir = path.join(IELTS_DIR, 'synthetic_official_mocks', 'listening');
  const mockWritingDir = path.join(IELTS_DIR, 'synthetic_official_mocks', 'writing');

  for (const dir of [drillReadingDir, drillListeningDir, drillWritingDir, mockReadingDir, mockListeningDir, mockWritingDir]) {
    if (!fs.existsSync(dir)) { console.log(`  Skipping ${dir} (not found)`); continue; }
    const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));
    for (const file of files) {
      const fp = path.join(dir, file);
      console.log(`  Importing ${file}...`);
      try {
        const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
        await importIELTSFile(data, file);
      } catch (e) {
        console.log(`    ERROR: ${e.message}`);
      }
    }
  }
}

async function importIELTSFile(data, filename) {
  const title = data.title || filename.replace('.json', '');
  const examType = 'IELTS';
  const isReading = filename.includes('reading');
  const isListening = filename.includes('listening');
  const isWriting = filename.includes('writing');
  const productLine = isWriting ? 'writing' : isReading ? 'reading' : 'listening';
  const section = isWriting ? 'writing' : isReading ? 'reading' : 'listening';
  const cefrLevel = data.difficulty || null;
  const isMock = filename.includes('mock') || !filename.includes('practice');
  const packageCode = `IELTS-${productLine.toUpperCase().replace('WRITING','W').replace('READING','R').replace('LISTENING','L')}-${String(packageCounter + 1).padStart(2, '0')}`;

  // Insert package
  const pkgSql = `INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata)
    VALUES (${esc(packageCode)}, '${examType}', '${productLine}', ${esc(cefrLevel)}, 'ai_generated_dataset', true,
    ${escJson({ title, difficulty: cefrLevel, is_mock: isMock, source_file: filename, duration: data.duration })}
    ) ON CONFLICT (package_code) DO NOTHING RETURNING id;`;

  const pkgResult = await execSQL(pkgSql);
  let packageId;
  try {
    const parsed = JSON.parse(pkgResult);
    if (parsed.length > 0) {
      packageId = parsed[0].id;
    }
  } catch (_) {}

  // If package already existed (ON CONFLICT DO NOTHING returned empty), fetch it
  if (!packageId) {
    const fetchSql = `SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)};`;
    const fetchResult = await execSQL(fetchSql);
    try {
      const parsed = JSON.parse(fetchResult);
      if (parsed.length > 0) packageId = parsed[0].id;
    } catch (_) {}
  }
  if (!packageId) { console.log(`    Could not insert/fetch package ${packageCode}`); return; }
  packageCounter++;
  console.log(`    Package: ${packageCode} (id: ${packageId.substring(0, 8)}...)`);

  // WRITING: flat tasks array
  if (isWriting && data.tasks) {
    for (const task of data.tasks) {
      const qNum = task.task_number || 0;
      const qType = task.task_type || 'task';
      const qText = task.prompt || task.title || '';
      const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, difficulty, cefr_level, metadata)
        VALUES ('${packageId}', '${examType}', '${productLine}', 'W${qNum}', ${questionCounter + 1}, ${esc(qType)}, '${section}',
        ${esc(qText)}, ${esc(cefrLevel)}, ${esc(cefrLevel)},
        ${escJson({ min_words: task.min_words, max_words: task.max_words, suggested_time: task.suggested_time, title: task.title })}
        ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
      await execSQL(sql);
      questionCounter++;
    }
    return;
  }

  // READING: passages > groups > questions
  // LISTENING: sections > question_groups > questions
  const containers = data.passages || data.sections || [];
  for (const container of containers) {
    const containerTitle = container.title || `Section ${container.passage_number || container.section_number || '?'}`;
    const containerContent = container.content || container.transcript || '';
    const groups = container.groups || container.question_groups || [];

    // Insert passage/transcript as material_asset
    if (containerContent) {
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, transcript, context, metadata)
        VALUES ('${packageId}', '${isReading ? 'passage' : 'transcript'}', null, ${esc(containerTitle)}, ${esc(containerContent)}, ${esc(containerContent.substring(0, 500))}, ${escJson({ source: isReading ? 'passage' : 'listening_transcript' })})
        RETURNING id;`;
      const assetResult = await execSQL(assetSql);
      try {
        const parsed = JSON.parse(assetResult);
        if (parsed.length > 0) assetCounter++;
      } catch (_) {}
    }

    for (const group of groups) {
      const groupType = group.question_type || 'unknown';
      const questions = group.questions || [];
      for (const q of questions) {
        const qText = q.text || q.question || q.question_text || '';
        const answer = q.answer || '';
        const acceptedAnswers = q.accepted_answers || [];
        const options = q.options || q.completion_gaps || q.matching_pairs || null;
        const wordBank = q.word_bank || null;
        const wordLimit = q.word_limit || null;

        const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, question_text, options, correct_answer, explanation, cefr_level, skill_tags, metadata)
          VALUES ('${packageId}', '${examType}', '${productLine}', '${isReading ? 'R' : 'L'}', ${questionCounter + 1}, ${esc(groupType)}, '${section}',
          ${esc(qText)}, ${escJson({ options, accepted_answers: acceptedAnswers, word_bank: wordBank, word_limit: wordLimit })},
          ${esc(answer)}, NULL, ${esc(cefrLevel)},
          ${escArray([groupType.replace(/-/g, '_')])},
          ${escJson({ group_order: group.group_order, instructions: group.instructions, sequential_order: group.sequential_order, passage_title: containerTitle })}
          ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
        await execSQL(sql);
        questionCounter++;
      }
    }
  }
}

// ============================================================
// IMPORT: TOEIC Listening/Reading packages
// ============================================================

async function importTOEICLR() {
  console.log('\n=== Importing TOEIC Listening/Reading packages ===');
  if (!fs.existsSync(TOEIC_LR_DIR)) { console.log(`  TOEIC LR dir not found: ${TOEIC_LR_DIR}`); return; }
  const packages = fs.readdirSync(TOEIC_LR_DIR).filter(d => d.startsWith('package_'));
  for (const pkgDir of packages) {
    const pkgPath = path.join(TOEIC_LR_DIR, pkgDir);
    const manifestPath = path.join(pkgPath, 'manifest.json');
    if (!fs.existsSync(manifestPath)) continue;
    console.log(`  Importing ${pkgDir}...`);
    try {
      await importTOEICLRPackage(pkgPath, pkgDir);
    } catch (e) {
      console.log(`    ERROR: ${e.message}`);
    }
  }
}

async function importTOEICLRPackage(pkgPath, pkgDir) {
  const manifest = JSON.parse(fs.readFileSync(path.join(pkgPath, 'manifest.json'), 'utf8'));
  const pkgNum = manifest.package || pkgDir.replace('package_', '');
  const packageCode = `TOEIC-LR-${String(pkgNum).padStart(2, '0')}`;
  const cefr = manifest.target_cefr || 'C2';

  // Insert package
  const pkgSql = `INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata)
    VALUES (${esc(packageCode)}, 'TOEIC', 'listening_reading', ${esc(cefr)}, 'ai_generated_minimax', true,
    ${escJson({ package: pkgNum, counts: manifest.counts, generated_at: manifest.generated_at })}
    ) ON CONFLICT (package_code) DO NOTHING RETURNING id;`;

  const pkgResult = await execSQL(pkgSql);
  let packageId;
  try { const p = JSON.parse(pkgResult); if (p.length > 0) packageId = p[0].id; } catch (_) {}
  if (!packageId) {
    const fetchSql = `SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)};`;
    const r = await execSQL(fetchSql);
    try { const p = JSON.parse(r); if (p.length > 0) packageId = p[0].id; } catch (_) {}
  }
  if (!packageId) { console.log(`    Could not get package ID for ${packageCode}`); return; }
  packageCounter++;
  console.log(`    Package: ${packageCode} (${manifest.counts?.total || '?'} questions)`);

  // Import each part
  for (let part = 1; part <= 7; part++) {
    const partFile = path.join(pkgPath, `part${part}.json`);
    if (!fs.existsSync(partFile)) continue;
    const partData = JSON.parse(fs.readFileSync(partFile, 'utf8'));
    await importTOEICPart(partData, part, packageId, cefr, pkgPath);
  }
}

async function importTOEICPart(partData, part, packageId, cefr, pkgPath) {
  const section = part <= 4 ? 'listening' : 'reading';

  // Parts 1, 2, 5: items array
  if (part === 1 || part === 2 || part === 5) {
    const items = partData.items || [];
    for (const item of items) {
      const itemId = item.item_id || `${part}_${questionCounter}`;
      const qText = part === 5 ? (item.sentence || '') : (item.prompt_text || item.title || item.audio_script || '');
      const options = item.options || {};
      const correctAnswer = item.correct_answer || '';
      const explanation = item.explanation || '';
      const audioFile = item.audio_file || null;
      const imageFile = item.image_file || null;

      // Insert audio asset if exists
      let assetId = null;
      if (audioFile) {
        const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, transcript, metadata)
          VALUES ('${packageId}', 'audio', '${part}', ${esc(item.title || itemId)}, ${esc(audioFile)},
          ${esc(typeof item.audio_script === 'string' ? item.audio_script : JSON.stringify(item.audio_script || {}))},
          ${escJson({ audio_file: audioFile })}
          ) RETURNING id;`;
        try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
      }
      // Insert image asset if exists
      if (imageFile) {
        const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, metadata)
          VALUES ('${packageId}', 'image', '${part}', ${esc(item.title || itemId)}, ${esc(imageFile)},
          ${escJson({ image_file: imageFile, photo_description: item.photo_description })}
          ) RETURNING id;`;
        try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
      }

      const qType = part === 1 ? 'photo_description' : part === 2 ? 'question_response' : 'incomplete_sentence';
      const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, options, correct_answer, explanation, cefr_level, skill_tags, metadata)
        VALUES ('${packageId}', 'TOEIC', 'listening_reading', '${part}', ${questionCounter + 1}, '${qType}', '${section}',
        ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)}, ${escJson(options)}, ${esc(correctAnswer)},
        ${esc(explanation)}, ${esc(cefr)}, ${escArray([qType])},
        ${escJson({ item_id: itemId, grammar_focus: item.grammar_focus, audio_file: audioFile, image_file: imageFile })}
        ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
      await execSQL(sql);
      questionCounter++;
    }
  }

  // Parts 3, 4: sets array with questions
  if (part === 3 || part === 4) {
    const sets = partData.sets || [];
    for (const set of sets) {
      const setTitle = set.title || `Set ${set.set_id}`;
      const context = set.context || '';
      const audioFile = set.audio_file || null;
      const audioScript = set.audio_script || '';

      // Insert audio asset
      let assetId = null;
      if (audioFile) {
        const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, transcript, context, metadata)
          VALUES ('${packageId}', 'audio', '${part}', ${esc(setTitle)}, ${esc(audioFile)}, ${esc(audioScript)}, ${esc(context)},
          ${escJson({ audio_file: audioFile, set_id: set.set_id })}
          ) RETURNING id;`;
        try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
      }

      for (const q of (set.questions || [])) {
        const qText = q.question_text || q.question || '';
        const options = q.options || {};
        const correctAnswer = q.correct_answer || '';
        const explanation = q.explanation || '';
        const qType = part === 3 ? 'conversation' : 'talk';
        const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, options, correct_answer, explanation, cefr_level, skill_tags, metadata)
          VALUES ('${packageId}', 'TOEIC', 'listening_reading', '${part}', ${questionCounter + 1}, '${qType}', '${section}',
          ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)}, ${escJson(options)}, ${esc(correctAnswer)},
          ${esc(explanation)}, ${esc(cefr)}, ${escArray([qType])},
          ${escJson({ set_id: set.set_id, set_title: setTitle, audio_file: audioFile })}
          ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
        await execSQL(sql);
        questionCounter++;
      }
    }
  }

  // Part 6: sets with blanks
  if (part === 6) {
    const sets = partData.sets || [];
    for (const set of sets) {
      const setTitle = set.title || `Set ${set.set_id}`;
      const passage = set.passage_with_blanks || '';
      // Insert passage as asset
      let assetId = null;
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, context, metadata)
        VALUES ('${packageId}', 'passage', '${part}', ${esc(setTitle)}, ${esc(passage)},
        ${escJson({ set_id: set.set_id, text_type: set.text_type })}
        ) RETURNING id;`;
      try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}

      for (const q of (set.questions || [])) {
        const qText = q.question_text || '';
        const options = q.options || {};
        const correctAnswer = q.correct_answer || '';
        const explanation = q.explanation || '';
        const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, options, correct_answer, explanation, cefr_level, skill_tags, blanks_json, metadata)
          VALUES ('${packageId}', 'TOEIC', 'listening_reading', '${part}', ${questionCounter + 1}, 'text_completion', 'reading',
          ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)}, ${escJson(options)}, ${esc(correctAnswer)},
          ${esc(explanation)}, ${esc(cefr)}, ${escArray(['text_completion'])},
          ${escJson({ blank_number: q.blank_number })},
          ${escJson({ set_id: set.set_id, set_title: setTitle, text_type: set.text_type })}
          ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
        await execSQL(sql);
        questionCounter++;
      }
    }
  }

  // Part 7: single_sets and double_sets
  if (part === 7) {
    const allSets = [...(partData.single_sets || []), ...(partData.double_sets || [])];
    for (const set of allSets) {
      const setTitle = set.title || `Set ${set.set_id}`;
      const passage = set.passage_1 || set.passage || '';
      const passage2 = set.passage_2 || null;

      // Insert passage as asset
      let assetId = null;
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, context, secondary_text, text_type, metadata)
        VALUES ('${packageId}', 'passage', '${part}', ${esc(setTitle)}, ${esc(passage)}, ${esc(passage2)},
        ${esc(set.text_type || 'single')},
        ${escJson({ set_id: set.set_id, is_double: !!passage2 })}
        ) RETURNING id;`;
      try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}

      for (const q of (set.questions || [])) {
        const qText = q.question_text || q.question || '';
        const options = q.options || [];
        const correctAnswer = q.correct_answer || (q.correct_index !== undefined ? String.fromCharCode(65 + q.correct_index) : '') || q.correct_option || '';
        const explanation = q.explanation || '';
        // Normalize options: could be array or object
        let normalizedOptions = options;
        if (Array.isArray(options) && options.length > 0 && typeof options[0] === 'string') {
          normalizedOptions = {};
          options.forEach((val, idx) => { normalizedOptions[String.fromCharCode(65 + idx)] = val; });
        }
        const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, options, correct_answer, explanation, cefr_level, skill_tags, metadata)
          VALUES ('${packageId}', 'TOEIC', 'listening_reading', '${part}', ${questionCounter + 1}, 'reading_comprehension', 'reading',
          ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)}, ${escJson(normalizedOptions)}, ${esc(correctAnswer)},
          ${esc(explanation)}, ${esc(cefr)}, ${escArray(['reading_comprehension'])},
          ${escJson({ set_id: set.set_id, set_title: setTitle, text_type: set.text_type, question_id: q.question_id || q.question_number })}
          ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
        await execSQL(sql);
        questionCounter++;
      }
    }
  }
}

// ============================================================
// IMPORT: TOEIC Speaking/Writing packages
// ============================================================

async function importTOEICSW() {
  console.log('\n=== Importing TOEIC Speaking/Writing packages ===');
  if (!fs.existsSync(TOEIC_SW_DIR)) { console.log(`  TOEIC SW dir not found: ${TOEIC_SW_DIR}`); return; }
  const packages = fs.readdirSync(TOEIC_SW_DIR).filter(d => d.startsWith('package_'));
  for (const pkgDir of packages) {
    const manifestPath = path.join(TOEIC_SW_DIR, pkgDir, 'manifest.json');
    if (!fs.existsSync(manifestPath)) continue;
    console.log(`  Importing ${pkgDir}...`);
    try {
      const data = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      await importTOEICSWPackage(data, pkgDir);
    } catch (e) {
      console.log(`    ERROR: ${e.message}`);
    }
  }
}

async function importTOEICSWPackage(data, pkgDir) {
  const packageCode = data.package_code || `TOEIC-SW-${pkgDir.replace('package_', '')}`;
  const cefr = 'C2';

  // Insert package
  const pkgSql = `INSERT INTO material_packages (package_code, exam_type, product_line, target_cefr, source, is_published, metadata)
    VALUES (${esc(packageCode)}, 'TOEIC', 'speaking_writing', ${esc(cefr)}, 'ai_generated_minimax', true,
    ${escJson({ format: data.format, package_number: data.package_number, source_note: data.source_note })}
    ) ON CONFLICT (package_code) DO NOTHING RETURNING id;`;

  const pkgResult = await execSQL(pkgSql);
  let packageId;
  try { const p = JSON.parse(pkgResult); if (p.length > 0) packageId = p[0].id; } catch (_) {}
  if (!packageId) {
    const fetchSql = `SELECT id FROM material_packages WHERE package_code = ${esc(packageCode)};`;
    const r = await execSQL(fetchSql);
    try { const p = JSON.parse(r); if (p.length > 0) packageId = p[0].id; } catch (_) {}
  }
  if (!packageId) { console.log(`    Could not get package ID for ${packageCode}`); return; }
  packageCounter++;
  console.log(`    Package: ${packageCode} (${(data.speaking || []).length} speaking + ${(data.writing || []).length} writing)`);

  // Import speaking items
  for (const item of (data.speaking || [])) {
    const qNum = item.question_number || 0;
    const qType = item.type || 'speaking';
    const qText = item.prompt_text || '';
    const section = 'speaking';
    const part = `S${qNum}`;

    // Handle stimulus assets
    let assetId = null;
    if (item.audio_path) {
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, transcript, metadata)
        VALUES ('${packageId}', 'audio', '${part}', ${esc(item.title || `Q${qNum}`)}, ${esc(item.audio_path)},
        ${esc(item.audio_transcript || item.audio_script || '')},
        ${escJson({ audio_provider: item.audio_provider, audio_model: item.audio_model })}
        ) RETURNING id;`;
      try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
    }
    if (item.image_path) {
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, metadata)
        VALUES ('${packageId}', 'image', '${part}', ${esc(item.title || `Q${qNum}`)}, ${esc(item.image_path)},
        ${escJson({ image_prompt: item.image_prompt, image_provider: item.image_provider, image_model: item.image_model })}
        ) RETURNING id;`;
      try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
    }

    const skillKey = qType.replace(/-/g, '_');
    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, scoring_rubric, sample_response, difficulty, cefr_level, skill_tags, metadata)
      VALUES ('${packageId}', 'TOEIC', 'speaking_writing', '${part}', ${questionCounter + 1}, ${esc(qType)}, '${section}',
      ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)},
      ${esc(item.scoring_rubric || '')}, ${esc(item.sample_response || '')},
      ${esc(item.difficulty || cefr)}, ${esc(item.cefr_level || cefr)},
      ${escArray([skillKey])},
      ${escJson({ question_number: qNum, title: item.title, information_card: item.information_card, stimulus_group_id: item.stimulus_group_id, audio_note: item.audio_note })}
      ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
    await execSQL(sql);
    questionCounter++;
  }

  // Import writing items
  for (const item of (data.writing || [])) {
    const qNum = item.question_number || 0;
    const qType = item.type || 'writing';
    const qText = item.prompt_text || '';
    const section = 'writing';
    const part = `W${qNum}`;

    let assetId = null;
    if (item.image_path) {
      const assetSql = `INSERT INTO material_assets (package_id, asset_type, part, title, storage_key, metadata)
        VALUES ('${packageId}', 'image', '${part}', ${esc(item.title || `W${qNum}`)}, ${esc(item.image_path)},
        ${escJson({ image_prompt: item.image_prompt, required_words: item.required_words_json })}
        ) RETURNING id;`;
      try { const r = await execSQL(assetSql); const p = JSON.parse(r); if (p.length > 0) { assetId = p[0].id; assetCounter++; } } catch (_) {}
    }

    const skillKey = qType.replace(/-/g, '_');
    const sql = `INSERT INTO exam_questions (package_id, exam_type, product_line, part, question_number, question_type, section, stimulus_asset_id, question_text, scoring_rubric, sample_response, difficulty, cefr_level, skill_tags, metadata)
      VALUES ('${packageId}', 'TOEIC', 'speaking_writing', '${part}', ${questionCounter + 1}, ${esc(qType)}, '${section}',
      ${assetId ? `'${assetId}'` : 'NULL'}, ${esc(qText)},
      ${esc(item.scoring_rubric || '')}, ${esc(item.sample_response || '')},
      ${esc(item.difficulty || cefr)}, ${esc(item.cefr_level || cefr)},
      ${escArray([skillKey])},
      ${escJson({ question_number: qNum, title: item.title, required_words_json: item.required_words_json })}
      ) ON CONFLICT (package_id, question_number) DO NOTHING;`;
    await execSQL(sql);
    questionCounter++;
  }
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log('=== Material Database Importer ===');
  console.log(`Time: ${new Date().toISOString()}`);
  console.log('');

  try {
    await importIELTS();
  } catch (e) { console.log(`IELTS import error: ${e.message}`); }

  try {
    await importTOEICLR();
  } catch (e) { console.log(`TOEIC LR import error: ${e.message}`); }

  try {
    await importTOEICSW();
  } catch (e) { console.log(`TOEIC SW import error: ${e.message}`); }

  console.log('\n=== Import Complete ===');
  console.log(`Packages: ${packageCounter}`);
  console.log(`Questions: ${questionCounter}`);
  console.log(`Assets: ${assetCounter}`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });