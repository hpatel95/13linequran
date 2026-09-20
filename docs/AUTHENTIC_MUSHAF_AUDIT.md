# Authentic Mushaf: Independent Architecture and Source Audit

## Verdict

**Approve the image-backed reader direction, but not the proposed ingestion plan or AI-upscaling recommendation.**

The problem is not simply an unattractive font. The current renderer lacks the artwork and edition-specific geometry needed to reproduce a particular printed Mushaf. More importantly, the proposal combines an **849-page Qudratullah layout** with an asset package containing **847 Quran-bearing pages**. These cannot safely share page metadata.

**Recommended production approach:** an edition-locked, image-backed reader with a separate canonical-text/verse layer. Given the document's explicit 849-page requirement, obtain licensed, genuinely high-resolution artwork matching that exact Qudratullah edition and validate or create its coordinates. If matching Qamar's appearance is more important than preserving 849 pages, explicitly adopt its edition instead, subject to asset-rights clarification and coordinate repairs.

Do not silently relabel Qamar's pages as the existing 849-page edition. Do not use generative super-resolution to manufacture apparent Quranic detail.

**Execution companion:** [AUTHENTIC_MUSHAF_IMPLEMENTATION_PLAN.md](AUTHENTIC_MUSHAF_IMPLEMENTATION_PLAN.md) translates these conclusions into staged, file-specific tasks, schemas, tests, fallbacks, and human approval gates. It is a plan, not a record of completed implementation.

## Scope and confidence

Reviewed `AUTHENTIC_MUSHAF_ARCHITECTURE.md`, the current renderer and reader state, content/user database services, audio synchronization, pipeline, tests, and screenshot/reference samples. Independently inspected the local Qamar APK, its HTML maps and PNG headers, public licensing statements, QUL layout previews, Quran.com metadata, Archive metadata and PDF byte ranges, and Apple documentation.

- **Complete automated local audit:** every relevant PNG and HTML map in the supplied APK, compared with the bundled content database.
- **Sample-based verification:** visual comparisons and remote PDF internals. No claim of complete page-by-page visual or scholarly verification.
- **Executed:** `node pipeline/qa_audit.js` — **51/51 checks passed**.
- **Not executed:** native iOS builds, XCTest/UI tests, device performance measurements, or full-PDF inspection. This environment is Windows.
- No application code or production assets were changed. Research artifacts/scripts are under ignored `pipeline/temp/` paths.

## 1. What the existing implementation gets right—and cannot supply

`QuranApp/Features/Reader/Rendering/MushafPageLayout.swift` defines a fixed 13-row grid. `MushafTextLayoutEngine.swift` shapes source text, while `MushafTextCanvas.swift` uses shared geometry for drawing, selection, and accessibility. `MushafPageView.swift` and `QuranPageFrame.swift` add decorations.

This is useful infrastructure, not a broken Quran database. The audit confirms 114 surahs, 6,236 ayahs, 849 pages, three complete translations, and internally consistent word ownership. However, tests enforcing thirteen slots also preserve the five empty slots on the opening and final pages. They cannot establish that the result looks like a lithographic reference.

A general font plus uniform rows does not contain the reference edition's frontispieces, exact calligraphic composition, margin artwork, or concluding supplication. Adding a border and color rules would improve appearance but would not produce a facsimile. Conversely, vector rendering is not fundamentally incapable of fidelity: it would require edition-specific positioned glyphs or artwork that this project does not have.

Also avoid treating every 13-line edition as identical. Color Tajweed conventions, illumination, pagination, and supplementary material vary by edition. The document's universal statements about these features are too broad.

## 2. Critical source and migration findings

### A. Qamar is not a drop-in replacement for the current 849 pages

Measured directly from `pipeline/qamar_app.apk`:

| Property | Result |
|---|---:|
| PNG assets | 853 |
| HTML files in the page-map directory | 852 |
| Pages with mapped Quranic content | **847**, source assets `004`–`850` |
| Total rectangles | 15,903 |
| Quranic verse rectangles | 15,791 |
| Distinct canonical verse keys | 6,236 |
| Distinct introductory Bismillah keys (`surah:0`) | 112 |
| Invalid zero-area rectangles | **2** |
| Verses mapped on more than one source page | **700** |
| Current database pages with identical verse-key sets on any source page | **242 / 849** |
| Original PNG payload | **78,359,302 bytes** (~78.4 MB decimal) |
| PNG dimensions | 851 at 720×1057; one at 640×1136; one at 720×1043 |

The five empty-map HTML files are `00`, `000`, `001`, `002`, and `003`. Thus “852 coordinate files from 004 through 850” is incorrect: that range contains 847 files. Asset `851.png` contains concluding supplication material and is not an additional Quran verse map.

The difference between source asset index and current verse-start page ranges from **0 to 4**, not a constant offset. For example:

- Current page 1 matches source `004` by verse keys.
- Current page 610 matches source `613` by verse keys.
- Current page 613 does **not** match source `616` by verse keys.
- Current page 849 matches source `850` by verse keys.

Matching verse sets is weaker than matching word breaks or visual geometry, so even the 242 matches do not authorize coordinate reuse across editions.

QUL independently identifies resource **236** as Qudratullah, **849 pages**, and resource **313** as Taj Company, **847 pages**. Sampled Taj preview pages agree with sampled Qamar verse sets, but a complete 313-to-Qamar word-level comparison has not been performed.

**Required distinction:** source filename/index, printed page label, Quran-page ordinal, and navigation position are separate fields. The document's proposed filename renaming conflates them.

### B. The map is useful, but not “100% exact”

Source `522.html` contains:

```html
<area shape="rect" coords="0,0,0,0" rel="026143" ...>
<area shape="rect" coords="0,0,0,0" rel="026144" ...>
```

These are invalid selectable regions for **26:143** and **26:144**. All 6,236 verse keys being present does not establish valid hit regions for every verse.

No differing-key rectangle overlaps were detected above the audit's 0.02-source-pixel tolerance. This checks geometry, not whether a rectangle covers the correct printed words. Human verification remains necessary, particularly around the defective regions and adjacent verses.

Do not interpret introductory `surah:0` regions as canonical ayahs or send them to ordinary translation/audio queries. Likewise, supplication text must not inherit Quranic verse identities.

### C. The alleged Archive “master” is not established as a high-resolution source

For `13-line-quran-with-beautiful-color-coded-tajweed-rules-pdf`:

- Archive labels the JP2 ZIP a **derivative**, not an original scan.
- The original PDF is **82,809,370 bytes**; its linearized header indicates **850 pages**.
- The first **2,000,001 bytes** contain **15 sampled image dictionaries specifying 720×1057 pixels**.

A 3301×5100 derivative canvas does not prove that the underlying artwork has that resolution. Rendering an embedded 720-pixel image into a larger PDF/JP2 canvas cannot recover missing detail.

The document's claim that Qamar necessarily downsampled this Archive “master” is therefore unsupported; shared appearance does not establish direction of derivation. These samples are strong contrary evidence to using the item as a proven high-resolution upgrade, but are not a complete audit of every PDF page.

The other Archive candidates also expose JP2 collections labeled as derivatives. Their PPI metadata and ZIP sizes alone do not establish native detail, matching pagination, or reuse rights. They remain research leads, not approved production sources.

### D. Licensing needs reconciliation

The public [Qamar license page](https://www.qamarapps.com/license) states:

> All Qamar Apps publications are licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.

However, the supplied APK's `assets/www/book/Pages/aboutus.html` states that the digitally enhanced visual content and entire publication are copyright protected and unauthorized reproduction/use is forbidden.

Copyright and a Creative Commons license can coexist; this is not proof that reuse is prohibited. It is an unresolved scope/version issue. Obtain confirmation that the public license covers **these exact images and coordinate files**, and establish attribution, modification notices, ShareAlike, and distribution requirements. Review CC restrictions on downstream restrictions/technological measures for the intended distribution channel. Do not assume that a Settings attribution alone resolves every obligation, or that the entire app automatically must use the asset license.

Likewise, “printed more than 50 years ago” is not a sufficient worldwide public-domain analysis. Publication history, contributors, jurisdiction, and modern artwork/digital enhancements matter. Archive availability is not permission. Claims that commercial publishers categorically do not license assets were not independently established; ask them directly.

## 3. The proposed coordinate formula is wrong for an aspect-fit container

Independently scaling X and Y by the enclosing view's dimensions only works if that view exactly coincides with the displayed image. An aspect-fit image usually has letterboxing.

For image size `W × H` and container size `Vw × Vh`:

```text
s  = min(Vw / W, Vh / H)
ox = (Vw - W*s) / 2
oy = (Vh - H*s) / 2

imageX = (touchX - ox) / s
imageY = (touchY - oy) / s
```

Reject touches outside the displayed image. With pan/zoom, invert the complete composed image-to-view transform. Use that same transform to draw highlights; never calculate hit-testing and highlighting independently.

Store coordinates either in a declared source-pixel space or as true normalized `[0,1]` values. “Normalized pixels” is ambiguous. With normalized coordinates, a geometrically identical higher-resolution asset requires **no coordinate multiplication**. A crop, changed border, deskew, or different scan requires registration and validation, not just scaling by two.

## 4. What must change beyond the page view

| Area | Current coupling | Required change |
|---|---|---|
| `MushafReaderView.swift` | `1...849`, page labels, bookmark navigation | Navigate an edition's page manifest |
| `MushafReaderViewModel.swift` | Clamping/cache bounds of 849; Surah/Juz start pages | Edition-specific locations and metadata |
| Audio sync in the view model | Jumps to `Ayah.pageNumber` | Resolve verse fragments within the selected edition |
| `QuranDatabaseService.swift` / models | Ayah and search results carry a page number | Separate canonical text identity from edition location |
| `UserDatabaseService.swift` | Bookmarks/history use bare page numbers; last-read capped at 849 | Persist edition ID and stable location; migrate old data |
| `pipeline/build_db.js` / QA | Fixed page/row assumptions | Separate canonical-content validation from edition validation |
| Tests and `.github/workflows/build-ipa.yml` | Fixed 849-page fixtures/screenshots | Edition-aware fixtures and visual/interaction checks |

Preserve canonical verse identities, translations, FTS, and recitation URLs. Do not rebuild canonical text from OCR of scans.

The current selection path deliberately avoids jumping backwards when a continuation is touched. Preserve that behavior. For audio, prefer the current page when it contains the playing verse; otherwise navigate to an appropriate page in the selected edition. A verse-to-page relation must support multiple pages. Verse-level audio alone cannot precisely time transitions between fragments of the same verse.

Legacy ayah bookmarks can be remapped through canonical verse identity. Page-only bookmarks and last-read positions cannot be translated perfectly across editions: preserve their original edition/page and use a documented verse-anchor approximation if migration is requested. Never silently reinterpret old numbers. Reading history should retain its original edition identity.

## 4A. Additional integration findings confirmed while preparing the implementation plan

These are current-code observations, not results from running the iOS app:

- **Playback entry point is incomplete:** `AyahActionSheetView.swift` accepts `onPlay` but does not render a Play action. The callback supplied by `MushafReaderView.swift` only dismisses the sheet; it does not call `AudioPlayerService.play`. The image migration must explicitly wire a real playback action and test it.
- **Search UI is not connected in the inspected view:** `IndexHubView.swift` defines `searchContent`, but its body only chooses Surahs/Juz/Pages and has no search field wired to `updateSearch`. The repository and view model contain search support; the implementation must expose it, not merely change its destination type. Its existing search callback carries `result.pageNumber`, which is legacy-edition metadata.
- **More bare-page consumers exist:** `QuranApp.swift` validates diagnostic page arguments against 849, `RootTabView.swift` routes index/search using integer pages, `PageJumpView.swift` hard-codes the input range, and the bookmark views, Ayah sheet, navigation rows, and Settings show legacy page/layout information. These must be included in the migration scope.
- **Downloaded audio already has a local-first path:** `AudioPlayerService.play` checks `AudioStorageLocator.fileExists` before using a remote URL. Preserve this path and the existing audio download manager. Image bundling neither requires rewriting audio storage nor makes undownloaded recitations available offline.
- **Actual build configuration differs from aspirational comments:** `project.yml` sets Swift 5.9 for app/test targets, and `Package.swift` uses tools version 5.9. Do not assume the repository already builds in Swift 6 language mode. Develop concurrency-safe new code and verify complete strict-concurrency checking; treat a whole-project language-mode migration as separate work.
- **Runtime checksum verification is not established by the Settings label:** the inspected `QuranDatabaseService` opens the SQLite file read-only but does not verify a SHA-256 digest at initialization. The pipeline audit does verify the canonical database checksum. Any new edition integrity indicator must reflect actual runtime verification rather than a hard-coded “Verified” label.
- **Resource packaging needs explicit treatment:** the XcodeGen project recursively includes `QuranApp`, while SwiftPM processes `Resources`. A nested edition directory cannot be assumed to survive both packaging paths identically. Add folder-preserving configuration and a packaged-resource lookup test.

## 5. Alternatives

| Option | Advantages | Disadvantages / conditions | Assessment |
|---|---|---|---|
| **1. Improve current Core Text rendering** | Small bundle; preserves current pagination and text accessibility; lowest asset dependency | Does not supply missing artwork or exact calligraphy; ongoing approximation work | Useful fallback/accessibility reader, not the facsimile solution |
| **2. Qamar original images + repaired maps, as its own edition** | Authentic reference appearance; most mapping work already exists; measured source payload is modest | 847 Quran-bearing pages, not 849; license scope needs confirmation; 720px limits large-screen/zoom quality; map defects and full QA remain | Fastest credible prototype; conditional production fallback |
| **3. Licensed native-resolution artwork for the exact chosen edition + verified coordinates** | Best fidelity without invented detail; can preserve the 849-page contract if Qudratullah is selected; supports future resolution variants | Source acquisition and mapping/review effort; native detail and rights must be established | **Best production approach** |
| **4. Exact vector facsimile / edition-specific glyph system** | Sharp at any scale; potentially efficient assets and precise geometry | Requires actual vector masters or extensive expert reconstruction and proofreading; arbitrary font shaping is not equivalent | Strong long-term option if vector masters exist, otherwise excessive for this milestone |

AI super-resolution is **not** recommended as a fifth production option. Apparent sharpness is not verified fidelity: small dots, vowels, stopping signs, and color edges can be changed. Ordinary interpolation is acceptable as a display operation, but should not be represented as recovered source resolution. Lossy compression also needs small-mark validation; preserve lossless source masters.

## 6. Recommended target design

Separate the system into:

1. **Canonical content:** surah/ayah identity, trusted Arabic text, translations, search, audio.
2. **Edition manifest:** edition ID/version, publisher/provenance/license, ordered page IDs, source asset IDs, printed labels, Quran ordinals where applicable, page dimensions, hashes, and supplementary-page classification.
3. **Page/verse fragments:** page ID, canonical verse key, fragment order, validated rectangle/polygon, and coordinate-space definition. Keep non-verse regions explicitly typed. A page can contain both Quran and supplication material.
4. **Presentation:** image + selection overlay + semantic accessibility elements, sharing one transform.

Implementation principles:

- Keep the existing SwiftUI reader structure where practical; replace the facsimile page surface, not the whole application.
- Do not nest a complete scanned border inside the old synthetic ornamented frame.
- Begin with a few representative licensed pages. Add zoom/pan only with explicit paging/long-press gesture arbitration; respect Reduce Motion.
- Keep canonical text for VoiceOver, copy, search, and a Dynamic Type-friendly text/translation mode. An image is not an accessibility replacement.
- Theme surrounding chrome; do not blindly invert/recolor Tajweed scans. Preserve printed color semantics.
- Load page metadata and regions before interaction; hit-test cached regions synchronously rather than querying SQLite during every gesture update.
- Decode/downsample images off the main actor, sized for display pixels and zoom policy. Keep a bounded current/neighbor cache with cancellation and stale-load protection.
- Benchmark native-supported PNG/HEIF or a verified WebP decoding path before choosing a format. Compression percentages and frame rates must be measured, not promised.
- Rough RGBA decoded memory: 720×1057 ≈ 2.9 MiB, 1440×2114 ≈ 11.6 MiB, 3301×5100 ≈ 64.2 MiB per image. Compressed bundle size does not describe runtime memory. Three full-resolution 3301×5100 images alone approach 193 MiB, excluding other overhead.
- No need to commit to Metal tiling up front. Start with appropriately downsampled images; consider tiled high-resolution zoom only if profiling justifies it.
- Bundle the complete baseline edition for first-launch offline reading. An optional verified HD pack is a later optimization, with checksums, atomic installation, and a baseline fallback. This does not imply that existing streamed audio becomes offline.

The document's 200 MB “OTA cap” is not a current hard iOS app limit. Apple lists a **4 GB maximum uncompressed iOS/iPadOS app size**; cellular download behavior is configurable. Download size remains a UX concern, but the claimed cap does not justify AI upscaling or establish the proposed WebP sizes.

## 7. Gated execution plan

### Gate 1 — Decide what “authentic” means for this product

- If **849-page Qudratullah pagination is contractual**, source matching artwork. Do not substitute Qamar.
- If **the Qamar reference appearance is contractual**, formally adopt its page sequence and disclose changed pagination.
- Record edition identity, provenance, native resolution, supplementary content, and distribution rights before committing to the asset pipeline.

### Gate 2 — Prove the smallest complete slice

Use both opening pages, an ordinary dense page, a Surah boundary, a Juz boundary, a cross-page verse, the final mixed Quran/supplication page, and a supplication-only page. If using Qamar, also include source `522` and its neighboring verse regions.

Validate image/overlay alignment, letterbox rejection, rotation, compact/large screens, long press, audio navigation, copy/translation, VoiceOver, and any zoom transform. These tests exercise the risky architecture before importing an entire edition.

### Gate 3 — Validate and import the complete edition

- Deterministic manifest/import with source and output hashes.
- All 6,236 canonical verse keys represented by valid regions; all assets decodable.
- No zero-area/out-of-bounds regions, unexpected canonical keys, omitted/duplicated page assets, or unexplained overlaps.
- Correct fragment ordering and cross-page associations.
- Visual review of overlays and printed content by qualified readers; automated checks are not a substitute for that review.
- No Quranic translation/audio actions attached to supplication, decoration, or introductory `surah:0` regions.

### Gate 4 — Migrate and verify the application

Replace hard-coded page bounds, edition-specific start-page metadata, audio/search navigation, persistence, and test fixtures. Preserve old bookmark/history meaning. Run native tests and screenshot comparisons against the selected edition, then profile real devices for decoding, paging hitches, memory, and 120 Hz behavior where supported.

**Do not delete the current renderer until the image reader clears these gates.** It remains useful as a development fallback and accessible text mode, not as a way to conceal missing image pages.

## Evidence and sources

Local reproducibility:

```bash
node pipeline/temp/authentic-audit/audit.cjs
node pipeline/qa_audit.js
```

The temporary audit uses the locally installed `pipeline/node_modules/sqlite3` package and reads the content database read-only. Results: `pipeline/temp/authentic-audit/local-audit.json`. APK SHA-256: `a48644f6735ac690130d449577a0c44c4fc981533f489974f0446beff1a629a3`.

Temporary evidence files include `qamar-license.html`, the extracted APK `aboutus.html`, `qul236.html`, `qul313.html`, `archive-original-part.pdf`, and `apple-size2.html` under `pipeline/temp/authentic-audit/`. These ignored research files are not a committed production pipeline.

Primary external sources:

- [Qamar public license](https://www.qamarapps.com/license)
- [CC BY-SA 4.0 legal code](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en)
- [QUL 236 — Qudratullah 13-line](https://qul.tarteel.ai/resources/mushaf-layout/236)
- [QUL 313 — Taj Company 13-line](https://qul.tarteel.ai/resources/mushaf-layout/313)
- [Quran.com Mushaf metadata](https://api.quran.com/api/v4/mushafs): inspected listing did not expose a 13-line image edition; this is not proof that no private/future resource exists.
- [Quran Android issue 688](https://github.com/quran/quran_android/issues/688): historical discussion, not proof of today's exhaustive source availability.
- [Inspected GitHub asset-repository lead](https://github.com/dalcanciaa/quran-13-line-assets): the inspected repository root contained only `README.md`, not the claimed ready-to-import image/map pack. GitHub searches performed during this audit did not establish a rights-cleared complete pack; this is not an exhaustive proof that none exists.
- [Archive candidate metadata](https://archive.org/metadata/13-line-quran-with-beautiful-color-coded-tajweed-rules-pdf)
- [Archive large-font metadata](https://archive.org/metadata/holy-quran-13-lines-with-big-font_20201219)
- [Archive q13sa metadata](https://archive.org/metadata/q13sa)
- [Archive qip13 metadata](https://archive.org/metadata/qip13)
- [Apple maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)
- [Apple App Store settings](https://support.apple.com/guide/iphone/manage-purchases-subscriptions-settings-iph3dfd91de/ios)

QUL's inspected 13-line previews expose SQLite/DOCX download links, not an advertised ready-to-use image/coordinate pack; downloads require login. Neither QUL nor Archive has been established here as a rights-cleared, fully mapped high-resolution source for this app.
