const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'QuranApp', 'Resources', 'Database', 'quran_content.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  db.get('SELECT COUNT(*) as count FROM surahs', (err, row) => {
    console.log('Surahs count:', row.count, '(expected 114)');
  });
  db.get('SELECT COUNT(*) as count FROM ayahs', (err, row) => {
    console.log('Ayahs count:', row.count, '(expected 6236)');
  });
  db.get('SELECT COUNT(*) as count FROM mushaf_lines', (err, row) => {
    console.log('Mushaf lines count:', row.count, '(expected 11037)');
  });
  db.get('SELECT COUNT(*) as count FROM translations', (err, row) => {
    console.log('Translations count:', row.count, '(expected 18708)');
  });
  db.all('SELECT author_code, COUNT(*) as c FROM translations GROUP BY author_code', (err, rows) => {
    console.log('Translations breakdown:', rows);
  });

  const t0 = Date.now();
  db.all('SELECT ayah_id, translation_en_saheeh FROM search_index WHERE search_index MATCH ? LIMIT 3', ['praise'], (err, rows) => {
    const elapsed = Date.now() - t0;
    console.log('FTS5 search "praise" in ' + elapsed + 'ms:');
    console.log(rows);
  });
});
