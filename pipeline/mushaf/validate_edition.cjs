/**
 * pipeline/mushaf/validate_edition.cjs
 *
 * Automated verification suite for the generated Authentic Mushaf sidecar database
 * and packaged resources (mushaf_editions.sqlite, catalog.json, page images).
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sqlite3 = require('sqlite3').verbose();

const EDITIONS_ROOT = path.join(__dirname, '..', '..', 'QuranApp', 'Resources', 'MushafEditions');
const DB_PATH = path.join(EDITIONS_ROOT, 'mushaf_editions.sqlite');
const CATALOG_PATH = path.join(EDITIONS_ROOT, 'catalog.json');
const CANONICAL_DB_PATH = path.join(__dirname, '..', '..', 'QuranApp', 'Resources', 'Database', 'quran_content.sqlite');

let totalChecks = 0;
let passedChecks = 0;
let failedChecks = 0;

function assert(cond, msg) {
  totalChecks++;
  if (cond) {
    passedChecks++;
    console.log(`  [PASS] ${msg}`);
  } else {
    failedChecks++;
    console.error(`  [FAIL] ${msg}`);
  }
}

function sha256File(filePath) {
  const data = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(data).digest('hex');
}

async function run() {
  console.log('=== AUTHENTIC MUSHAF PACKAGE & DATABASE VALIDATION ===\n');

  // 1. File existence
  assert(fs.existsSync(DB_PATH), `Sidecar DB exists at ${DB_PATH}`);
  assert(fs.existsSync(CATALOG_PATH), `Catalog exists at ${CATALOG_PATH}`);

  // 2. Catalog validation
  const catalog = JSON.parse(fs.readFileSync(CATALOG_PATH, 'utf8'));
  assert(catalog.schemaVersion === 1, 'Catalog schemaVersion is 1');
  assert(catalog.defaultEditionID === 'taj-company-13-847', 'Default edition is taj-company-13-847');
  assert(catalog.editions && catalog.editions.length === 1, 'Catalog contains 1 edition');
  const dbHash = sha256File(DB_PATH);
  assert(catalog.sidecarDatabaseSHA256 === dbHash, `Catalog sidecar hash matches DB file (${dbHash.slice(0, 16)}...)`);

  // 3. Database integrity checks
  const db = new sqlite3.Database(DB_PATH, sqlite3.OPEN_READONLY);

  const integrityCheck = await new Promise(res => db.all('PRAGMA integrity_check;', (err, rows) => res(rows)));
  assert(integrityCheck.length === 1 && integrityCheck[0].integrity_check === 'ok', 'PRAGMA integrity_check is ok');

  const fkCheck = await new Promise(res => db.all('PRAGMA foreign_key_check;', (err, rows) => res(rows)));
  assert(fkCheck.length === 0, `PRAGMA foreign_key_check has 0 violations (found: ${fkCheck.length})`);

  // 4. Metadata table
  const metaRows = await new Promise(res => db.all('SELECT key, value FROM metadata;', (err, rows) => res(rows)));
  const metaMap = new Map(metaRows.map(r => [r.key, r.value]));
  assert(metaMap.get('schema_version') === '1', 'Metadata schema_version is 1');
  assert(metaMap.get('edition_id') === 'taj-company-13-847', 'Metadata edition_id is taj-company-13-847');

  // 5. Canonical verses table
  const canonCount = await new Promise(res => db.get('SELECT COUNT(*) as c FROM canonical_verses;', (err, row) => res(row.c)));
  assert(canonCount === 6236, `Canonical verses count is 6,236 (found: ${canonCount})`);

  // 6. Editions table
  const edition = await new Promise(res => db.get('SELECT * FROM editions WHERE edition_id = "taj-company-13-847";', (err, row) => res(row)));
  assert(edition !== undefined, 'Edition taj-company-13-847 exists');
  assert(edition.quran_page_count === 847, `quran_page_count is 847 (found: ${edition.quran_page_count})`);
  assert(edition.navigation_page_count === 848, `navigation_page_count is 848 (found: ${edition.navigation_page_count})`);
  assert(edition.renderer_kind === 'facsimile', 'renderer_kind is facsimile');
  assert(edition.approval_status === 'approved', 'approval_status is approved');

  // 7. Pages table
  const pages = await new Promise(res => db.all('SELECT * FROM pages ORDER BY navigation_index;', (err, rows) => res(rows)));
  assert(pages.length === 848, `Pages count is exactly 848 (found: ${pages.length})`);

  let navIndicesContiguous = true;
  let quranOrdinalsContiguous = true;
  let allImagesExist = true;
  let allImageHashesMatch = true;

  for (let i = 0; i < pages.length; i++) {
    const p = pages[i];
    if (p.navigation_index !== i + 1) navIndicesContiguous = false;
    if (i < 847) {
      if (p.quran_ordinal !== i + 1) quranOrdinalsContiguous = false;
    } else {
      if (p.quran_ordinal !== null) quranOrdinalsContiguous = false;
    }

    const diskImgPath = path.join(EDITIONS_ROOT, p.image_path);
    if (!fs.existsSync(diskImgPath)) {
      allImagesExist = false;
    } else {
      const diskHash = sha256File(diskImgPath);
      if (diskHash !== p.image_sha256) allImageHashesMatch = false;
    }
  }

  assert(navIndicesContiguous, 'Navigation indices are strictly contiguous from 1 to 848');
  assert(quranOrdinalsContiguous, 'Quran ordinals are strictly contiguous from 1 to 847 (page 848 is null)');
  assert(allImagesExist, 'All 848 page image files exist on disk in QuranApp/Resources/MushafEditions/');
  assert(allImageHashesMatch, 'All 848 image SHA-256 hashes match database entries exactly');

  // 8. Page Verses & Canonical Coverage
  const distinctVerses = await new Promise(res => db.all('SELECT DISTINCT surah_id, ayah_number FROM page_verses;', (err, rows) => res(rows)));
  assert(distinctVerses.length === 6236, `Page verses map all 6,236 canonical verses (found: ${distinctVerses.length})`);

  const multiStarts = await new Promise(res => db.all(`
    SELECT surah_id, ayah_number, SUM(starts_here) as s_count
    FROM page_verses GROUP BY surah_id, ayah_number HAVING s_count != 1;
  `, (err, rows) => res(rows)));
  assert(multiStarts.length === 0, `Every canonical verse has exactly one starts_here = 1 (violations: ${multiStarts.length})`);

  const multiEnds = await new Promise(res => db.all(`
    SELECT surah_id, ayah_number, SUM(ends_here) as e_count
    FROM page_verses GROUP BY surah_id, ayah_number HAVING e_count != 1;
  `, (err, rows) => res(rows)));
  assert(multiEnds.length === 0, `Every canonical verse has exactly one ends_here = 1 (violations: ${multiEnds.length})`);

  // 9. Regions & Coordinate Validity
  const regionCount = await new Promise(res => db.get('SELECT COUNT(*) as c FROM regions;', (err, row) => res(row.c)));
  assert(regionCount > 15000, `Total interactive regions count > 15,000 (found: ${regionCount})`);

  const invalidRegions = await new Promise(res => db.all(`
    SELECT * FROM regions
    WHERE min_x < 0 OR min_y < 0 OR max_x > 1 OR max_y > 1 OR min_x >= max_x OR min_y >= max_y;
  `, (err, rows) => res(rows)));
  assert(invalidRegions.length === 0, `Zero invalid/out-of-bounds/zero-area regions (found: ${invalidRegions.length})`);

  // Verify Patch 522 for 26:143 and 26:144
  const patchRegions = await new Promise(res => db.all(`
    SELECT * FROM regions WHERE page_id = 'p0519' AND surah_id = 26 AND ayah_number IN (143, 144);
  `, (err, rows) => res(rows)));
  assert(patchRegions.length >= 2, `Patched regions for 26:143 and 26:144 exist on page p0519 (found: ${patchRegions.length})`);
  let patchHasZeroArea = false;
  for (const r of patchRegions) {
    if (r.min_x >= r.max_x || r.min_y >= r.max_y) patchHasZeroArea = true;
  }
  assert(!patchHasZeroArea, 'Patched 26:143 and 26:144 regions have positive non-zero area');

  // 10. Navigation Anchors (Surahs & Juzs)
  const surahAnchors = await new Promise(res => db.all('SELECT * FROM navigation_anchors WHERE kind = "surah" ORDER BY number;', (err, rows) => res(rows)));
  assert(surahAnchors.length === 114, `Exactly 114 Surah navigation anchors exist (found: ${surahAnchors.length})`);
  assert(surahAnchors[0].page_id === 'p0001', `Surah 1 anchor starts on page p0001 (found: ${surahAnchors[0].page_id})`);
  assert(surahAnchors[113].page_id === 'p0847', `Surah 114 anchor starts on page p0847 (found: ${surahAnchors[113].page_id})`);

  const juzAnchors = await new Promise(res => db.all('SELECT * FROM navigation_anchors WHERE kind = "juz" ORDER BY number;', (err, rows) => res(rows)));
  assert(juzAnchors.length === 30, `Exactly 30 Juz navigation anchors exist (found: ${juzAnchors.length})`);
  assert(juzAnchors[0].page_id === 'p0001', `Juz 1 anchor starts on page p0001 (found: ${juzAnchors[0].page_id})`);

  db.close();

  console.log(`\n====================================================`);
  console.log(`VALIDATION SUMMARY: ${passedChecks}/${totalChecks} checks passed (${failedChecks} failures).`);
  console.log(`====================================================`);

  if (failedChecks > 0) {
    process.exit(1);
  }
}

run().catch(err => {
  console.error('Validation crashed:', err);
  process.exit(1);
});
