/**
 * pipeline/mushaf/import_edition.cjs
 *
 * Deterministic ingestion pipeline for the Authentic 13-Line Mushaf (Taj Company edition).
 * - Extracts and validates 848 page images (847 Quran pages + 1 concluding Dua page)
 * - Parses 847 HTML coordinate map files into normalized [0, 1] bounding rectangles
 * - Applies versioned coordinate patch for source 522 (verses 26:143-145)
 * - Builds mushaf_editions.sqlite with strict schema, foreign keys, and indexes
 * - Emits catalog.json and notices/taj-company-13-847.txt
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sqlite3 = require('sqlite3').verbose();

const CANONICAL_DB_PATH = path.join(__dirname, '..', '..', 'QuranApp', 'Resources', 'Database', 'quran_content.sqlite');
const SCHEMA_PATH = path.join(__dirname, 'schema.sql');
const PATCH_522_PATH = path.join(__dirname, 'patches', 'patch_522.json');

const EXTRACTED_ROOT = path.join(__dirname, '..', 'temp_apk_extracted', 'assets', 'www', 'book');
const IMAGES_DIR = path.join(EXTRACTED_ROOT, 'Images');
const HTML_DIR = path.join(EXTRACTED_ROOT, 'Html');

const EDITIONS_ROOT = path.join(__dirname, '..', '..', 'QuranApp', 'Resources', 'MushafEditions');
const NOTICES_DIR = path.join(EDITIONS_ROOT, 'notices');
const EDITION_PAGES_DIR = path.join(EDITIONS_ROOT, 'editions', 'taj-company-13-847', 'v1', 'pages');
const TARGET_DB_PATH = path.join(EDITIONS_ROOT, 'mushaf_editions.sqlite');
const CATALOG_PATH = path.join(EDITIONS_ROOT, 'catalog.json');

function sha256File(filePath) {
  const data = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(data).digest('hex');
}

function readPngDimensions(filePath) {
  const buf = fs.readFileSync(filePath);
  if (buf.length < 24 || buf.toString('ascii', 1, 4) !== 'PNG') {
    throw new Error(`Not a valid PNG: ${filePath}`);
  }
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20)
  };
}

function runAsync(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) reject(err);
      else resolve(this);
    });
  });
}

async function run() {
  console.log('=== AUTHENTIC 13-LINE MUSHAF INGESTION PIPELINE ===');

  // 1. Verify Canonical Database
  if (!fs.existsSync(CANONICAL_DB_PATH)) {
    throw new Error(`Canonical DB not found at: ${CANONICAL_DB_PATH}`);
  }
  const canonicalHash = sha256File(CANONICAL_DB_PATH);
  console.log(`Canonical DB verified: ${canonicalHash.slice(0, 16)}...`);

  // Load canonical data
  const canonicalDb = new sqlite3.Database(CANONICAL_DB_PATH, sqlite3.OPEN_READONLY);
  const canonicalVerses = await new Promise((resolve, reject) => {
    canonicalDb.all('SELECT id, surah_id, verse_number FROM ayahs ORDER BY id;', (err, rows) => {
      if (err) reject(err); else resolve(rows);
    });
  });
  const canonicalJuzs = await new Promise((resolve, reject) => {
    canonicalDb.all('SELECT id, start_surah_id, start_verse_number FROM juzs ORDER BY id;', (err, rows) => {
      if (err) reject(err); else resolve(rows);
    });
  });
  const canonicalSurahs = await new Promise((resolve, reject) => {
    canonicalDb.all('SELECT id, english_name, arabic_name, start_page FROM surahs ORDER BY id;', (err, rows) => {
      if (err) reject(err); else resolve(rows);
    });
  });
  canonicalDb.close();

  const canonicalVerseSet = new Set(canonicalVerses.map(v => `${v.surah_id}:${v.verse_number}`));
  console.log(`Loaded ${canonicalVerses.length} canonical verses across ${canonicalSurahs.length} Surahs and ${canonicalJuzs.length} Juzs.`);

  // 2. Prepare Output Directories
  fs.mkdirSync(NOTICES_DIR, { recursive: true });
  fs.mkdirSync(EDITION_PAGES_DIR, { recursive: true });

  // 3. Write Legal Notice
  const noticeContent = `Taj Company 13-Line Color-Coded Tajweed Mushaf (Lahore, Pakistan).
Digital page scans & coordinate datasets courtesy of Qamar Apps,
distributed under the Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0).
https://creativecommons.org/licenses/by-sa/4.0/

Coordinate repairs applied by 13Line project for verses 26:143-145 (source 522).
Canonical text, search index, and audio sync verified independently.
`;
  const noticePath = path.join(NOTICES_DIR, 'taj-company-13-847.txt');
  fs.writeFileSync(noticePath, noticeContent, 'utf8');

  // 4. Load Patch for 522
  const patch522 = JSON.parse(fs.readFileSync(PATCH_522_PATH, 'utf8'));

  // 5. Initialize mushaf_editions.sqlite
  if (fs.existsSync(TARGET_DB_PATH)) {
    fs.unlinkSync(TARGET_DB_PATH);
  }
  const db = new sqlite3.Database(TARGET_DB_PATH);
  const schemaSql = fs.readFileSync(SCHEMA_PATH, 'utf8');
  await new Promise((resolve, reject) => {
    db.exec(schemaSql, err => {
      if (err) reject(err); else resolve();
    });
  });
  console.log('Initialized sidecar database schema.');

  // Begin transaction
  await runAsync(db, 'BEGIN IMMEDIATE TRANSACTION;');

  // Insert metadata
  await runAsync(db, 'INSERT INTO metadata (key, value) VALUES (?, ?);', ['schema_version', '1']);
  await runAsync(db, 'INSERT INTO metadata (key, value) VALUES (?, ?);', ['canonical_db_sha256', canonicalHash]);
  await runAsync(db, 'INSERT INTO metadata (key, value) VALUES (?, ?);', ['edition_id', 'taj-company-13-847']);
  await runAsync(db, 'INSERT INTO metadata (key, value) VALUES (?, ?);', ['content_version', '1']);

  // Populate canonical_verses
  console.log('Populating canonical_verses...');
  for (const v of canonicalVerses) {
    await runAsync(db, 'INSERT INTO canonical_verses (surah_id, ayah_number, canonical_id) VALUES (?, ?, ?);', [v.surah_id, v.verse_number, v.id]);
  }

  // Insert edition
  await runAsync(db, `
    INSERT INTO editions (
      edition_id, content_version, display_name, publisher, renderer_kind,
      approval_status, quran_page_count, navigation_page_count, notice_path
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
  `, [
    'taj-company-13-847',
    1,
    'Taj Company 13-Line (Color Tajweed)',
    'Taj Company Ltd. / Qamar Apps',
    'facsimile',
    'approved',
    847,
    848,
    'notices/taj-company-13-847.txt'
  ]);

  // 6. Process Pages (1 to 848)
  const versePageOccurrences = new Map();
  const pageParsedData = [];

  console.log('Processing 848 pages and copying images...');

  for (let navIndex = 1; navIndex <= 848; navIndex++) {
    const isQuran = navIndex <= 847;
    const sourceAssetNum = navIndex + 3; // 1 -> 004, 847 -> 850, 848 -> 851
    const sourceAssetId = String(sourceAssetNum).padStart(3, '0');
    const pageId = `p${String(navIndex).padStart(4, '0')}`;
    const quranOrdinal = isQuran ? navIndex : null;
    const printedLabel = String(sourceAssetNum);

    let kind = 'quran';
    let title = `Page ${navIndex}`;
    if (navIndex === 847) {
      kind = 'quranAndSupplement';
      title = 'Surah An-Nas & Dua Khatam al-Quran';
    } else if (navIndex === 848) {
      kind = 'supplement';
      title = 'Dua Khatam al-Quran (Conclusion)';
    }

    // Source image
    const srcImgName = `${sourceAssetId}.png`;
    const srcImgPath = path.join(IMAGES_DIR, srcImgName);
    if (!fs.existsSync(srcImgPath)) {
      throw new Error(`Missing source image: ${srcImgPath}`);
    }

    const dstImgName = `page_${String(navIndex).padStart(3, '0')}.png`;
    const dstImgPath = path.join(EDITION_PAGES_DIR, dstImgName);
    fs.copyFileSync(srcImgPath, dstImgPath);

    const imgHash = sha256File(dstImgPath);
    const { width: imgW, height: imgH } = readPngDimensions(dstImgPath);
    const relativeImgPath = `editions/taj-company-13-847/v1/pages/${dstImgName}`;

    await runAsync(db, `
      INSERT INTO pages (
        edition_id, page_id, navigation_index, quran_ordinal, printed_label,
        kind, title, source_asset_id, source_width, source_height,
        image_path, image_sha256
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    `, [
      'taj-company-13-847', pageId, navIndex, quranOrdinal, printedLabel,
      kind, title, sourceAssetId, imgW, imgH, relativeImgPath, imgHash
    ]);

    // Parse HTML map if Quran page
    const rawRegions = [];
    if (isQuran) {
      const htmlPath = path.join(HTML_DIR, `${sourceAssetId}.html`);
      if (!fs.existsSync(htmlPath)) {
        throw new Error(`Missing HTML map: ${htmlPath}`);
      }

      if (sourceAssetId === '522') {
        // Use patch
        for (const r of patch522.replacementRegions) {
          rawRegions.push({
            minX: r.minX / imgW,
            minY: r.minY / imgH,
            maxX: r.maxX / imgW,
            maxY: r.maxY / imgH,
            rel: r.rel,
            label: r.description
          });
        }
        // Also keep other non-defective regions from 522
        const content = fs.readFileSync(htmlPath, 'utf8');
        const areaRegex = /<area\s+[^>]*coords="([^"]+)"\s+[^>]*rel="([^"]+)"[^>]*>/gi;
        let match;
        while ((match = areaRegex.exec(content)) !== null) {
          const coordsStr = match[1];
          const rel = match[2];
          if (coordsStr === '0,0,0,0' || (coordsStr === '21.99,109.01,562.3,174.97' && rel === '026145') || (coordsStr === '21.99,186.28,697.38,252.25' && rel === '026145')) {
            continue;
          }
          const [x1, y1, x2, y2] = coordsStr.split(',').map(Number);
          rawRegions.push({
            minX: x1 / imgW,
            minY: y1 / imgH,
            maxX: x2 / imgW,
            maxY: y2 / imgH,
            rel: rel,
            label: null
          });
        }
      } else {
        const content = fs.readFileSync(htmlPath, 'utf8');
        const areaRegex = /<area\s+[^>]*coords="([^"]+)"\s+[^>]*rel="([^"]+)"[^>]*>/gi;
        let match;
        while ((match = areaRegex.exec(content)) !== null) {
          const coordsStr = match[1];
          const rel = match[2];
          const [x1, y1, x2, y2] = coordsStr.split(',').map(Number);
          if (x1 === 0 && y1 === 0 && x2 === 0 && y2 === 0) {
            throw new Error(`Unexpected zero-area region on page ${pageId}, source ${sourceAssetId}, rel ${rel}`);
          }
          rawRegions.push({
            minX: x1 / imgW,
            minY: y1 / imgH,
            maxX: x2 / imgW,
            maxY: y2 / imgH,
            rel: rel,
            label: null
          });
        }
      }
    }

    // Sort regions in reading order
    rawRegions.sort((a, b) => {
      const lineDiff = a.minY - b.minY;
      if (Math.abs(lineDiff) > 0.035) {
        return lineDiff;
      }
      return b.maxX - a.maxX; // RTL
    });

    const parsedRegions = [];
    const pageVerseKeys = [];
    const fragmentCounts = new Map();

    let sourceOrder = 1;
    for (const r of rawRegions) {
      let kind = 'ayah';
      let surahId = null;
      let ayahNum = null;
      let label = r.label;

      if (r.rel.endsWith('000')) {
        kind = 'bismillah';
        const sNum = parseInt(r.rel.slice(0, 3), 10);
        label = `Bismillah (Surah ${sNum})`;
      } else {
        surahId = parseInt(r.rel.slice(0, 3), 10);
        ayahNum = parseInt(r.rel.slice(3, 6), 10);
        const vKey = `${surahId}:${ayahNum}`;
        if (!canonicalVerseSet.has(vKey)) {
          throw new Error(`Noncanonical verse key ${vKey} on page ${pageId}`);
        }
        if (!pageVerseKeys.includes(vKey)) {
          pageVerseKeys.push(vKey);
        }
        if (!versePageOccurrences.has(vKey)) {
          versePageOccurrences.set(vKey, []);
        }
        if (!versePageOccurrences.get(vKey).includes(pageId)) {
          versePageOccurrences.get(vKey).push(pageId);
        }
      }

      const fragKey = kind === 'ayah' ? `${surahId}:${ayahNum}` : 'nonverse';
      const fragOrder = (fragmentCounts.get(fragKey) || 0) + 1;
      fragmentCounts.set(fragKey, fragOrder);

      const regionId = `${pageId}-r${sourceOrder}`;
      parsedRegions.push({
        regionId,
        kind,
        surahId,
        ayahNum,
        fragmentOrder: fragOrder,
        sourceOrder: sourceOrder++,
        label,
        minX: Math.max(0, Math.min(1, r.minX)),
        minY: Math.max(0, Math.min(1, r.minY)),
        maxX: Math.max(0, Math.min(1, r.maxX)),
        maxY: Math.max(0, Math.min(1, r.maxY))
      });
    }

    pageParsedData.push({
      pageId,
      navIndex,
      pageVerseKeys,
      parsedRegions
    });
  }

  // 7. Insert Page Verses and Regions
  console.log('Inserting page verses and regions with continuation tracking...');
  for (const p of pageParsedData) {
    let readingOrder = 1;
    for (const vKey of p.pageVerseKeys) {
      const [sId, aNum] = vKey.split(':').map(Number);
      const occurrences = versePageOccurrences.get(vKey);
      const startsHere = occurrences[0] === p.pageId ? 1 : 0;
      const endsHere = occurrences[occurrences.length - 1] === p.pageId ? 1 : 0;

      await runAsync(db, `
        INSERT INTO page_verses (
          edition_id, page_id, surah_id, ayah_number, reading_order, starts_here, ends_here
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
      `, ['taj-company-13-847', p.pageId, sId, aNum, readingOrder++, startsHere, endsHere]);
    }

    for (const r of p.parsedRegions) {
      await runAsync(db, `
        INSERT INTO regions (
          edition_id, page_id, region_id, kind, surah_id, ayah_number,
          fragment_order, source_order, label, min_x, min_y, max_x, max_y
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `, [
        'taj-company-13-847', p.pageId, r.regionId, r.kind, r.surahId, r.ayahNum,
        r.fragmentOrder, r.sourceOrder, r.label, r.minX, r.minY, r.maxX, r.maxY
      ]);
    }
  }

  // 8. Insert Navigation Anchors (Surahs & Juzs)
  console.log('Inserting Surah and Juz navigation anchors...');

  // Surahs 1..114
  for (const s of canonicalSurahs) {
    const vKey = `${s.id}:1`;
    const occurrences = versePageOccurrences.get(vKey);
    if (!occurrences || occurrences.length === 0) {
      throw new Error(`Surah start verse ${vKey} not found on any page!`);
    }
    const firstPageId = occurrences[0];
    await runAsync(db, `
      INSERT INTO navigation_anchors (
        edition_id, kind, number, page_id, surah_id, ayah_number
      ) VALUES (?, ?, ?, ?, ?, ?);
    `, ['taj-company-13-847', 'surah', s.id, firstPageId, s.id, 1]);
  }

  // Juzs 1..30
  for (const j of canonicalJuzs) {
    const vKey = `${j.start_surah_id}:${j.start_verse_number}`;
    const occurrences = versePageOccurrences.get(vKey);
    if (!occurrences || occurrences.length === 0) {
      throw new Error(`Juz ${j.id} start verse ${vKey} not found on any page!`);
    }
    const firstPageId = occurrences[0];
    await runAsync(db, `
      INSERT INTO navigation_anchors (
        edition_id, kind, number, page_id, surah_id, ayah_number
      ) VALUES (?, ?, ?, ?, ?, ?);
    `, ['taj-company-13-847', 'juz', j.id, firstPageId, j.start_surah_id, j.start_verse_number]);
  }

  // Commit transaction
  await runAsync(db, 'COMMIT;');
  db.close();

  // 9. Generate catalog.json
  console.log('Generating catalog.json...');
  const catalog = {
    schemaVersion: 1,
    canonicalDatabaseSHA256: canonicalHash,
    sidecarDatabaseSHA256: sha256File(TARGET_DB_PATH),
    defaultEditionID: 'taj-company-13-847',
    editions: [
      {
        editionID: 'taj-company-13-847',
        contentVersion: 1,
        displayName: 'Taj Company 13-Line (Color Tajweed)',
        publisher: 'Taj Company Ltd. / Qamar Apps',
        rendererKind: 'facsimile',
        approvalStatus: 'approved',
        quranPageCount: 847,
        navigationPageCount: 848,
        noticePath: 'notices/taj-company-13-847.txt',
        coordinateSpace: 'normalized-top-left'
      }
    ]
  };

  fs.writeFileSync(CATALOG_PATH, JSON.stringify(catalog, null, 2), 'utf8');
  console.log('Catalog generated successfully.');
  console.log('=== INGESTION COMPLETE! ===');
}

run().catch(err => {
  console.error('INGESTION FAILED:', err);
  process.exit(1);
});
