PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE canonical_verses (
    surah_id INTEGER NOT NULL CHECK(surah_id BETWEEN 1 AND 114),
    ayah_number INTEGER NOT NULL CHECK(ayah_number > 0),
    canonical_id INTEGER NOT NULL UNIQUE,
    PRIMARY KEY (surah_id, ayah_number)
);

CREATE TABLE editions (
    edition_id TEXT PRIMARY KEY,
    content_version INTEGER NOT NULL CHECK(content_version > 0),
    display_name TEXT NOT NULL,
    publisher TEXT NOT NULL,
    renderer_kind TEXT NOT NULL CHECK(renderer_kind IN ('legacyText','facsimile')),
    approval_status TEXT NOT NULL CHECK(approval_status IN ('fixture','unapproved','approved')),
    quran_page_count INTEGER NOT NULL CHECK(quran_page_count > 0),
    navigation_page_count INTEGER NOT NULL CHECK(navigation_page_count >= quran_page_count),
    notice_path TEXT
);

CREATE TABLE pages (
    edition_id TEXT NOT NULL,
    page_id TEXT NOT NULL,
    navigation_index INTEGER NOT NULL CHECK(navigation_index > 0),
    quran_ordinal INTEGER CHECK(quran_ordinal > 0),
    printed_label TEXT,
    kind TEXT NOT NULL CHECK(kind IN ('quran','quranAndSupplement','supplement','frontMatter')),
    title TEXT NOT NULL,
    source_asset_id TEXT NOT NULL,
    source_width INTEGER,
    source_height INTEGER,
    image_path TEXT,
    image_sha256 TEXT,
    PRIMARY KEY (edition_id, page_id),
    UNIQUE (edition_id, navigation_index),
    UNIQUE (edition_id, quran_ordinal),
    UNIQUE (edition_id, source_asset_id),
    FOREIGN KEY (edition_id) REFERENCES editions(edition_id),
    CHECK (
      (kind IN ('quran','quranAndSupplement') AND quran_ordinal IS NOT NULL)
      OR (kind IN ('supplement','frontMatter') AND quran_ordinal IS NULL)
    ),
    CHECK (
      (source_width IS NULL AND source_height IS NULL AND image_path IS NULL AND image_sha256 IS NULL)
      OR (source_width IS NOT NULL AND source_width > 0
          AND source_height IS NOT NULL AND source_height > 0
          AND image_path IS NOT NULL AND image_sha256 IS NOT NULL
          AND length(image_sha256) = 64)
    )
);

CREATE TABLE page_verses (
    edition_id TEXT NOT NULL,
    page_id TEXT NOT NULL,
    surah_id INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    reading_order INTEGER NOT NULL CHECK(reading_order > 0),
    starts_here INTEGER NOT NULL CHECK(starts_here IN (0,1)),
    ends_here INTEGER NOT NULL CHECK(ends_here IN (0,1)),
    PRIMARY KEY (edition_id, page_id, surah_id, ayah_number),
    UNIQUE (edition_id, page_id, reading_order),
    FOREIGN KEY (edition_id, page_id) REFERENCES pages(edition_id, page_id),
    FOREIGN KEY (surah_id, ayah_number) REFERENCES canonical_verses(surah_id, ayah_number)
);
CREATE INDEX idx_page_verses_key ON page_verses(edition_id, surah_id, ayah_number);

CREATE TABLE regions (
    edition_id TEXT NOT NULL,
    page_id TEXT NOT NULL,
    region_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('ayah','bismillah','decoration','supplication')),
    surah_id INTEGER,
    ayah_number INTEGER,
    fragment_order INTEGER NOT NULL CHECK(fragment_order > 0),
    source_order INTEGER NOT NULL CHECK(source_order > 0),
    label TEXT,
    min_x REAL NOT NULL CHECK(min_x >= 0 AND min_x < 1),
    min_y REAL NOT NULL CHECK(min_y >= 0 AND min_y < 1),
    max_x REAL NOT NULL CHECK(max_x > 0 AND max_x <= 1 AND max_x > min_x),
    max_y REAL NOT NULL CHECK(max_y > 0 AND max_y <= 1 AND max_y > min_y),
    PRIMARY KEY (edition_id, page_id, region_id),
    UNIQUE (edition_id, page_id, source_order),
    UNIQUE (edition_id, page_id, surah_id, ayah_number, fragment_order),
    FOREIGN KEY (edition_id, page_id) REFERENCES pages(edition_id, page_id),
    FOREIGN KEY (edition_id, page_id, surah_id, ayah_number)
      REFERENCES page_verses(edition_id, page_id, surah_id, ayah_number)
);
CREATE INDEX idx_regions_verse ON regions(edition_id, surah_id, ayah_number);

CREATE TABLE navigation_anchors (
    edition_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('surah','juz')),
    number INTEGER NOT NULL,
    page_id TEXT NOT NULL,
    surah_id INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    PRIMARY KEY (edition_id, kind, number),
    FOREIGN KEY (edition_id, page_id, surah_id, ayah_number)
      REFERENCES page_verses(edition_id, page_id, surah_id, ayah_number)
);
