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

/**
 * Minimal TrueType cmap reader. Returns a code-point membership helper (or null)
 * so the audit can prove that the bundled calligraphy font really maps every
 * glyph used by the printed page text, including private-use verse ornaments.
 */
function readFontCmap(filePath) {
  try {
    const buf = fs.readFileSync(filePath);
    const numTables = buf.readUInt16BE(4);
    let cmapOffset = 0;
    for (let i = 0; i < numTables; i++) {
      const tag = buf.toString('ascii', 12 + i * 16, 16 + i * 16);
      if (tag === 'cmap') { cmapOffset = buf.readUInt32BE(12 + i * 16 + 8); break; }
    }
    if (!cmapOffset) return null;

    const numSubtables = buf.readUInt16BE(cmapOffset + 2);
    const subtables = [];
    for (let i = 0; i < numSubtables; i++) {
      const record = cmapOffset + 4 + i * 8;
      subtables.push({
        platformId: buf.readUInt16BE(record),
        encodingId: buf.readUInt16BE(record + 2),
        offset: cmapOffset + buf.readUInt32BE(record + 4)
      });
    }
    const rank = s => (s.platformId === 3 && s.encodingId === 10 ? 0 : s.platformId === 3 && s.encodingId === 1 ? 1 : s.platformId === 0 ? 2 : 3);
    subtables.sort((a, b) => rank(a) - rank(b));

    const codePoints = new Set();
    const ranges = [];
    for (const subtable of subtables) {
      const format = buf.readUInt16BE(subtable.offset);
      if (format === 4) {
        const segCount = buf.readUInt16BE(subtable.offset + 6) / 2;
        const endOffset = subtable.offset + 14;
        const startOffset = endOffset + segCount * 2 + 2;
        const deltaOffset = startOffset + segCount * 2;
        const rangeOffsetOffset = deltaOffset + segCount * 2;
        for (let segment = 0; segment < segCount; segment++) {
          const end = buf.readUInt16BE(endOffset + segment * 2);
          const start = buf.readUInt16BE(startOffset + segment * 2);
          const delta = buf.readInt16BE(deltaOffset + segment * 2);
          const rangeOffset = buf.readUInt16BE(rangeOffsetOffset + segment * 2);
          if (start === 0xffff) continue;
          for (let code = start; code <= end && code < 0xffff; code++) {
            let glyphId;
            if (rangeOffset === 0) {
              glyphId = (code + delta) & 0xffff;
            } else {
              const index = rangeOffsetOffset + segment * 2 + rangeOffset + (code - start) * 2;
              if (index + 1 >= buf.length) continue;
              glyphId = buf.readUInt16BE(index);
              if (glyphId !== 0) glyphId = (glyphId + delta) & 0xffff;
            }
            if (glyphId !== 0) codePoints.add(code);
          }
        }
      } else if (format === 12) {
        const groupCount = buf.readUInt32BE(subtable.offset + 12);
        for (let group = 0; group < groupCount; group++) {
          const base = subtable.offset + 16 + group * 12;
          ranges.push([buf.readUInt32BE(base), buf.readUInt32BE(base + 4)]);
        }
      }
      if (codePoints.size > 0 || ranges.length > 0) break;
    }

    return {
      size: codePoints.size + ranges.reduce((total, [start, end]) => total + (end - start + 1), 0),
      has(codePoint) {
        if (codePoints.has(codePoint)) return true;
        return ranges.some(([start, end]) => codePoint >= start && codePoint <= end);
      }
    };
  } catch (error) {
    console.error('  [WARN] Could not parse the bundled font cmap:', error.message);
    return null;
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

    // --- 8. RENDERER INVARIANTS (word ownership, shared rows, blank slots, font) ---
    console.log('\n--- 8. Renderer Invariant Audit (word ownership & row geometry) ---');
    const allLines = await all('SELECT page_number, line_number, line_type, is_centered, text_indopak, words_json FROM mushaf_lines ORDER BY page_number, line_number');

    let ownershipMismatch = 0;
    let duplicateLocations = 0;
    let malformedLocations = 0;
    let emptyTokens = 0;
    let multiAyahRows = 0;
    let rowsAcrossTwoSurahs = 0;
    let nonAyahRowsWithWords = 0;
    let ayahRowsWithoutTokens = 0;
    let nonCenteredRowsWithOneLexicalWord = 0;
    let puaCharacters = 0;
    let replacementCharacters = 0;
    let populatedRows = 0;
    let centeredAyahRows = 0;
    let bismillahRows = 0;
    let surahHeaderRows = 0;
    const distinctLocations = new Set();
    const usedCodePoints = new Set();
    const blankRowsByPage = new Map();

    for (const row of allLines) {
      const words = JSON.parse(row.words_json || '[]');
      const isAyahRow = row.line_type === 'ayah_text';

      if (!isAyahRow && words.length > 0) nonAyahRowsWithWords++;
      if (isAyahRow && words.length === 0 && row.text_indopak.length > 0) ayahRowsWithoutTokens++;
      if (row.line_type === 'bismillah') bismillahRows++;
      if (row.line_type === 'surah_name') surahHeaderRows++;

      if (isAyahRow && words.length > 0) {
        populatedRows++;
        if (row.is_centered === 1) centeredAyahRows++;

        // The renderer maps a touch back to an Ayah through these tokens, so the
        // tokens must be a lossless, ordered partition of the printed row.
        if (words.map(w => w.text).join(' ') !== row.text_indopak) ownershipMismatch++;

        const seen = new Set();
        for (const word of words) {
          distinctLocations.add(word.location);
          if (seen.has(word.location)) duplicateLocations++; else seen.add(word.location);
          if (word.location !== `${word.surah}:${word.ayah}:${word.word}` || !word.surah || !word.ayah || !word.word) malformedLocations++;
          if (!word.text || word.text.length === 0) emptyTokens++;
        }
        if (new Set(words.map(w => w.surah)).size > 1) rowsAcrossTwoSurahs++;
        if (new Set(words.map(w => `${w.surah}:${w.ayah}`)).size > 1) multiAyahRows++;
        if (row.is_centered === 0 && words.filter(w => /\p{L}/u.test(w.text)).length < 2) nonCenteredRowsWithOneLexicalWord++;
      } else if (isAyahRow) {
        blankRowsByPage.set(row.page_number, (blankRowsByPage.get(row.page_number) || 0) + 1);
      }

      // Every row the renderer shapes — including the decorative Bismillah — must
      // be fully covered by the bundled font's cmap.
      for (const character of row.text_indopak) {
        const codePoint = character.codePointAt(0);
        usedCodePoints.add(codePoint);
        if (codePoint >= 0xe000 && codePoint <= 0xf8ff) puaCharacters++;
        if (codePoint === 0xfffd) replacementCharacters++;
      }
    }

    assert(ownershipMismatch === 0, `Every Ayah row rebuilds its printed text exactly from word tokens (mismatches: ${ownershipMismatch})`);
    assert(duplicateLocations === 0, `No Ayah row repeats a word location (duplicates: ${duplicateLocations})`);
    assert(malformedLocations === 0, `Every word location matches surah:ayah:word (malformed: ${malformedLocations})`);
    assert(emptyTokens === 0, `No word token is empty (empty: ${emptyTokens})`);
    assert(nonAyahRowsWithWords === 0, 'Surah headers and Bismillah rows never claim selectable words');
    assert(ayahRowsWithoutTokens === 0, 'No Ayah row has printed text without a token mapping');
    assert(rowsAcrossTwoSurahs === 0, 'No single row mixes two Surahs, so a Surah banner always separates them');
    assert(multiAyahRows > 0, `Shared rows exist and must be selectable per Ayah (rows with two Ayahs: ${multiAyahRows})`);
    assert(nonCenteredRowsWithOneLexicalWord === 0, 'Every justified row has at least two word groups, so expansion always has a valid boundary');
    assert(replacementCharacters === 0, 'The printed text contains no U+FFFD replacement characters');
    assert(puaCharacters > 0, `Verse ornaments use font-specific private-use glyphs (PUA characters: ${puaCharacters})`);
    assert(centeredAyahRows > 0 && bismillahRows > 0 && surahHeaderRows === 114,
      `Centered rows (${centeredAyahRows}), Bismillah rows (${bismillahRows}) and all 114 Surah headers are preserved`);

    // Page 28 row 10 is the canonical two-Ayah regression case.
    const mixedRow = allLines.find(r => r.page_number === 28 && r.line_number === 10);
    const mixedVerses = mixedRow ? [...new Set(JSON.parse(mixedRow.words_json).map(w => `${w.surah}:${w.ayah}`))].sort() : [];
    assert(mixedRow && mixedVerses.join(',') === '2:143,2:144', `Page 28 row 10 owns both 2:143 and 2:144 (found: ${mixedVerses.join(',') || 'none'})`);

    // Pages 1, 2 and 849 keep five deliberately unprinted slots at the end.
    for (const page of [1, 2, 849]) {
      const lines = allLines.filter(r => r.page_number === page);
      const blankRows = lines.filter(r => r.line_type === 'ayah_text' && JSON.parse(r.words_json || '[]').length === 0).map(r => r.line_number);
      assert(blankRows.join(',') === '9,10,11,12,13', `Page ${page} preserves exactly its five empty source slots (found: ${blankRows.join(',') || 'none'})`);
    }
    assert(distinctLocations.size > 80000, `Word tokens map to ${distinctLocations.size} distinct locations across ${populatedRows} populated rows`);

    // --- 9. FONT COVERAGE AUDIT ---
    console.log('\n--- 9. Bundled Calligraphy Font Coverage Audit ---');
    const fontPath = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Fonts', 'IndoPak-Nastaleeq.ttf');
    assert(fs.existsSync(fontPath), 'IndoPak-Nastaleeq.ttf is bundled with the application');
    if (fs.existsSync(fontPath)) {
      const cmap = readFontCmap(fontPath);
      assert(cmap !== null, 'The bundled font exposes a parsable cmap table');
      if (cmap) {
        const missing = [...usedCodePoints].filter(codePoint => !cmap.has(codePoint));
        assert(missing.length === 0, `All ${usedCodePoints.size} code points used in the printed text are mapped by the bundled font (missing: ${missing.length})`);
      }
    }

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
