# Quran Content Architecture & Licensing Strategy

**This is the most important document in this set. Read it fully before writing any code that touches Quran text.** Nothing here is a substitute for the IP attorney and Islamic-scholar review flagged in document 01 — it is the research needed to brief them effectively and to build responsibly while that review is underway.

---

## 1. The core principle

The Quranic text itself is not "ownable" in a religious sense, but **every digital artifact derived from it — a specific typeset arrangement, a specific translation's wording, a specific recitation recording, a specific font, a specific set of scanned page images — is created by identifiable people or organizations who hold rights in *that specific artifact*.** Your job is to source each artifact from a place that has clear, commercially-compatible permission to redistribute it, attribute correctly, and never assume "it's religious, so it must be free to use however I want."

---

## 2. Source-by-source findings

### 2.1 Arabic Quran text
- **Primary recommendation: Quran Foundation's Content APIs / Content Sync APIs.** Their Developer Terms explicitly permit commercial and freemium apps to display this content as part of the end-user experience, with no separate commercial license needed, provided the text is never modified and never redistributed as raw data/dataset. Their Content Sync API is specifically designed for the offline-mirror use case this app needs, with a required re-sync at least every 7 days while online (perfectly compatible with "offline-first" — the user experience is unaffected; it's a background compliance mechanism, not a UX constraint).
- **Secondary/verification reference: Tanzil.net's Uthmani text**, CC BY 3.0 — permission to copy/distribute, explicit prohibition on altering the text, attribution to Tanzil Project with a link back required. Use this as an independent cross-check corpus in your content-verification pipeline (§6 below), not necessarily as your live data source.
- **Do not** scrape quran.com's website directly — their website Terms of Service (as opposed to the separate Quran Foundation *developer* API terms) restrict copying/reproduction/redistribution of site content to personal, non-commercial use. Always go through the official developer API, not the website.

### 2.2 The 13-line Mushaf page structure
- **There is no single official 13-line government edition** the way the King Fahd Complex's 15-line Uthmani Mushaf is the de facto worldwide standard for that layout. The 13-line convention (large Indo-Pak/Persian Naskh script, ~13 lines/page, every page ending on a complete ayah, popular for Hifz/memorization in South Asia, South Africa, and diaspora communities) has historically been typeset independently by multiple publishers (Taj Company Karachi, Waterval Islamic Institute, Jamiatul Ulama South Africa, and others), each with their own specific page-by-page arrangement.
- **The most useful existing dataset found:** Tarteel AI's Quranic Universal Library (QUL) hosts a structured "Indopak 13 Lines – Taj Company" layout — a page/line/word-indexed SQLite/JSON export (not scanned images) built exactly for this rendering problem, paired with compatible IndoPak Quran scripts and fonts, and credited in QUL's own acknowledgments to King Fahd Glorious Qur'an Printing Complex for underlying fonts/images and to Tanzil for the underlying text.
- **The licensing gray area:** QUL is described by its maintainers as open and community-driven, "primarily geared towards other Muslim developers," but a documented public request from another developer building a commercial-adjacent Islamic app asking QUL's team directly for commercial-licensing clarity did not surface a published blanket policy. **Action required before shipping:** email the QUL/Tarteel team directly, describe your specific commercial subscription app and your intended use (rendering the Indopak 13-line layout, offline, in a paid app), and get written confirmation. This is a low-cost, high-value step — do it early, in parallel with engineering, not as a launch blocker discovered late.
- **Recommended engineering hedge, regardless of the answer above:** build your content pipeline so the *layout data* (which ayah/word appears on which line/page) is stored as a swappable configuration, not hard-coded into rendering logic. If QUL licensing terms turn out to be unsuitable, or you want to reduce reliance on any single publisher's specific historical typesetting, you can commission or compute an **original 13-line pagination** — a fresh, independent decision about where each page/line break falls, applied to the CC-BY-licensed Tanzil Arabic text — which sidesteps the question of reproducing any specific publisher's arrangement entirely. This is a real engineering option, not just a legal fallback: the "13 lines per page, ending on a verse boundary" *convention* is a widely-shared idea; a *specific* page-by-page break sequence is what any individual publisher might claim as their arrangement. An attorney should confirm this reasoning for your jurisdiction(s) before you rely on it as your primary path.

### 2.3 Fonts
- **KFGQPC Uthmanic/Naskh fonts** (the standard for 15-line Uthmani rendering): free to embed and distribute inside your app; explicitly **cannot** be sold standalone, modified, reverse-engineered, or have their source extracted. Fine for direct in-app embedding.
- **IndoPak-script fonts** (needed for the 13-line format specifically) are distributed alongside the QUL Mushaf layout resources described above — subject to the same licensing-confirmation action item in §2.2.
- Whichever font you use, **never let an AI coding agent "helpfully" modify, subset, or hint the font files without checking the license first** — font modification is one of the more common inadvertent license violations in app projects, and it's an easy thing for an automated build step to do silently (e.g., a well-meaning font-subsetting optimization script).

### 2.4 Page images vs. rendered text
- **Recommendation: render text from structured data (glyph-accurate fonts + word/line layout data), do not use scanned bitmap page images**, for three independent reasons: (1) licensing — a scanned image of a specific printed book is unambiguously that publisher's copyrighted reproduction, a much harder rights position than structured text data; (2) accessibility — scanned images are invisible to VoiceOver and can't support text selection/search/copy, which this product needs; (3) quality/adaptability — rendered text scales cleanly across device sizes and supports dark mode/zoom without the artifacts of a scaled bitmap. Several existing 13-line apps (per the competitive research in doc 01) are simple PDF/image viewers — this is precisely the "low bar" this app should clear.

### 2.5 Ayah boundaries, surah/juz/hizb/rub'/sajdah metadata
- Sourced from the same structured datasets above (Quran Foundation API / QUL exports both include this metadata alongside the text), cross-verified against Tanzil's independently-audited corpus. This metadata is highly standardized across the Muslim world (ayah numbering per the standard Kufi/Egyptian numbering convention used by nearly all modern print and digital Qurans) and carries very low licensing risk — the risk here is **accuracy**, not rights, which is exactly what the verification pipeline in §6 and the scholarly review in doc 01 are for.

### 2.6 Translations
- **Do not** use Tanzil's bundled translation corpus for anything beyond non-commercial reference/testing — it is explicitly non-commercial-only, and using it in a paid app without separate permission from each translator/publisher would be a direct license violation.
- **Primary recommendation:** the translations served through Quran Foundation's Content API, which fall under the same commercial-permitted developer terms as the Arabic text — **but** the FAQ explicitly notes "any source-specific license requirements" still apply on top of the general permission, meaning some individual translations in their catalog may carry their own additional restrictions. **Action item:** before finalizing your V1 translation list, request from Quran Foundation (via the licensing contact in their FAQ) an explicit list of which specific translations in their catalog are cleared for full commercial/offline use in a paid app, and use only those for V1.
- **Safe fallback for at least one translation:** public-domain English translations (e.g., Muhammad Marmaduke Pickthall's *The Meaning of the Glorious Koran*, 1930; earlier editions of Abdullah Yusuf Ali's translation) are old enough to be public domain in the US and most jurisdictions, carrying essentially zero commercial-licensing risk — though they read as more archaic English, which is a genuine product/scholarly trade-off (flag for your Islamic-scholar reviewer: archaic language vs. licensing certainty). A defensible V1 strategy is to ship **one publicly-cleared modern translation via Quran Foundation** as the default, with a public-domain option available as a safety net if the Quran Foundation translation list changes.
- **Modern, popular translations you may want later** (Saheeh International, Dr. Mustafa Khattab's *The Clear Quran*, etc.) typically require **direct commercial licensing from the translator/publisher** — this is a real negotiation, not a technical integration, and should go through your IP attorney.

### 2.7 Tafsir
- Same sourcing logic as translations: use only tafsir volumes explicitly confirmed as commercially-cleared through Quran Foundation's catalog (or an equivalent confirmed source), gated behind Premium in V1 per doc 02.

### 2.8 Audio recitations
- **Do not** build your primary audio pipeline on community MP3 mirrors (everyayah.com, versebyversequran.com) — community-documented licensing for this content is CC BY-NC (non-commercial), which directly conflicts with a paid subscription app. QuranicAudio.com publishes no clear license at all, which is its own red flag (absence of a license is not the same as permission).
- **Primary recommendation:** Quran Foundation's Audio API, covered by the same general commercial-use permission as their other content, with the same "displayed as part of the end-user experience, not redistributed as raw data" constraint — meaning your app should stream/cache audio for playback, not expose a bulk "export these MP3 files" feature.
- Whichever reciters you launch with, get an explicit written answer from Quran Foundation on **offline caching duration for audio specifically** (their general FAQ addresses "QF Content" caching broadly at ≤1 week outside Content Sync — confirm audio recitations are included in the Content Sync exception, since large audio files are exactly the kind of asset an offline-first app needs to keep for longer than a week without re-fetching).

---

## 3. What ships in the app bundle vs. what downloads

| Content | Delivery | Rationale |
|---|---|---|
| Arabic 13-line Mushaf text + layout data + IndoPak font | **Bundled** (app binary) | Core free experience must work with zero network access from first launch |
| One default translation (confirmed commercially-cleared) | **Bundled** | Free tier must be genuinely useful offline immediately |
| One reciter, streaming | **On-demand streaming**, not bundled (audio is large; not everyone wants every reciter) | Keeps initial app size reasonable; download-to-offline is an explicit, visible user action |
| Additional translations/tafsir (Premium) | **On-demand download** via Content Sync, re-synced ≤7 days while online | Matches Quran Foundation's licensing constraint exactly |
| Additional reciters + offline packs (Premium) | **On-demand download**, background-refreshed | Same reasoning |
| Surah/juz/metadata | **Bundled** | Small, structural, needed immediately for navigation |

---

## 4. Attribution requirements (must appear in-app, in Settings → About)

- "Quran data provided by Quran Foundation" (exact phrasing requested in their developer FAQ), wherever Quranic content sourced from their API is surfaced.
- Named credit for each specific translation and tafsir edition used, per that edition's own licensing terms.
- Named credit for each reciter.
- Tanzil Project attribution with a link to tanzil.net, if/where Tanzil-sourced text is used directly.
- QUL/Tarteel AI attribution for the Mushaf layout dataset, if used, per whatever terms result from the direct licensing confirmation in §2.2.
- KFGQPC attribution for fonts, per their license terms.

---

## 5. Explicitly out of scope / do not do

- Do not let the app, or any AI coding agent working on it, ever "correct," "clean up," "normalize," or otherwise programmatically alter the Arabic text for formatting convenience (e.g., stripping diacritics to simplify a search index is fine *for the search index only*, never for the displayed/stored canonical text).
- Do not bundle or link to any recitation, translation, or tafsir source without a specific licensing answer on file for that exact source.
- Do not build a "download the whole Quran as files" export/share feature that effectively re-distributes the raw content packages — this crosses directly into the "resold, sublicensed, or redistributed as raw data" restriction common to nearly every source above.
- Do not use auto-translation (e.g., piping API translation text through a generic machine-translation service) — Quran Foundation's own FAQ specifically warns this can distort peer-reviewed translations into theological inaccuracies, independent of any licensing concern.

---

## 6. Content Verification Pipeline (so AI-generated code can never alter Quranic text)

This is the concrete system that makes "AI-assisted development" safe for this specific project. Treat it as a hard gate, not a nice-to-have.

**6.1 — Golden reference corpus.** At project setup, before any app code is written, download and store (outside the app's normal content pipeline, in a dedicated `ContentIntegrity/reference/` folder used only by tests) an independent, checksummed copy of the full Arabic Uthmani text from Tanzil, plus the full ayah/surah/juz/hizb/sajdah metadata. This is your ground truth, never modified after initial creation, checked into version control as read-only reference fixtures.

**6.2 — Automated diff testing, not manual proofreading, as the primary safety net.** Every time content is bundled, downloaded, or touched by any code change:
- Compare every ayah's Unicode text, character-by-character, against the golden reference corpus. Any diff fails the build/update.
- Verify ayah count per surah matches the known-correct count for all 114 surahs (a fixed, well-known table).
- Verify total ayah count (6,236 in the standard Hafs numbering — confirm exact figure with your scholarly reviewer, as counting conventions vary slightly by tradition) matches exactly.
- Verify no duplicate (surah, ayah) keys exist, and no gaps exist in the sequence.
- Verify every page in the 13-line layout dataset sums to the correct total ayah/word count with no words dropped or duplicated across page/line boundaries.
- Verify Unicode normalization/encoding integrity (no replacement characters, no unexpected combining-mark corruption, correct UTF-8 throughout).
- Verify sajdah ayah positions match a known-correct reference list (there are a small, fixed number of sajdah verses; this is easy to hard-code as a checked constant and diff against).

**6.3 — CI gate.** Wire all of §6.2 into your test suite (see document 07) as tests that run on every single build, not just before release — this is what allows an AI coding agent to work quickly without fear, because any accidental text corruption from a refactor, a bad merge, or an over-eager "let me fix this formatting" edit is caught automatically within seconds, before it can reach a device, let alone a released build.

**6.4 — Human-in-the-loop gate before any content-affecting release.** Independent of the automated pipeline, no update that touches the content database, translation set, or tafsir set ships without a sign-off step from your Islamic-scholar reviewer (doc 01 §7) — the automated pipeline proves *nothing changed unexpectedly*, not that the content is *correct in the first place*, which is a different and equally necessary check.

**6.5 — Runtime tripwire (defense in depth).** Even after all of the above, add a lightweight runtime checksum verification of the active content database on app launch (comparing a stored hash against the expected hash for the currently-active content version) — if it ever mismatches (e.g., due to a corrupted download or on-device data corruption), the app should silently fall back to the last known-good bundled/cached version rather than displaying unverified content, and log the event to crash reporting for investigation. This is cheap to implement and closes the loop between "verified at build/download time" and "still correct at the moment someone is reading."
