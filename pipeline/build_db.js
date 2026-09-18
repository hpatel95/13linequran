/**
 * build_db.js
 * 
 * High-performance, resumable pipeline to build `quran_content.sqlite`
 * Sources:
 * - 13-line Mushaf Layout (849 pages) & IndoPak text: QUL (Quranic Universal Library)
 * - Translations:
 *     - English 1: Saheeh International (Tanzil en.sahih)
 *     - English 2: Dr. Hilali & Dr. Muhsin Khan (Tanzil en.hilali)
 *     - French: Dr. Muhammad Hamidullah (Tanzil fr.hamidullah)
 * - Normalized Arabic Search Text: Quran.com API (Imlaei Simple 6,236 verses)
 * - Chapters & Juz Metadata: Quran.com API
 */

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const axios = require('axios');

const PAGES_DIR = path.join(__dirname, 'temp', 'pages');
const META_DIR = path.join(__dirname, 'temp', 'meta');
const TRANS_DIR = path.join(__dirname, 'temp', 'translations');
const DB_OUTPUT_DIR = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Database');
const DB_PATH = path.join(DB_OUTPUT_DIR, 'quran_content.sqlite');
const SHA_PATH = path.join(DB_OUTPUT_DIR, 'quran_content.sqlite.sha256');

// Ensure working directories exist
[PAGES_DIR, META_DIR, TRANS_DIR, DB_OUTPUT_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// Helper for sleep
const sleep = ms => new Promise(r => setTimeout(r, ms));

// --- 1. DOWNLOAD TRANSLATIONS ---
async function downloadTranslations() {
  console.log('--- Step 1: Ingesting Translations ---');
  const sources = [
    { name: 'en.sahih.txt', url: 'https://tanzil.net/trans/en.sahih' },
    { name: 'en.hilali.txt', url: 'https://tanzil.net/trans/en.hilali' },
    { name: 'fr.hamidullah.txt', url: 'https://tanzil.net/trans/fr.hamidullah' }
  ];

  for (const s of sources) {
    const dest = path.join(TRANS_DIR, s.name);
    if (!fs.existsSync(dest) || fs.statSync(dest).size < 1000) {
      console.log(`Downloading ${s.name}...`);
      const res = await axios.get(s.url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      fs.writeFileSync(dest, res.data, 'utf8');
    } else {
      console.log(`[CACHED] ${s.name} (${fs.statSync(dest).size} bytes)`);
    }
  }
}

// --- 2. DOWNLOAD CHAPTERS & JUZ & CLEAN ARABIC ---
async function downloadMetadata() {
  console.log('--- Step 2: Ingesting Surahs, Juz & Clean Arabic ---');

  // Chapters English
  const chEnPath = path.join(META_DIR, 'chapters_en.json');
  if (!fs.existsSync(chEnPath)) {
    console.log('Downloading English chapters...');
    const res = await axios.get('https://api.quran.com/api/v4/chapters?language=en');
    fs.writeFileSync(chEnPath, JSON.stringify(res.data.chapters, null, 2));
  }

  // Chapters French
  const chFrPath = path.join(META_DIR, 'chapters_fr.json');
  if (!fs.existsSync(chFrPath)) {
    console.log('Downloading French chapters...');
    const res = await axios.get('https://api.quran.com/api/v4/chapters?language=fr');
    fs.writeFileSync(chFrPath, JSON.stringify(res.data.chapters, null, 2));
  }

  // Juzs
  const juzPath = path.join(META_DIR, 'juzs.json');
  if (!fs.existsSync(juzPath)) {
    console.log('Downloading Juz metadata...');
    const res = await axios.get('https://api.quran.com/api/v4/juzs');
    fs.writeFileSync(juzPath, JSON.stringify(res.data.juzs, null, 2));
  }

  // Imlaei Simple (diacritic-free normalized Arabic for search)
  const imlaeiPath = path.join(META_DIR, 'imlaei_simple.json');
  if (!fs.existsSync(imlaeiPath)) {
    console.log('Downloading Imlaei clean Arabic text...');
    const res = await axios.get('https://api.quran.com/api/v4/quran/verses/imlaei_simple');
    fs.writeFileSync(imlaeiPath, JSON.stringify(res.data.verses, null, 2));
  }

  // Verse-level metadata: juz_number, rub_el_hizb_number, sajdah_number for all 114 surahs
  const verseMetaPath = path.join(META_DIR, 'verse_metadata.json');
  if (!fs.existsSync(verseMetaPath)) {
    console.log('Downloading verse-level metadata (juz, hizb, sajdah) for all 114 surahs...');
    const allVerses = [];
    const CONCURRENCY = 10;
    for (let s = 1; s <= 114; s += CONCURRENCY) {
      const chunk = [];
      for (let c = s; c < s + CONCURRENCY && c <= 114; c++) {
        chunk.push(c);
      }
      const results = await Promise.all(chunk.map(async (surahId) => {
        let retries = 3;
        while (retries > 0) {
          try {
            const res = await axios.get(`https://api.quran.com/api/v4/verses/by_chapter/${surahId}?language=en&fields=verse_key,juz_number,rub_el_hizb_number,sajdah_number&per_page=300`, { timeout: 15000 });
            return res.data.verses;
          } catch (e) {
            retries--;
            if (retries === 0) throw e;
            await sleep(500);
          }
        }
      }));
      results.forEach(verses => allVerses.push(...verses));
      console.log(`Fetched verse metadata for surahs ${s}..${Math.min(s + CONCURRENCY - 1, 114)} (verses: ${allVerses.length}/6236)`);
    }
    fs.writeFileSync(verseMetaPath, JSON.stringify(allVerses, null, 2));
  }

  console.log('Metadata ready.');
}

// --- 3. DOWNLOAD ALL 849 13-LINE MUSHAF PAGES ---
async function downloadPages() {
  console.log('--- Step 3: Ingesting 849 13-Line Mushaf Layout Pages ---');
  const TOTAL_PAGES = 849;
  const missingPages = [];

  for (let p = 1; p <= TOTAL_PAGES; p++) {
    const pageFile = path.join(PAGES_DIR, `page_${p}.html`);
    if (!fs.existsSync(pageFile) || fs.statSync(pageFile).size < 1000) {
      missingPages.push(p);
    }
  }

  console.log(`Pages cached: ${TOTAL_PAGES - missingPages.length}/${TOTAL_PAGES}. Need to fetch: ${missingPages.length}`);

  const CONCURRENCY = 15;
  for (let i = 0; i < missingPages.length; i += CONCURRENCY) {
    const chunk = missingPages.slice(i, i + CONCURRENCY);
    await Promise.all(chunk.map(async (pageNum) => {
      let retries = 3;
      while (retries > 0) {
        try {
          const res = await axios.get(`https://qul.tarteel.ai/resources/mushaf-layout/236?page=${pageNum}`, {
            timeout: 10000,
            headers: { 'User-Agent': 'Mozilla/5.0' }
          });
          fs.writeFileSync(path.join(PAGES_DIR, `page_${pageNum}.html`), res.data, 'utf8');
          break;
        } catch (err) {
          retries--;
          if (retries === 0) console.error(`Failed page ${pageNum}: ${err.message}`);
          await sleep(500);
        }
      }
    }));

    process.stdout.write(`\rProgress: ${Math.min(i + CONCURRENCY, missingPages.length)}/${missingPages.length} downloaded`);
  }
  console.log('\nAll 849 layout pages downloaded.');
}

// --- 4. PARSE PAGE HTML ---
function parsePage(html, pageNumber) {
  const turboMatch = html.match(new RegExp(`<turbo-frame id="page_${pageNumber}_mushaf_17">([\\s\\S]*?)</turbo-frame>`));
  if (!turboMatch) return [];

  const content = turboMatch[1];
  const lineSplits = content.split('<div class="line-container"');
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

    const lineText = isBismillah ? '﷽' : words.map(w => w.text).join(' ');

    lines.push({
      line_number: i,
      line_type: lineType,
      surah_header: surahHeader,
      is_centered: isCenter || isBismillah ? 1 : 0,
      words: words,
      line_text: lineText
    });
  }

  return lines;
}

// --- 5. BUILD SQLITE DATABASE ---
async function buildDatabase() {
  console.log('--- Step 4: Compiling quran_content.sqlite ---');

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

  // Create Schema
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

  console.log('Schema created.');

  // Load Metadata
  const chEn = JSON.parse(fs.readFileSync(path.join(META_DIR, 'chapters_en.json'), 'utf8'));
  const chFr = JSON.parse(fs.readFileSync(path.join(META_DIR, 'chapters_fr.json'), 'utf8'));
  const imlaeiList = JSON.parse(fs.readFileSync(path.join(META_DIR, 'imlaei_simple.json'), 'utf8'));
  const verseMetaList = JSON.parse(fs.readFileSync(path.join(META_DIR, 'verse_metadata.json'), 'utf8'));

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

  // Parse Translations
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

  const saheehMap = loadTranslationFile('en.sahih.txt');
  const hilaliMap = loadTranslationFile('en.hilali.txt');
  const hamidullahMap = loadTranslationFile('fr.hamidullah.txt');

  console.log('Translations parsed in memory.');

  // Parse all 849 pages to build line layout and map verses to pages
  console.log('Parsing 849 mushaf pages...');
  const verseToPageMap = new Map();
  const verseToIndoPakWords = new Map(); // "s:a" -> array of word texts
  const surahStartPages = new Map();

  await run('BEGIN TRANSACTION');

  const insertLineStmt = db.prepare(`
    INSERT INTO mushaf_lines (page_number, line_number, line_type, surah_id, is_centered, text_indopak, words_json)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  for (let p = 1; p <= 849; p++) {
    const pageHtml = fs.readFileSync(path.join(PAGES_DIR, `page_${p}.html`), 'utf8');
    const lines = parsePage(pageHtml, p);

    for (const l of lines) {
      insertLineStmt.run(p, l.line_number, l.line_type, l.surah_header, l.is_centered, l.line_text, JSON.stringify(l.words));

      if (l.surah_header && !surahStartPages.has(l.surah_header)) {
        surahStartPages.set(l.surah_header, p);
      }

      for (const w of l.words) {
        const vKey = `${w.surah}:${w.ayah}`;
        if (!verseToPageMap.has(vKey)) {
          verseToPageMap.set(vKey, p);
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
  console.log('mushaf_lines table populated.');

  // Populate Surahs
  await run('BEGIN TRANSACTION');
  const insertSurahStmt = db.prepare(`
    INSERT INTO surahs (id, arabic_name, english_name, french_name, english_meaning, revelation_type, total_verses, start_page, juz_number)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  for (let i = 0; i < chEn.length; i++) {
    const en = chEn[i];
    const fr = chFr[i];
    const startPage = surahStartPages.get(en.id) || 1;
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
  console.log('surahs table populated.');

  // Populate Ayahs, Translations & FTS5
  console.log('Populating ayahs, translations, and search index...');
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
      const pageNumber = verseToPageMap.get(vKey) || 1;
      const cleanArabic = imlaeiMap.get(vKey) || '';
      const indoPakText = (verseToIndoPakWords.get(vKey) || []).join(' ');

      const tSaheeh = saheehMap.get(vKey) || '';
      const tHilali = hilaliMap.get(vKey) || '';
      const tHamidullah = hamidullahMap.get(vKey) || '';
      const vMeta = verseMetaMap.get(vKey) || { juzNumber: 1, hizbQuarter: 1, sajdah: 0 };

      // Ayah record
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

      // Translations
      insertTransStmt.run(globalAyahId, 'en', 'saheeh', tSaheeh);
      insertTransStmt.run(globalAyahId, 'en', 'hilali_khan', tHilali);
      insertTransStmt.run(globalAyahId, 'fr', 'hamidullah', tHamidullah);

      // FTS5 Virtual Index with page_number
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

  // Populate Juzs table
  console.log('Populating juzs table...');
  const juzsMeta = JSON.parse(fs.readFileSync(path.join(META_DIR, 'juzs.json'), 'utf8'));
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
      const startPage = verseToPageMap.get(`${startSurah}:${startVerse}`) || 1;

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
  console.log('juzs table populated.');

  // Create fast lookup indexes
  console.log('Creating database indexes...');
  await run('CREATE INDEX idx_ayahs_surah_verse ON ayahs(surah_id, verse_number);');
  await run('CREATE INDEX idx_ayahs_page ON ayahs(page_number);');
  await run('CREATE INDEX idx_ayahs_juz ON ayahs(juz_number);');
  await run('CREATE INDEX idx_mushaf_lines_page ON mushaf_lines(page_number, line_number);');
  await run('CREATE INDEX idx_translations_ayah ON translations(ayah_id, author_code);');
  await run('CREATE INDEX idx_juzs_start_page ON juzs(start_page);');

  await new Promise(res => db.close(res));
  console.log('Database successfully compiled and closed.');

  // Compute SHA-256
  const crypto = require('crypto');
  const fileBuffer = fs.readFileSync(DB_PATH);
  const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
  fs.writeFileSync(SHA_PATH, hash, 'utf8');

  console.log('--------------------------------------------------');
  console.log(`Database generated at: ${DB_PATH}`);
  console.log(`File size: ${(fileBuffer.length / (1024 * 1024)).toFixed(2)} MB`);
  console.log(`SHA-256: ${hash}`);
  console.log('--------------------------------------------------');
}

// --- MAIN RUNNER ---
async function main() {
  const start = Date.now();
  console.log('Starting Phase 0 Data Pipeline...');
  await downloadTranslations();
  await downloadMetadata();
  await downloadPages();
  await buildDatabase();
  console.log(`Pipeline complete in ${((Date.now() - start) / 1000).toFixed(1)}s!`);
}

main().catch(err => {
  console.error('Pipeline failed with error:', err);
  process.exit(1);
});
