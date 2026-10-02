/**
 * rebuild_db_313.js
 * 
 * Rebuilds `quran_content.sqlite` from QUL Resource 313 (Taj Company 13-line layout).
 * Maps Resource 313 Page P (1..847) to Physical Page P + 1 (2..848).
 * Page 1 is the physical frontispiece / title page.
 */

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const crypto = require('crypto');

const PAGES_DIR = path.join(__dirname, 'temp', 'pages_313');
const META_DIR = path.join(__dirname, 'temp', 'meta');
const TRANS_DIR = path.join(__dirname, 'temp', 'translations');
const DB_OUTPUT_DIR = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Database');
const DB_PATH = path.join(DB_OUTPUT_DIR, 'quran_content.sqlite');
const SHA_PATH = path.join(DB_OUTPUT_DIR, 'quran_content.sqlite.sha256');

function parsePage(html, resourcePage) {
  const lineSplits = html.split('<div class="line-container"');
  const lines = [];

  for (let i = 1; i < lineSplits.length; i++) {
    const chunk = lineSplits[i];
    const isSurahName = chunk.includes('line--surah-name');
    const isBismillah = chunk.includes('line--bismillah');
    const isCenter = chunk.includes('line--center');

    let lineType = 'ayah_text';
    let surahHeader = null;

    if (isSurahName) {
      lineType = 'surah_name';
      const sMatch = chunk.match(/surah(\d{3})/);
      if (sMatch) surahHeader = parseInt(sMatch[1], 10);
    } else if (isBismillah) {
      lineType = 'bismillah';
    }

    const wordRegex = /data-location="([^"]+)"[^>]*>[\s\S]*?<a[^>]*>\s*([\s\S]*?)\s*<\/a>/g;
    const words = [];
    let wMatch;
    while ((wMatch = wordRegex.exec(chunk)) !== null) {
      const loc = wMatch[1];
      const text = wMatch[2].trim();
      const [s, a, w] = loc.split(':').map(Number);
      words.push({ surah: s, ayah: a, word: w, location: loc, text: text });
    }

    // Line 2 on Physical Page 2 (Resource Page 1) is Al-Fatihah 1:1, centered ayah_text
    const isCentered = isCenter || isBismillah || (resourcePage === 1 && i === 2);
    const lineText = isBismillah ? '﷽' : (isSurahName ? '' : words.map(w => w.text).join(' '));

    lines.push({
      line_number: i,
      line_type: lineType,
      surah_header: surahHeader,
      is_centered: isCentered ? 1 : 0,
      words: words,
      line_text: lineText
    });
  }

  while (lines.length < 13) {
    lines.push({
      line_number: lines.length + 1,
      line_type: 'ayah_text',
      surah_header: null,
      is_centered: 0,
      words: [],
      line_text: ''
    });
  }

  return lines;
}

function loadTranslationFile(filename) {
  const map = new Map();
  const content = fs.readFileSync(path.join(TRANS_DIR, filename), 'utf8');
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const parts = trimmed.split('|');
    if (parts.length >= 3) {
      const s = parseInt(parts[0], 10);
      const a = parseInt(parts[1], 10);
      const text = parts.slice(2).join('|').trim();
      map.set(`${s}:${a}`, text);
    }
  }
  return map;
}

async function main() {
  console.log('--- Rebuilding quran_content.sqlite with 848-page Taj Company layout ---');

  if (fs.existsSync(DB_PATH)) {
    fs.unlinkSync(DB_PATH);
  }

  const db = new sqlite3.Database(DB_PATH);
  const run = (sql, params = []) => new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) reject(err);
      else resolve(this);
    });
  });

  // 1. Create Schema
  console.log('Creating schema...');
  await run(`
    CREATE TABLE surahs (
      id INTEGER PRIMARY KEY,
      arabic_name TEXT NOT NULL,
      english_name TEXT NOT NULL,
      french_name TEXT NOT NULL,
      english_meaning TEXT NOT NULL,
      revelation_type TEXT NOT NULL,
      total_verses INTEGER NOT NULL,
      start_page INTEGER NOT NULL,
      juz_number INTEGER NOT NULL
    );
  `);

  await run(`
    CREATE TABLE ayahs (
      id INTEGER PRIMARY KEY,
      surah_id INTEGER NOT NULL,
      verse_number INTEGER NOT NULL,
      page_number INTEGER NOT NULL,
      juz_number INTEGER NOT NULL,
      hizb_quarter INTEGER NOT NULL,
      sajdah INTEGER DEFAULT 0,
      text_indopak TEXT NOT NULL,
      text_clean TEXT NOT NULL,
      FOREIGN KEY(surah_id) REFERENCES surahs(id)
    );
  `);

  await run(`
    CREATE TABLE mushaf_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      page_number INTEGER NOT NULL,
      line_number INTEGER NOT NULL,
      line_type TEXT NOT NULL,
      surah_id INTEGER,
      is_centered INTEGER DEFAULT 0,
      text_indopak TEXT,
      words_json TEXT
    );
  `);

  await run(`
    CREATE TABLE translations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ayah_id INTEGER NOT NULL,
      lang TEXT NOT NULL,
      author_code TEXT NOT NULL,
      text TEXT NOT NULL,
      FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
    );
  `);

  await run(`
    CREATE TABLE juzs (
      id INTEGER PRIMARY KEY,
      name_arabic TEXT NOT NULL,
      name_transliteration TEXT NOT NULL,
      start_surah_id INTEGER NOT NULL,
      start_verse_number INTEGER NOT NULL,
      start_page INTEGER NOT NULL,
      first_verse_id INTEGER NOT NULL,
      last_verse_id INTEGER NOT NULL,
      total_verses INTEGER NOT NULL
    );
  `);

  await run(`
    CREATE VIRTUAL TABLE search_index USING fts5(
      ayah_id UNINDEXED,
      surah_id UNINDEXED,
      verse_number UNINDEXED,
      page_number UNINDEXED,
      arabic_clean,
      translation_en_saheeh,
      translation_en_hilali,
      translation_fr_hamidullah,
      tokenize = 'unicode61 remove_diacritics 2'
    );
  `);

  // 2. Load Metadata
  console.log('Loading metadata and translations...');
  const chEn = JSON.parse(fs.readFileSync(path.join(META_DIR, 'chapters_en.json'), 'utf8'));
  const chFr = JSON.parse(fs.readFileSync(path.join(META_DIR, 'chapters_fr.json'), 'utf8'));
  const imlaeiList = JSON.parse(fs.readFileSync(path.join(META_DIR, 'imlaei_simple.json'), 'utf8'));
  const verseMetaList = JSON.parse(fs.readFileSync(path.join(META_DIR, 'verse_metadata.json'), 'utf8'));
  const juzsMeta = JSON.parse(fs.readFileSync(path.join(META_DIR, 'juzs.json'), 'utf8'));

  const imlaeiMap = new Map();
  imlaeiList.forEach(v => imlaeiMap.set(v.verse_key, v.text_imlaei_simple));

  const verseMetaMap = new Map();
  verseMetaList.forEach(v => {
    verseMetaMap.set(v.verse_key, {
      juzNumber: v.juz_number,
      hizbQuarter: v.rub_el_hizb_number || 1,
      sajdah: v.sajdah_number ? 1 : 0
    });
  });

  const saheehMap = loadTranslationFile('en.sahih.txt');
  const hilaliMap = loadTranslationFile('en.hilali.txt');
  const hamidullahMap = loadTranslationFile('fr.hamidullah.txt');

  // 3. Populate mushaf_lines & map verses to physical pages
  console.log('Populating mushaf_lines (Pages 1..848)...');
  const verseToPageMap = new Map();
  const verseToIndoPakWords = new Map();
  const surahStartPages = new Map();

  await run('BEGIN TRANSACTION');

  const insertLineStmt = db.prepare(`
    INSERT INTO mushaf_lines (page_number, line_number, line_type, surah_id, is_centered, text_indopak, words_json)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  // Page 1: Physical Frontispiece (13 empty lines)
  for (let l = 1; l <= 13; l++) {
    insertLineStmt.run(1, l, 'ayah_text', null, 0, '', '[]');
  }

  // Pages 2..848 from Resource 313 Pages 1..847
  for (let p = 1; p <= 847; p++) {
    const physPage = p + 1;
    const pageHtml = fs.readFileSync(path.join(PAGES_DIR, `page_${p}.html`), 'utf8');
    const lines = parsePage(pageHtml, p);

    for (const l of lines) {
      insertLineStmt.run(physPage, l.line_number, l.line_type, l.surah_header, l.is_centered, l.line_text, JSON.stringify(l.words));

      if (l.surah_header && !surahStartPages.has(l.surah_header)) {
        surahStartPages.set(l.surah_header, physPage);
      }

      for (const w of l.words) {
        const vKey = `${w.surah}:${w.ayah}`;
        if (!verseToPageMap.has(vKey)) {
          verseToPageMap.set(vKey, physPage);
        }
        if (!verseToIndoPakWords.has(vKey)) {
          verseToIndoPakWords.set(vKey, []);
        }
        verseToIndoPakWords.get(vKey).push(w.text);
      }
    }
  }

  await new Promise(res => insertLineStmt.finalize(res));
  await run('COMMIT');
  console.log('mushaf_lines populated (11,024 rows).');

  // 4. Populate Surahs
  console.log('Populating surahs table...');
  await run('BEGIN TRANSACTION');
  const insertSurahStmt = db.prepare(`
    INSERT INTO surahs (id, arabic_name, english_name, french_name, english_meaning, revelation_type, total_verses, start_page, juz_number)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  for (let i = 0; i < chEn.length; i++) {
    const en = chEn[i];
    const fr = chFr[i];
    const startPage = surahStartPages.get(en.id) || verseToPageMap.get(`${en.id}:1`) || 2;
    const startJuz = verseMetaMap.get(`${en.id}:1`)?.juzNumber || 1;
    insertSurahStmt.run(
      en.id,
      en.name_arabic,
      en.name_simple,
      fr.translated_name.name,
      en.translated_name.name,
      en.revelation_place === 'makkah' ? 'Meccan' : 'Medinan',
      en.verses_count,
      startPage,
      startJuz
    );
  }
  await new Promise(res => insertSurahStmt.finalize(res));
  await run('COMMIT');
  console.log('surahs populated (114 rows).');

  // 5. Populate Ayahs, Translations & FTS5
  console.log('Populating ayahs, translations, and FTS5 search index...');
  await run('BEGIN TRANSACTION');

  const insertAyahStmt = db.prepare(`
    INSERT INTO ayahs (id, surah_id, verse_number, page_number, juz_number, hizb_quarter, sajdah, text_indopak, text_clean)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const insertTransStmt = db.prepare(`
    INSERT INTO translations (ayah_id, lang, author_code, text)
    VALUES (?, ?, ?, ?)
  `);

  const insertFtsStmt = db.prepare(`
    INSERT INTO search_index (ayah_id, surah_id, verse_number, page_number, arabic_clean, translation_en_saheeh, translation_en_hilali, translation_fr_hamidullah)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  let globalAyahId = 0;
  for (const surah of chEn) {
    for (let v = 1; v <= surah.verses_count; v++) {
      globalAyahId++;
      const vKey = `${surah.id}:${v}`;
      const pageNumber = verseToPageMap.get(vKey) || 2;
      const cleanArabic = imlaeiMap.get(vKey) || '';
      const indoPakText = (verseToIndoPakWords.get(vKey) || []).join(' ');

      const tSaheeh = saheehMap.get(vKey) || '';
      const tHilali = hilaliMap.get(vKey) || '';
      const tHamidullah = hamidullahMap.get(vKey) || '';
      const vMeta = verseMetaMap.get(vKey) || { juzNumber: 1, hizbQuarter: 1, sajdah: 0 };

      insertAyahStmt.run(
        globalAyahId,
        surah.id,
        v,
        pageNumber,
        vMeta.juzNumber,
        vMeta.hizbQuarter,
        vMeta.sajdah,
        indoPakText,
        cleanArabic
      );

      insertTransStmt.run(globalAyahId, 'en', 'saheeh', tSaheeh);
      insertTransStmt.run(globalAyahId, 'en', 'hilali_khan', tHilali);
      insertTransStmt.run(globalAyahId, 'fr', 'hamidullah', tHamidullah);

      insertFtsStmt.run(
        globalAyahId,
        surah.id,
        v,
        pageNumber,
        cleanArabic,
        tSaheeh,
        tHilali,
        tHamidullah
      );
    }
  }

  await new Promise(res => insertAyahStmt.finalize(res));
  await new Promise(res => insertTransStmt.finalize(res));
  await new Promise(res => insertFtsStmt.finalize(res));
  await run('COMMIT');
  console.log('ayahs, translations, and search_index populated (6,236 verses).');

  // 6. Populate Juzs
  console.log('Populating juzs table...');
  const CANONICAL_JUZS = [
    { id: 1, name_arabic: 'الم', name_transliteration: 'Alif Lam Meem' },
    { id: 2, name_arabic: 'سَيَقُولُ', name_transliteration: 'Sayaqool' },
    { id: 3, name_arabic: 'تِلْكَ الرُّسُلُ', name_transliteration: 'Tilkar Rusul' },
    { id: 4, name_arabic: 'لَنْ تَنَالُوا', name_transliteration: 'Lan Tanaaloo' },
    { id: 5, name_arabic: 'وَالْمُحْصَنَاتُ', name_transliteration: 'Wal Mohsanat' },
    { id: 6, name_arabic: 'لَا يُحِبُّ اللَّهُ', name_transliteration: 'La Yuhibbullah' },
    { id: 7, name_arabic: 'وَإِذَا سَمِعُوا', name_transliteration: 'Wa Iza Sami\'oo' },
    { id: 8, name_arabic: 'وَلَوْ أَنَّنَا', name_transliteration: 'Wa Law Annana' },
    { id: 9, name_arabic: 'قَالَ الْمَلَأُ', name_transliteration: 'Qalal Mala\'o' },
    { id: 10, name_arabic: 'وَاعْلَمُوا', name_transliteration: 'Wa\'lamoo' },
    { id: 11, name_arabic: 'يَعْتَذِرُونَ', name_transliteration: 'Ya\'taziroon' },
    { id: 12, name_arabic: 'وَمَا مِنْ دَابَّةٍ', name_transliteration: 'Wa Mamin Da\'abbah' },
    { id: 13, name_arabic: 'وَمَا أُبَرِّئُ', name_transliteration: 'Wa Ma Obarri\'o' },
    { id: 14, name_arabic: 'رُبَمَا', name_transliteration: 'Rubama' },
    { id: 15, name_arabic: 'سُبْحَانَ الَّذِي', name_transliteration: 'Subhanallazi' },
    { id: 16, name_arabic: 'قَالَ أَلَمْ', name_transliteration: 'Qal Alam' },
    { id: 17, name_arabic: 'اقْتَرَبَ لِلنَّاسِ', name_transliteration: 'Iqtaraba Linnaas' },
    { id: 18, name_arabic: 'قَدْ أَفْلَحَ', name_transliteration: 'Qadd Aflaha' },
    { id: 19, name_arabic: 'وَقَالَ الَّذِينَ', name_transliteration: 'Wa Qalal Lazeena' },
    { id: 20, name_arabic: 'أَمَّنْ خَلَقَ', name_transliteration: 'Amman Khalaqa' },
    { id: 21, name_arabic: 'اتْلُ مَا أُوحِيَ', name_transliteration: 'Otlo Ma Oohiya' },
    { id: 22, name_arabic: 'وَمَنْ يَقْنُتْ', name_transliteration: 'Wa Manyaqnut' },
    { id: 23, name_arabic: 'وَمَا لِيَ', name_transliteration: 'Wa Maliya' },
    { id: 24, name_arabic: 'فَمَنْ أَظْلَمُ', name_transliteration: 'Faman Azlamo' },
    { id: 25, name_arabic: 'إِلَيْهِ يُرَدُّ', name_transliteration: 'Elahe Yuraddo' },
    { id: 26, name_arabic: 'حـم', name_transliteration: 'Ha-Meem' },
    { id: 27, name_arabic: 'قَالَ فَمَا خَطْبُكُمْ', name_transliteration: 'Qala Fama Khatbukum' },
    { id: 28, name_arabic: 'قَدْ سَمِعَ اللَّهُ', name_transliteration: 'Qadd Sami Allah' },
    { id: 29, name_arabic: 'تَبَارَكَ الَّذِي', name_transliteration: 'Tabarakallazi' },
    { id: 30, name_arabic: 'عَمَّ يَتَسَاءَلُونَ', name_transliteration: '\'Amma Yatasa\'aloon' }
  ];

  await run('BEGIN TRANSACTION');
  const insertJuzStmt = db.prepare(`
    INSERT INTO juzs (id, name_arabic, name_transliteration, start_surah_id, start_verse_number, start_page, first_verse_id, last_verse_id, total_verses)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  for (const cj of CANONICAL_JUZS) {
    const jData = juzsMeta.find(j => j.juz_number === cj.id);
    if (jData) {
      const surahKeys = Object.keys(jData.verse_mapping).map(k => parseInt(k, 10)).sort((a, b) => a - b);
      const startSurah = surahKeys[0];
      const startVerse = parseInt(jData.verse_mapping[startSurah].split('-')[0], 10);
      const startPage = verseToPageMap.get(`${startSurah}:${startVerse}`) || 2;

      insertJuzStmt.run(
        cj.id,
        cj.name_arabic,
        cj.name_transliteration,
        startSurah,
        startVerse,
        startPage,
        jData.first_verse_id,
        jData.last_verse_id,
        jData.verses_count
      );
    }
  }
  await new Promise(res => insertJuzStmt.finalize(res));
  await run('COMMIT');
  console.log('juzs table populated (30 rows).');

  // 7. Create Indexes
  console.log('Creating database indexes...');
  await run('CREATE INDEX idx_ayahs_surah_verse ON ayahs(surah_id, verse_number);');
  await run('CREATE INDEX idx_ayahs_page ON ayahs(page_number);');
  await run('CREATE INDEX idx_ayahs_juz ON ayahs(juz_number);');
  await run('CREATE INDEX idx_mushaf_lines_page ON mushaf_lines(page_number, line_number);');
  await run('CREATE INDEX idx_translations_ayah ON translations(ayah_id, author_code);');
  await run('CREATE INDEX idx_juzs_start_page ON juzs(start_page);');

  await new Promise(res => db.close(res));
  console.log('Database successfully compiled and closed.');

  // 8. Compute and write SHA-256
  const fileBuffer = fs.readFileSync(DB_PATH);
  const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
  fs.writeFileSync(SHA_PATH, hash, 'utf8');

  console.log('--------------------------------------------------');
  console.log(`Database generated at: ${DB_PATH}`);
  console.log(`File size: ${(fileBuffer.length / (1024 * 1024)).toFixed(2)} MB`);
  console.log(`SHA-256: ${hash}`);
  console.log('--------------------------------------------------');
}

main().catch(err => {
  console.error('Database rebuild failed:', err);
  process.exit(1);
});
