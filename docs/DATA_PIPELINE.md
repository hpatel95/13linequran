# Phase 0: Quran Content & Data Sourcing Specification

This document provides a comprehensive audit, licensing evaluation, and architectural recommendation for every public and open-source data asset required to build the 13-Line Quran application.

---

## 1. The Definitive Mushaf Edition Decision

The term "13-Line Quran" is not generic; in the physical print tradition of South Asia, there are distinct lithographic editions with different page counts and ayah-to-line boundaries:

| Physical Edition | Page Count | Publisher / Origin | QUL Resource ID | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Qudratullah 13-Line** | **849 pages** | Qudratullah Company (Lahore, Pakistan) | **Layout 17** | 🏆 **APPROVED CANONICAL TARGET** |
| **Taj Company 13-Line** | 847 pages | Taj Company Ltd. (Karachi/Lahore) | Layout 313 | Alternate (different page breaks) |
| **Qamar Apps 13-Line** | 848 pages | Qamar Apps | Proprietary Scans | ❌ Rejected (licensing ambiguity) |

### Why Qudratullah (QUL Layout 17) is Selected:
1. **Mathematical Determinism**: Exactly 13 horizontal lines per page, fixed across 849 pages.
2. **Line-Level Word Ranges**: QUL explicitly defines `page_number`, `line_number`, `line_type`, `first_word_id`, and `last_word_id`.
3. **Paired Font Compatibility**: QUL provides the exact **Indopak Nastaleeq TTF** font paired mathematically to this layout.
4. **Hifz Community Standard**: Widely memorized across Pakistan, India, Bangladesh, the UK, and South African madrasas.

---

## 2. Complete Inventory of Public & Open-Source Data Assets

```
quran_content.sqlite
├── mushaf_layout     ◄── QUL Layout 17 (Qudratullah: page → line → word bounds)
├── quran_script       ◄── QUL IndoPak Nastaleeq Script (word-by-word locations)
├── quran_font         ◄── QUL IndoPak Nastaleeq Font (.ttf)
├── search_index       ◄── Tanzil.net Clean Imlaei Text (FTS5 normalized Arabic)
├── translations       ◄── Pickthall (English, 1930) + Hamidullah (French, KFGQPC 2000)
├── metadata           ◄── QUL & Tanzil Golden Reference (Surahs, Juz, Hizb, Sajdah)
└── audio_sync         ◄── QUL Segment Timestamps + EveryAyah CDN (Mishary Alafasy)
```

---

### Layer 1: 13-Line Mushaf Layout Data
* **Source**: Quranic Universal Library (QUL / Tarteel AI) — Resource ID `17`.
* **URL**: `https://qul.tarteel.ai/mushaf_layouts/17`
* **Format**: SQLite / JSON.
* **Fields**: `page_number`, `line_number`, `line_type` (`SURAH_NAME`, `BISMILLAH`, `AYAH_TEXT`), `is_centered`, `first_word_id`, `last_word_id`, `surah_number`.
* **Licensing**: Open Resource (MIT platform).
* **Recommendation**: **Adopt as the structural skeleton of the reader.** Eliminates random line-wrapping and preserves the physical printed page layout 1:1.

---

### Layer 2: Indo-Pak Arabic Script & Typography
* **Script Source**: QUL Resource `59` (*Indopak Nastaleeq script - Word by Word*).
* **Font Source**: QUL Resource `242` (*Indopak Nastaleeq Font - TTF*).
* **URL**: `https://qul.tarteel.ai/resources/quran-script/59` & `https://qul.tarteel.ai/resources/font/242`
* **Format**: SQLite database for text + `.ttf` font file.
* **What it contains**: Every individual word, its position, `surah:ayah:word` coordinates, page number, and hizb quarter.
* **Recommendation**: **Bundle the TTF font directly in Xcode assets.** Renders authentic calligraphic ligatures natively with zero pixelation on Super Retina displays.

---

### Layer 3: Search Engine Data (Normalized Arabic)
* **Source**: Tanzil.net (*Tanzil Clean / Imlaei Text*).
* **URL**: `https://tanzil.net/download/`
* **Format**: Plain text / XML / SQL.
* **Why it matters**: Calligraphic Indo-Pak text has intricate diacritics that make standard keyboard search impossible. Tanzil provides a normalized, diacritic-stripped representation where searching "الملك" matches verse 67:1 instantly.
* **Licensing**: Free for non-commercial and commercial application use with Tanzil attribution.
* **Recommendation**: **Store in `quran_search_fts` virtual table.** Power fast (<10ms) debounced full-text search.

---

### Layer 4: English Translations (Saheeh International & Hilali-Khan)
* **Exclusive English Translations**:
  1. *Saheeh International*: Widely popular, modern English, highly readable, standard in most top Quran apps.
  2. *Dr. Muhammad Taqi-ud-Din al-Hilali and Dr. Muhammad Muhsin Khan*: Highly regarded, authoritative; official translation endorsed by the King Fahd Complex.
* **Source**: QuranEnc / Tanzil / QUL.
* **Format**: SQLite / JSON.
* **Selection Policy**: Exclusively Saheeh International and Hilali-Khan. No other English translations.

---

### Layer 5: French Translation (Muhammad Hamidullah - KFGQPC Revision)
* **Candidate Translations Evaluated**:
  1. *Dr. Muhammad Hamidullah (1959, KFGQPC 2000 revision)*: The undisputed standard French translation in the Muslim world, published and revised by the King Fahd Holy Quran Printing Complex in Medina.
  2. *Rashid Maash (2019)*: Modern phrasing, but publisher copyright applies.
  3. *Denise Masson / Jacques Berque*: Academic/Orientalist (Éditions Gallimard), unsuitable for liturgical recitation.
* **Source**: QUL Resource `227` / QuranEnc (`french_hamidullah`).
* **Format**: JSON / SQLite with footnote structure.
* **Recommendation**: **Adopt Muhammad Hamidullah (KFGQPC 2000 edition).** Universal acceptance across francophone communities (France, Belgium, North/West Africa, Canada).

---

### Layer 6: Quranic Structural Metadata
* **Source**: QUL Quran Metadata (`quran-metadata`) validated against Tanzil XML golden reference.
* **URL**: `https://qul.tarteel.ai/resources/quran-metadata` & `https://tanzil.net/docs/Quran_Metadata`
* **Entities**:
  - `114` Surahs (Number, Arabic name, English name, French name, Revelation type, Total ayahs, Start page)
  - `30` Juz (Number, Arabic start snippet, Start ayah, Start page)
  - `60` Hizb & `240` Rub el Hizb
  - `7` Manzil & `558` Ruku
  - `14` Canonical Sajdah verse markers (Surah & Ayah numbers)
* **Recommendation**: **Pre-compile into `surahs`, `juz`, and `sajdahs` tables inside `quran_content.sqlite`.**

---

### Layer 7: Audio Recitation & Word Synchronization
* **Reciter**: Sheikh Khalifa Al Tunaiji.
* **Streaming Source**: EveryAyah CDN & QUL Recitation Metadata.
* **URL Pattern**: `https://everyayah.com/data/Khalifa_Al_Tunaiji_64kbps/{surah:03d}{ayah:03d}.mp3`
* **Synchronization Data**: QUL word-by-word segment timestamps map milliseconds to specific verse word ranges.
* **Licensing**: Open Islamic commons with attribution.
* **Recommendation**:
  - Stream directly from EveryAyah CDN.
  - Monetize offline downloading and repeat looping through the Supporter Pass.

---

## 3. Recommended SQLite Schema (`quran_content.sqlite`)

```sql
-- 1. Surahs Metadata
CREATE TABLE surahs (
    id INTEGER PRIMARY KEY,
    arabic_name TEXT NOT NULL,
    english_name TEXT NOT NULL,
    french_name TEXT NOT NULL,
    english_meaning TEXT NOT NULL,
    revelation_type TEXT NOT NULL, -- 'Meccan' or 'Medinan'
    total_verses INTEGER NOT NULL,
    start_page INTEGER NOT NULL,
    juz_number INTEGER NOT NULL
);

-- 2. Canonical Verses
CREATE TABLE ayahs (
    id INTEGER PRIMARY KEY,         -- Global index: 1 to 6236
    surah_id INTEGER NOT NULL,
    verse_number INTEGER NOT NULL,
    page_number INTEGER NOT NULL,   -- 13-line page: 1 to 849
    juz_number INTEGER NOT NULL,
    hizb_quarter INTEGER NOT NULL,
    sajdah INTEGER DEFAULT 0,       -- 1 if verse contains Sajdah
    text_indopak TEXT NOT NULL,
    text_clean TEXT NOT NULL,       -- Normalized for search
    FOREIGN KEY(surah_id) REFERENCES surahs(id)
);

-- 3. 13-Line Page & Line Layout
CREATE TABLE mushaf_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_number INTEGER NOT NULL,   -- 1 to 849
    line_number INTEGER NOT NULL,   -- 1 to 13
    line_type TEXT NOT NULL,        -- 'surah_name', 'bismillah', 'ayah_text'
    surah_id INTEGER,
    first_word_id INTEGER,
    last_word_id INTEGER,
    is_centered INTEGER DEFAULT 0
);

-- 4. Translations (English & French)
CREATE TABLE translations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ayah_id INTEGER NOT NULL,
    lang TEXT NOT NULL,             -- 'en' or 'fr'
    author_code TEXT NOT NULL,      -- 'pickthall' or 'hamidullah'
    text TEXT NOT NULL,
    footnotes TEXT,
    FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
);

-- 5. Full-Text Search (FTS5 Virtual Table)
CREATE VIRTUAL TABLE search_index USING fts5(
    ayah_id UNINDEXED,
    surah_id UNINDEXED,
    verse_number UNINDEXED,
    arabic_clean,
    translation_en,
    translation_fr,
    tokenize = 'unicode61 remove_diacritics 2'
);
```

---

## 4. Ingestion Action Plan (Phase 0)

1. **Download Sources**:
   - Download QUL Qudratullah Layout 17 SQLite / JSON dataset.
   - Download QUL IndoPak Nastaleeq TTF Font.
   - Download Tanzil Clean Arabic text & XML metadata.
   - Download QuranEnc / QUL English (Saheeh International & Hilali-Khan) and French (Hamidullah).
2. **Build Database Script** (`pipeline/build_db.js`):
   - Node.js script to merge, validate verse counts (114 Surahs, 6,236 Ayahs), and populate `quran_content.sqlite`.
3. **Generate FTS5 Index & SHA-256 Checksum**:
   - Verify query speed (<15ms).
   - Record SHA-256 hash in `QuranApp/Resources/Database/quran_content.sqlite.sha256`.
