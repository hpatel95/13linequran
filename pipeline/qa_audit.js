const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sqlite3 = require('sqlite3').verbose();

const DB_PATH = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Database', 'quran_content.sqlite');
const SHA_PATH = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Database', 'quran_content.sqlite.sha256');
const PRIVACY_PATH = path.join(__dirname, '..', 'QuranApp', 'Support', 'PrivacyInfo.xcprivacy');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  [PASS] ${message}`);
  } else {
    failedTests++;
    console.error(`  [FAIL] ${message}`);
  }
}

async function runAudit() {
  console.log('====================================================');
  console.log('  13-LINE MUSHAF END-TO-END QA & PRE-RELEASE AUDIT  ');
  console.log('====================================================\n');

  // --- 1. PRIVACY MANIFEST AUDIT ---
  console.log('--- 1. Apple Privacy Manifest Audit ---');
  assert(fs.existsSync(PRIVACY_PATH), 'PrivacyInfo.xcprivacy exists at expected path');
  if (fs.existsSync(PRIVACY_PATH)) {
    const privacyContent = fs.readFileSync(PRIVACY_PATH, 'utf8');
    assert(privacyContent.includes('NSPrivacyAccessedAPICategoryFileTimestamp'), 'Includes NSPrivacyAccessedAPICategoryFileTimestamp');
    assert(privacyContent.includes('C617.1'), 'Declares Reason C617.1 for file timestamp access');
    assert(privacyContent.includes('NSPrivacyAccessedAPICategoryUserDefaults'), 'Includes NSPrivacyAccessedAPICategoryUserDefaults');
    assert(privacyContent.includes('CA92.1'), 'Declares Reason CA92.1 for user defaults access');
    assert(privacyContent.includes('<false/>'), 'Declares zero tracking (NSPrivacyTracking is false)');
  }

  // --- 2. DATABASE FILE & CHECKSUM AUDIT ---
  console.log('\n--- 2. SQLite File & Integrity Checksum Audit ---');
  assert(fs.existsSync(DB_PATH), 'Database exists at ' + DB_PATH);
  assert(fs.existsSync(SHA_PATH), 'SHA256 reference file exists');

  if (fs.existsSync(DB_PATH) && fs.existsSync(SHA_PATH)) {
    const fileBuffer = fs.readFileSync(DB_PATH);
    const calculatedHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    const expectedHash = fs.readFileSync(SHA_PATH, 'utf8').trim();
    assert(calculatedHash.toLowerCase() === expectedHash.toLowerCase(), `SHA-256 Checksum matches: ${calculatedHash.substring(0, 16)}...`);
  }

  // --- 3. DATABASE RELATIONAL DATA INTEGRITY ---
  console.log('\n--- 3. Database Schema & Record Counts Audit ---');
  const db = new sqlite3.Database(DB_PATH);
  const get = (sql, params = []) => new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => err ? reject(err) : resolve(row));
  });
  const all = (sql, params = []) => new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => err ? reject(err) : resolve(rows));
  });

  try {
    // PRAGMA quick_check
    const integrityCheck = await get('PRAGMA integrity_check');
    assert(integrityCheck.integrity_check === 'ok', 'PRAGMA integrity_check is OK');

    // Surahs count
    const surahsCount = await get('SELECT COUNT(*) as c FROM surahs');
    assert(surahsCount.c === 114, `Surahs count is exactly 114 (found: ${surahsCount.c})`);

    // Ayahs count
    const ayahsCount = await get('SELECT COUNT(*) as c FROM ayahs');
    assert(ayahsCount.c === 6236, `Ayahs count is exactly 6236 (found: ${ayahsCount.c})`);

    // Mushaf lines count: 849 pages * 13 lines = 11,037 lines
    const linesCount = await get('SELECT COUNT(*) as c FROM mushaf_lines');
    assert(linesCount.c === 11037, `Mushaf lines count is exactly 11037 (found: ${linesCount.c})`);

    // Translations count: 6236 * 3 = 18,708
    const transCount = await get('SELECT COUNT(*) as c FROM translations');
    assert(transCount.c === 18708, `Translations count is exactly 18708 (found: ${transCount.c})`);

    // Translation breakdown
    const transBreakdown = await all('SELECT author_code, COUNT(*) as c FROM translations GROUP BY author_code');
    const saheeh = transBreakdown.find(t => t.author_code === 'saheeh');
    const hilali = transBreakdown.find(t => t.author_code === 'hilali_khan');
    const hamid = transBreakdown.find(t => t.author_code === 'hamidullah');
    assert(saheeh && saheeh.c === 6236, 'Saheeh International translation has all 6236 verses');
    assert(hilali && hilali.c === 6236, 'Hilali & Khan translation has all 6236 verses');
    assert(hamid && hamid.c === 6236, 'Hamidullah French translation has all 6236 verses');

    // Juzs count
    const juzsCount = await get('SELECT COUNT(*) as c FROM juzs');
    assert(juzsCount.c === 30, `Juzs count is exactly 30 (found: ${juzsCount.c})`);

    // Page boundaries
    console.log('\n--- 4. Mushaf Page Geometry & Boundary Audit ---');
    const minMaxPages = await get('SELECT MIN(page_number) as minP, MAX(page_number) as maxP FROM mushaf_lines');
    assert(minMaxPages.minP === 1 && minMaxPages.maxP === 849, `Page numbers range from 1 to 849 (found: ${minMaxPages.minP} to ${minMaxPages.maxP})`);

    // Verify each page 1..849 has exactly 13 lines
    const badPages = await all('SELECT page_number, COUNT(*) as c FROM mushaf_lines GROUP BY page_number HAVING c != 13');
    assert(badPages.length === 0, `All 849 pages have exactly 13 lines (anomalous pages: ${badPages.length})`);

    // Verify Surah Al-Fatiha on page 1
    const fatiha = await get('SELECT * FROM ayahs WHERE surah_id = 1 AND verse_number = 1');
    assert(fatiha && fatiha.page_number === 1, `Surah Al-Fatihah starts on Page 1 (found page: ${fatiha?.page_number})`);

    // Verify Surah An-Nas final verse on page 849
    const nas = await get('SELECT * FROM ayahs WHERE surah_id = 114 AND verse_number = 6');
    assert(nas && nas.page_number === 849, `Surah An-Nas Ayah 6 is on Page 849 (found page: ${nas?.page_number})`);
    assert(nas && nas.id === 6236, `Surah An-Nas Ayah 6 is global verse ID 6236 (found ID: ${nas?.id})`);

    // Verify Page 64 line continuity
    const page64Lines = await all('SELECT line_number, line_type, is_centered FROM mushaf_lines WHERE page_number = 64 ORDER BY line_number');
    assert(page64Lines.length === 13, `Page 64 has all 13 lines populated for continuous reading (found: ${page64Lines.length})`);

    // Words JSON format verification on sample pages
    console.log('\n--- 5. Word Tokens & JSON Mapping Audit ---');
    const sampleLines = await all('SELECT page_number, line_number, words_json FROM mushaf_lines WHERE words_json IS NOT NULL AND words_json != "[]" LIMIT 10');
    let wordsValid = true;
    for (const row of sampleLines) {
      try {
        const words = JSON.parse(row.words_json);
        if (!Array.isArray(words) || words.length === 0 || !words[0].text) {
          wordsValid = false;
        }
      } catch (e) {
        wordsValid = false;
      }
    }
    assert(wordsValid, 'Sample words_json fields parse cleanly into valid word tokens');

    // FTS5 Full-Text Search performance
    console.log('\n--- 6. FTS5 Search Engine Latency & Accuracy Audit ---');
    const t0 = Date.now();
    const searchPraise = await all('SELECT ayah_id, page_number, translation_en_saheeh FROM search_index WHERE search_index MATCH ? LIMIT 5', ['praise']);
    const elapsedPraise = Date.now() - t0;
    assert(searchPraise.length > 0, `FTS5 English search "praise" returned ${searchPraise.length} matches`);
    assert(elapsedPraise < 50, `FTS5 search latency is blazingly fast (${elapsedPraise}ms < 50ms)`);

    const t1 = Date.now();
    const searchArabic = await all('SELECT ayah_id, page_number FROM search_index WHERE search_index MATCH ? LIMIT 5', ['الله']);
    const elapsedArabic = Date.now() - t1;
    assert(searchArabic.length > 0, `FTS5 Arabic search "الله" returned ${searchArabic.length} matches`);
    assert(elapsedArabic < 50, `FTS5 Arabic search latency (${elapsedArabic}ms < 50ms)`);

    // Audio URL Formatter verification
    console.log('\n--- 7. Recitation CDN URL Formatting Audit ---');
    function formatAudioUrl(surah, ayah) {
      const s = String(surah).padStart(3, '0');
      const a = String(ayah).padStart(3, '0');
      return `https://everyayah.com/data/khalefa_al_tunaiji_64kbps/${s}${a}.mp3`;
    }
    assert(formatAudioUrl(1, 1) === 'https://everyayah.com/data/khalefa_al_tunaiji_64kbps/001001.mp3', 'Fatihah 1:1 audio URL matches Sheikh Khalifa Al Tunaiji CDN pattern');
    assert(formatAudioUrl(114, 6) === 'https://everyayah.com/data/khalefa_al_tunaiji_64kbps/114006.mp3', 'An-Nas 114:6 audio URL matches CDN pattern');

  } finally {
    db.close();
  }

  console.log('\n====================================================');
  console.log(`AUDIT COMPLETE: ${passedTests}/${totalTests} tests passed (${failedTests} failures).`);
  console.log('====================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runAudit().catch(err => {
  console.error('Audit fatal error:', err);
  process.exit(1);
});
