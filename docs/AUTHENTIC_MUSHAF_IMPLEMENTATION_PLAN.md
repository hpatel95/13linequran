# Authentic Mushaf — Detailed Implementation Plan

**Status:** specification, not completed implementation.

**Audience:** coding agents executing small, independently testable changes, including smaller-context LLMs.

**Decision basis:** [AUTHENTIC_MUSHAF_AUDIT.md](AUTHENTIC_MUSHAF_AUDIT.md). This plan and the audit supersede conflicting instructions in `AUTHENTIC_MUSHAF_ARCHITECTURE.md`, especially its pagination conversion, coordinate formula, upscaling proposal, and unconditional licensing assumptions.

## 1. Execution rules

1. This is a documentation deliverable. Its existence does not mean application changes, native tests, source approvals, or content review have occurred.
2. Read sections 1–5 and the contract appendices before implementing. Execute P00–P18 in order, except where dependencies explicitly permit fixture-only work.
3. Complete one task or numbered subtask per increment. Update a progress log with changed files, commands/results, blockers, and next task. Do not rewrite the whole reader in one pass.
4. Paths marked **NEW** are proposed files. Commands invoking those files work only after their implementation task creates them.
5. Preserve unrelated changes and pre-existing untracked files, including the APK, extracted `assets/`, screenshots, and original architecture document.
6. Keep existing canonical and legacy-renderer tests. Add facsimile-specific tests rather than weakening assertions until the new system passes.
7. Windows can run Node/SQLite checks. Xcode builds, XCTest, simulator interaction, VoiceOver, and device profiling require macOS/hardware. Record unavailable checks as **pending**, never passed.
8. Do not invent verse IDs, page correspondence, rights approval, native resolution, reviewer names, or performance results.
9. A blocked source does not block fixture-driven engineering. It does block production ingestion/distribution of that source.
10. No application default changes until the release gates in section 8 pass.

### Two completion tracks

- **Engineering:** models, synthetic fixtures, importer, geometry, persistence, renderer, navigation, tests.
- **Content/release:** approved edition identity and rights, complete artwork, verified maps, qualified human review, packaging and hardware acceptance.

Engineering completion alone is not authorization to ship a facsimile reader.

## 2. Fixed decisions and approval gates

| Topic | Required decision |
|---|---|
| Canonical data | Preserve existing ayah IDs, Arabic, translations, FTS, verse numbering, and audio filenames. No OCR replacement. |
| Edition data | Add a separate read-only `mushaf_editions.sqlite`; do not change `quran_content.sqlite` for this milestone. |
| Default source target | Licensed native-resolution artwork matching the exact required **Qudratullah 849-page** layout. |
| Alternative | Adopt Qamar's **847 Quran-bearing-page** edition only after explicit pagination and rights approval. |
| Legacy renderer | Retain Core Text as an explicitly named legacy edition and accessible fallback, not a silent substitute for missing image pages. |
| Artwork | Original or losslessly prepared PNG baseline; no generative enhancement, speculative WebP savings, or mandatory Metal tiling. |
| Coordinates | Normalized `[0,1]`, top-left origin, X right, Y down; one transform for display, hit testing, and accessibility. |
| Initial interaction | Native RTL pager, aspect-fit artwork, location-aware hold, tap chrome, verse highlighting, accessible text alternative. Zoom is a later task. |
| Offline | Bundle a complete approved baseline edition. Optional HD downloads are not required for this release. |
| Persistence | Store edition/page identity; preserve legacy meanings; never reinterpret old page integers as new-edition pages. |
| Dependencies | Reuse native SQLite3 and ImageIO. Do not migrate to GRDB simply because it is declared. |
| Swift | Project currently uses Swift 5.9. Check new code with complete strict concurrency; keep a whole-project Swift 6 migration separate. |

### Pivotal human decision

Create **NEW** `docs/mushaf/EDITION_DECISION.md` with:

```text
Status: BLOCKED | APPROVED
Approved by/date/evidence:
Chosen immutable edition ID:
Exact publisher/print or digital edition:
Recitation and verse-numbering convention:
Quran-bearing page count:
Included front matter/supplementary pages:
Existing 849-page compatibility evidence, if claimed:
Approved migration and user communication policy:
Artwork source/archive SHA-256:
Coordinate source/version:
Native-resolution evidence:
Rights scope for these exact images AND maps:
Attribution/license/modification/ShareAlike obligations:
Distribution-channel review:
Qualified reviewers and review process:
Unresolved items:
```

Leave unknown fields unresolved. Copyright and a CC grant can coexist; neither the APK notice nor the public license page alone settles the scope for these exact assets. Archive hosting and age claims do not establish permission. Keep private correspondence outside publicly distributed resources.

### Audited facts that must survive implementation

- Qamar: 853 PNGs, 852 HTML files, 847 mapped pages, source IDs `004`–`850`.
- `851.png` is supplementary material, not an extra canonical verse-map page.
- Source `522` has zero-area regions for **26:143 and 26:144**. Do not simply omit or fabricate them.
- 700 canonical verses span multiple Qamar source pages.
- A constant offset does not map Qamar to the current 849 pages.
- Large Archive derivative dimensions do not prove native detail.
- Baseline pipeline audit was **51/51** during the audit. This validates current data/layout assumptions, not facsimile fidelity or future changes.
- The original proposal's 200 MB hard OTA limit, bundle estimates, and frame-rate promises are not release criteria.

## 3. Identity and runtime architecture

### 3.1 Required vocabulary

| Field | Meaning |
|---|---|
| `VerseKey` | Canonical positive `(surah, ayah)`; never ayah zero. |
| `editionID` | Stable identity of one particular page layout/edition. |
| `contentVersion` | Asset/map revision that does not change page identity. |
| `pageID` | Stable key within an edition, not array position. |
| `navigationIndex` | 1-based order of all included pages. |
| `quranOrdinal` | 1-based order of Quran-bearing pages; null on supplementary-only pages. |
| `printedLabel` | Verified printed label, nullable string; not an inferred index. |
| `sourceAssetID` | Unchanged source string; `00`, `000`, and `004` remain distinct. |
| `ReaderLocation` | Edition ID, page ID, optional canonical verse anchor. |
| `readingOrder` | Order of distinct canonical verses on a page. |
| `fragmentOrder` | Order of one verse's rectangles within one page. |

Reserve `legacy-qudratullah-13-849` for current text pagination, with page IDs `q0001`–`q0849`. A new image edition receives a separate human-approved ID, even if it also has 849 pages. Changed pagination requires another edition ID; revised coordinates or geometrically identical resolution variants may increment `contentVersion`.

The UI displays **Quran page N of M**, plus an optional verified printed label. Supplementary pages display titles, not invented Juz/Quran ordinals. Page jump explicitly targets Quran ordinals; supplementary navigation is separate.

### 3.2 Component ownership

```text
Canonical repository (existing)
  IDs, Arabic, translations, search, audio identity, legacy text layout
       |
Edition repository + legacy adapter (new)
  pages, memberships, regions, Surah/Juz anchors
       |
ReaderLocationResolver (new)
  typed destinations -> validated edition-aware locations
       |
MushafReaderViewModel (refactored, @Observable @MainActor)
  current location, selection, audio following, windowed page state
       |
Legacy page view OR AuthenticMushafPageView
                      |
               Image loader actor + image canvas
                      |
               shared image geometry and semantic elements
```

Do not put image methods into `QuranRepositoryProtocol` merely to reuse its name. Do not put UIKit/SQLite handles in domain models. New repository methods are `async throws`; no empty-success defaults to conceal unimplemented mock methods.

### 3.3 Resource layout

```text
QuranApp/Resources/MushafEditions/
  catalog.json
  mushaf_editions.sqlite
  notices/<editionID>.txt
  editions/<editionID>/v1/manifest.json
  editions/<editionID>/v1/pages/<asset>.png
```

Catalog includes schema version, canonical DB hash, sidecar hash, edition/content versions, manifest hashes, and approved default edition ID (null while legacy-only). Manifests contain exact asset paths, dimensions, and hashes. All paths are relative to this root, not constructed from a user-entered page number.

Reject absolute paths, `..`, backslashes in portable manifests, drive prefixes, URL schemes, empty path components, symlink escapes, and case-folded duplicates. Do not bundle raw APKs, executable source HTML/JavaScript, private correspondence, or unapproved scans.

### 3.4 Existing files to change

| File/group | Specific integration requirement |
|---|---|
| `QuranApp/App/QuranApp.swift` | Bootstrap catalog/user migration/resolved location; replace 849-only diagnostic arguments. |
| `QuranApp/App/RootTabView.swift` | Inject shared services; route typed index/search/bookmark destinations. |
| `QuranApp/Domain/Models/QuranModels.swift` | Preserve canonical models; label existing page fields as legacy metadata. |
| `QuranApp/Domain/Models/UserModels.swift` | Add typed V2 location/bookmark/session models without reinterpreting old fields. |
| `QuranApp/Domain/Database/UserDatabaseService.swift` and protocol | Transactional V2 storage and migration; eliminate bare-page methods from production call sites. |
| `QuranApp/Features/Reader/MushafReaderViewModel.swift` | Typed location, edition-aware windowing, cancellation, selection/audio separation. |
| `QuranApp/Features/Reader/MushafReaderView.swift` | Manifest-driven pager, dynamic labels, load/error states, working playback callback. |
| `QuranApp/Features/Reader/AyahActionSheetView.swift` | Actual Play control, trusted text actions, resolved location label. |
| `QuranApp/Features/Reader/MushafPageView.swift`, `Rendering/MushafText*` | Keep for named legacy renderer. Preserve its geometry/interaction tests. |
| `QuranApp/DesignSystem/Components/QuranPageFrame.swift` | Legacy use only; no synthetic border around full scans. |
| `QuranApp/Features/Navigation/IndexHubView.swift`, `IndexViewModel.swift` | Connect search UI and replace legacy page destinations/labels. |
| `QuranApp/Features/Navigation/PageJumpView.swift` | Dynamic Quran ordinal range and supplementary navigation. |
| Navigation row views | Stop displaying canonical models' legacy `startPage` as the active image edition's location. |
| `QuranApp/Features/Bookmarks/BookmarksListView.swift` and row views | Edition labels, typed current location, explicit cross-edition behavior. |
| `QuranApp/Features/Audio/AudioPlayerService.swift` | Preserve local-first audio; use canonical keys for page following. |
| `QuranApp/Features/Settings/SettingsView.swift` | Real edition/count/license/verification state; no hard-coded “Verified”. |
| Onboarding/help views | Remove misleading page-count/interaction claims if present. |
| `project.yml`, `Package.swift` | Preserve folder structure and isolate fixture resources. |
| `.github/workflows/build-ipa.yml` | Separate test reporting and production content release gates. |
| `pipeline/build_db.js`, `qa_audit.js` | Preserve canonical/legacy invariants; add separate edition tooling. |

## 4. Implementation tasks

### P00 — Baseline and progress log

**Dependencies:** none.

1. Read audit, build configuration, relevant skills, and exact interfaces before editing.
2. Run `git status --short`; record unrelated changes. Never stage everything indiscriminately.
3. Run `node pipeline/qa_audit.js`. Install existing dependencies with `npm ci --prefix pipeline` if necessary.
4. Inventory assumptions:

```bash
rg -n '849|847|848|850|pageNumber|startPage|currentPage|last_read_page' QuranApp Tests pipeline .github
rg -n 'onPlay|searchContent|updateSearch|SHA-256 Verified' QuranApp
```

5. Create **NEW** `docs/AUTHENTIC_MUSHAF_IMPLEMENTATION_PROGRESS.md` with baseline environment, task status table P00–P18, decisions, commands/results, blockers, and next action.
6. On macOS, establish a native baseline before feature changes. Record pre-existing failures separately.

**Done:** reproducible baseline and inventory recorded. **Stop:** canonical integrity failure; do not rebuild a different Quran silently.

### P01 — Source decision and rights register

**Dependencies:** P00. May remain blocked while fixture engineering continues.

1. Create the decision document in section 2 and **NEW** `docs/mushaf/SOURCE_REGISTER.md`.
2. Register each candidate's source path/URL/hash, exact edition claims, rights evidence, native-resolution evidence, map availability, and approval state.
3. Ask prospective licensors for the complete exact page set, matching coordinate data if available, distribution/modification terms, notices, and supplementary-page coverage. Do not assume willingness to license.
4. Keep Qamar and QUL sampled similarities as evidence, not proof of complete word-level equivalence.

**Done:** explicit blocked/approved decision. **Fallback:** synthetic fixtures and legacy production; no unapproved public artifact.

### P02 — Models, manifest validator, safe fixtures

**Dependencies:** P00.

**NEW:**

```text
QuranApp/Domain/Models/MushafEditionModels.swift
QuranApp/Domain/Models/ReaderLocationModels.swift
pipeline/mushaf/manifest.schema.json
pipeline/mushaf/generate_fixtures.cjs
pipeline/mushaf/test/
pipeline/mushaf/fixtures/
```

1. Implement immutable validated models from Appendix A; `Hashable`, `Sendable`, and `Codable` where persisted.
2. Implement strict manifest validation. A JSON schema file is documentation unless the executable validator enforces it.
3. Use self-authored PNG shapes/grids, explicitly labeled in test UI **SYNTHETIC — NOT A MUSHAF**. Do not fabricate Quran calligraphy or depend on unapproved scans.
4. Required fixtures: two keys sharing a row; two disjoint fragments of one key; cross-page continuation; mixed verse/non-verse page; supplementary-only page; two editions with identical ordinal numbers but different memberships.
5. Required invalid fixtures: zero area, out-of-bounds/nonfinite values, unknown key, absent image, wrong dimensions/hash, duplicate page/ordinal, traversal, duplicate case-folded paths, differing-key overlap, incomplete production coverage.
6. Tiny fixtures may be checked-in self-authored PNGs or generated with Node built-ins; avoid an unnecessary image dependency.
7. Add `test:mushaf` using Node's built-in test runner to `pipeline/package.json`. Its existing placeholder `npm test` is not an audit suite.
8. Partial coverage is accepted only under explicit `--fixture`; release validator rejects fixture editions.

**Done:** every invalid fixture fails for its intended reason; model coding round trips pass.

### P03 — Deterministic importer and inspection

**Dependencies:** P02; source-specific use needs P01 permission appropriate to that use.

**NEW:** `pipeline/mushaf/schema.sql`, `inspect_source.cjs`, `import_edition.cjs`, `validate_edition.cjs`, `build_catalog.cjs`, and small `lib/` helpers.

1. Open canonical DB read-only; load canonical IDs/keys and calculate its hash.
2. Validate the entire input manifest and permitted asset paths before writing output.
3. Verify file sizes, native/oriented dimensions, hashes, memberships, anchors, and region geometry. PNG header inspection alone is not complete decode validation; include native ImageIO validation later.
4. Normalize source-pixel rectangles exactly once (`x/W`, `y/H`), retaining Double precision. Preserve original source IDs/region IDs and correction provenance.
5. Build a new staging directory and SQLite file. Enable foreign keys; use one transaction and deterministic insertion ordering. Use bound SQL parameters.
6. Run structural checks, `PRAGMA integrity_check`, and `PRAGMA foreign_key_check`. Close/checkpoint journals so the output does not require an unbundled WAL file.
7. Emit deterministic manifests/hashes. Keep volatile build timestamps outside hashed content.
8. Replace last known-good output only after success. Failure leaves previous output intact.
9. Import twice; compare logical dumps/manifests and, on the same pinned SQLite version, DB bytes. Do not promise cross-version SQLite byte identity.

**Qamar-specific adapter:**

- Parse HTML as inert data; never execute source scripts.
- Require six-digit `rel`: three-digit surah plus three-digit ayah. Validate positive keys against canonical data. Map `SSS000` to noncanonical Bismillah regions, not ayah zero.
- Test attribute order, quoting, whitespace, missing/duplicate fields, malformed rectangles, and unsupported forms. Fail closed rather than guessing.
- Preserve source IDs as strings. Do not rely on `pipeline/compare_mapping.js` or copy the temporary audit ZIP parser blindly.
- Extraction can use installed `unzip` via `execFile` with exact validated entry names, no shell interpolation. Inventory first; reject duplicate/unexpected paths; cap per-file/total extraction; write only to staging. If unavailable, accept a separately verified extracted directory instead of improvising a ZIP implementation.
- `004`–`850` form an explicit 847-Quran-page sequence **inside Qamar**, not a crosswalk to legacy pages. If `851` is appended as supplementary material, this trimmed selection has 848 navigation pages. Other inclusions/exclusions require manifest entries and review.
- Do not infer printed labels from filenames. Do not upscale images.

**Done:** repeatable valid fixture package; bad import cannot overwrite good output. **Stop:** missing/malformed regions or unexplained source count changes.

### P04 — Human coordinate review and corrections

**Dependencies:** P03; production approval requires P01.

**NEW:** `pipeline/mushaf/export_review.cjs`, `docs/mushaf/CONTENT_REVIEW.md`, versioned correction records.

1. Export local static source-image/SVG overlays with region IDs, canonical keys, image/map hashes, and original coordinates. Escape labels; do not embed executable source HTML.
2. Produce review index: coverage, invalid/overlapping regions, continuations, Surah/Juz anchors, and unreviewed pages.
3. For an edition without maps, manually annotate native images in a local tool, per verse fragment. OCR may suggest work items, never final canonical text or unreviewed ownership.
4. Maps from lower-resolution copies can transfer only after confirming identical artwork and registering crop/deskew/scale using multiple landmarks. Different editions cannot be repaired by scaling.
5. Qamar `522`: qualified review must locate 26:143/144 and inspect neighboring ownership, including 26:142/145. Tiny arbitrary rectangles are not repairs.
6. Store patches separately: source hashes, exact region ID, before/after coordinates, operation, rationale, reviewer/reference. Apply only if hashes and before-values match. Never mutate original source files silently.
7. Re-run all validation after corrections. Track structural approval, visual artwork review, map ownership review, and scholarly review separately.

**Done:** reviewable provenance and signed-off production maps. **Fallback:** edition stays release-disabled; local debug image-only preview may disable all verse actions with a visible warning.

### P05 — Edition repository, legacy adapter, resolver

**Dependencies:** P02/P03; fixtures suffice.

**NEW:** under `QuranApp/Domain/Database/`: `MushafEditionRepositoryProtocol.swift`, `MushafEditionDatabaseService.swift`, `LegacyMushafAdapter.swift`, `ReaderLocationResolver.swift`.

1. Implement actor-isolated read-only SQLite access, bound queries, statement finalization, and explicit error handling. `sqlite3_step` errors are not end-of-results.
2. Implement contracts in Appendix A and their fixture tests.
3. Legacy membership comes from all `mushaf_lines.words_json` entries, not only `ayahs.page_number` (first occurrence). Deduplicate keys in reading order; preserve continuations.
4. Generate/cache lightweight legacy page metadata once. Support legacy startup even if no facsimile package is available.
5. Surah/Juz anchors resolve canonical start verse keys in each edition. Existing integer start pages are only legacy regression checks.
6. Resolver policies: exact saved location stays exact; explicit verse search starts at first occurrence; audio prefers current page if it contains the playing verse. Missing mapping is a typed error, never a legacy-page fallback.
7. Keep image/region data windowed; all page summaries may be loaded as lightweight metadata.

**Done:** two-edition and continuation tests pass; legacy remains 849 pages; supplementary pages resolve without fake verse identity.

### P06 — Resource packaging and integrity

**Dependencies:** P03/P05.

**NEW:** `QuranApp/Domain/Resources/MushafResourceLocator.swift`, `MushafResourceErrors.swift`.

1. Inject a root URL in tests. Production resolves only the bundled folder root, not a developer source-tree fallback.
2. In `project.yml`, exclude the new subtree from broad recursive resource discovery and add it once as a folder-preserved resource entry. Verify installed XcodeGen syntax (`type: folder`, resource build phase) against generated output.
3. In `Package.swift`, preserve current database/fonts while copying `Resources/MushafEditions` as a directory rather than flattening it. Use `Bundle.module` only under `#if SWIFT_PACKAGE`; app packaging tests exercise the app bundle.
4. Unit fixtures belong in the test bundle. UI fixtures need a separate DEBUG-only resource/configuration path. Release checks must reject fixture catalogs/assets, not merely hide their menu entry.
5. Verify catalog→sidecar and catalog→manifest hashes during bootstrap; verify each image against manifest before first display. Cache process-local verification by immutable hash/path. Verify canonical DB hash off main actor.
6. Test lookup of a deeply nested image, notice, catalog, and DB in the built product. Reject duplicate copies/case collisions/unexpected files.
7. Bundled hashes detect mismatch/corruption; do not claim this is a secure remote-download signing protocol.

**Done:** native packaged-resource lookup succeeds without source fallback; corrupted fixtures fail clearly; Release has no unapproved/test assets.

### P07 — Geometry and bounded image loading

**Dependencies:** P02/P05/P06.

**NEW:** `QuranApp/Features/Reader/Rendering/MushafImageGeometry.swift`, `QuranApp/Domain/Resources/MushafImageLoader.swift`.

1. Implement Appendix B's pure transform and hit testing before UI work.
2. Use ImageIO thumbnail decoding on a dedicated actor/executor, not main-actor `UIImage(contentsOfFile:)`.
3. Target displayed image points × display scale, round to a modest pixel bucket (initially 256px increments), cap at native resolution. Never upscale the file.
4. Disable full-source caching; create transformed thumbnails with immediate decode on the decode executor. Validate dimensions/aspect ratio allowing integer thumbnail rounding.
5. Cache by edition/content version/page/hash/pixel bucket; charge actual `bytesPerRow * height`. Initial configurable budget: 48 MiB, to be revised by measurements.
6. Keep current/neighbor images, one or at most two concurrent decodes, current-page priority, coalesced duplicate requests. Cancel obsolete queued prefetch; discard stale in-flight results.
7. Memory warning: evict neighbors; background: cancel prefetch. On memory/decode pressure, retry once at smaller bucket, then explicit error. Never retry forever.
8. `Task {}` in a main-actor VM does not move synchronous decoding off main. No broad unchecked Sendable/global mutable caches. If SDK annotations require it, use only a narrowly documented immutable CGImage wrapper; never mark UIKit objects/the entire loader unchecked.
9. Add injectable decoder/clock and debug counters for decode count, cached bytes, queue length, stale discards.

**Done:** transform, cache, concurrency, corrupt-image, and native decode tests pass. Selection/theme changes do not decode again.

### P08 — Facsimile page and accessible text mode

**Dependencies:** P07.

**NEW:** `AuthenticMushafPageView.swift`, `MushafPageTextView.swift`, `MushafPageErrorView.swift` in the reader feature; `Rendering/MushafImageCanvas.swift`.

1. SwiftUI owns page/chrome/sheet state; a `UIViewRepresentable` bridges a main-actor image canvas for location-aware native hold and UIAccessibility, following the existing renderer's established bridge pattern.
2. Display full aspect-fit image, no synthetic border/13-row grid/cropping. Keep canvas coordinates LTR while outer pager is RTL; never mirror Arabic pixels.
3. One shared geometry instance drives image placement, per-fragment overlay paths, and accessibility frames. Recompute atomically on resize, never animate image/map independently.
4. Hold defaults: 0.4s recognition, 10pt movement allowance, one selection/haptic, no tap toggle after hold. Tap waits for hold failure; pager must not wait for hold timeout. Reject hold during ancestor dragging/deceleration or unavailable geometry.
5. A margin, decoration, Bismillah, or supplication hold must not open ordinary Quran verse actions.
6. Render subtle outlined/low-opacity highlights above opaque images. A layer behind the image is invisible. Validate that overlays do not obscure dots/Tajweed colors. No image inversion/recoloring in Dark Mode.
7. No I/O/SQL/decode in `updateUIView` or gesture callbacks. Update selected keys without recreating images/regions.
8. Accessibility: ordered unique verse elements on current page only, trusted Arabic/identity, activation to same action flow, selected trait, chrome/text-mode actions. Supplementary transcription must be reviewed, not invented.
9. Text mode uses validated memberships and trusted complete verses, explicitly notes continuations, supports Dynamic Type/translation/actions. If memberships are unavailable, offer canonical Surah/verse browsing rather than claiming to know page contents.
10. Explicit states: loading, ready, failed with Retry/Text view, edition unavailable. Never endless spinner or adjacent-page substitution.

**Done:** native fixture interaction, shared-row selection, margin rejection, geometry rotation, and accessibility tests pass.

### P09 — User storage migration

**Dependencies:** P02/P05. Follow Appendix C exactly.

**NEW:** `QuranApp/Domain/Database/UserDatabaseMigrations.swift`; update user service/protocol/models and all relevant mocks.

1. Add V2 tables/APIs and one transaction copying legacy data without reinterpreting page numbers.
2. Preserve IDs, notes, titles, snippets, dates, canonical identity, original page numbers, and historical sessions.
3. Mark legacy locations as `legacy-qudratullah-13-849`. Do not remap to the selected facsimile during schema migration.
4. Keep per-edition last-read state and separate preferred edition.
5. Run migration only when the app's production persistence call sites are ready to use V2; otherwise old writes would diverge after the snapshot.
6. Test on-disk old-schema files, migration reopen/idempotency, duplicates, malformed locations, Unicode notes, and injected transaction failure.

**Done:** V2 migration/CRUD and original legacy tests pass. **Stop:** migration failure leaves old DB intact, reports error, disables unsafe writes; never silently create an empty replacement.

### P10 — Reader state and pager migration

**Dependencies:** P05/P08/P09.

1. Keep VM `@Observable @MainActor`; use `@ObservationIgnored` for tasks/caches/generation counters.
2. Replace writable raw `currentPage` navigation with `currentLocation`, active edition, ordered summaries, and `navigate(to:reason:)`. Pager binding selects stable page IDs through validated navigation.
3. Resolve asynchronously with generation checks after every await. Commit destination once; avoid chains of `didSet`-launched work.
4. On genuine location change: cancel obsolete load/selection/translation tasks; clear inspected state unless navigation explicitly selects a verse; reset geometry/zoom; load current then adjacent pages; window content/cache; update bookmark state with captured full location.
5. Separate inspected verse/location from playing verse/audio-follow state. Playback never opens the sheet by itself.
6. Keep existing synchronous selected-key publication and async stale-translation protections. Add equivalent guards to page/image/audio/edition resolution.
7. Schedule last-read dwell save (initially 2s) with a captured location, not whatever page is current after an await. Flush valid current location on background where possible.
8. Replace `ForEach(1...849)` with page summaries. Heavy views stay within ±1; other items are lightweight. Full scanned page bypasses `QuranPageFrame`.
9. Surah/Juz labels derive from current memberships/anchors, never legacy start-page comparisons. Supplements have honest titles/no fake Juz.
10. Legacy renderer conversion is allowed only through the legacy adapter. Image source IDs are never interpreted as legacy pages.

**Done:** rapid A→B→C and edition switches cannot publish stale data; supplementary navigation works; legacy remains functional through V2 state.

**Fallback:** replace only the pager with `UIPageViewController` if native profiling proves `TabView` unsuitable. Record evidence; do not redesign cache/gestures simultaneously.

### P11 — Bootstrap, index, search, labels, bookmarks

**Dependencies:** P10.

1. Bootstrap canonical DB, user migration, verified catalog/legacy availability, and resolved initial location before constructing root reader state. Do not initialize at page 1 then expect later initializer arguments to update an existing `@State` VM.
2. Inject one shared repository/resolver/image loader through `RootTabView`, not separate caches per page.
3. Replace raw-page callbacks with typed Surah/Juz/Quran-ordinal/verse/exact-location intent. Search must ignore legacy `result.pageNumber` for image destinations.
4. Wire actual search UI in `IndexHubView`: its inspected body does not expose its existing `searchContent`. Bind a search field to the existing debounced/cancellable query path, display results/loading/error/empty states, select canonical key, resolve active edition, then inspect it.
5. Page jump validates `1...activeEdition.quranPageCount`, resolves ordinal explicitly, and shows error without clamping an invalid input. Supplementary entries are separate.
6. Resolve row/location labels for Surahs, Juzs, search, bookmarks, Ayah sheet, reader footer, settings, and launch diagnostics. Audit all `startPage`/`pageNumber` use after changes.
7. Page bookmark equality is `(editionID,pageID)`; verse bookmarks retain canonical identity globally. Cross-edition behavior follows Appendix C with user confirmation for approximation.
8. Surface persistence errors; do not optimistically leave a bookmark icon successful after a failed write.
9. Settings shows current edition/renderer, actual counts, offline asset status, notices/modifications, and actual verification state. Theme chrome, not scans.

**Done:** every entry point reaches the correct fixture-edition page, working search is visible, same ordinal in two editions is not conflated, old bookmarks remain readable.

### P12 — Wire playback and continuation-safe following

**Dependencies:** P10/P11.

**NEW:** `QuranApp/Features/Audio/ReaderAudioPlaybackProtocol.swift` if needed for a minimal fakeable interface.

1. Add a visible Play control to `AyahActionSheetView`. Its existing `onPlay` argument is not enough: the inspected view does not render the action, and reader callback only dismisses the sheet.
2. Play invokes canonical `(surah,ayah)` playback through the existing service, then dismisses according to current UI policy. Test actual service invocation, not only sheet disappearance.
3. Preserve `AudioStorageLocator.fileExists` local-first lookup and existing download manager. Image bundling does not make undownloaded audio offline.
4. `onVerseChanged` resolves active-edition memberships. If current page contains that verse, remain there, including on a continuation page; otherwise go to its first occurrence when follow mode permits.
5. A long verse has verse-level timing only: highlight visible fragments but do not pretend to time transitions between fragments/pages. User may turn pages; repeated callback must not jump backwards while that page still contains the verse.
6. Follow policy: manual page navigation pauses following and displays Resume following; opening the inspection sheet temporarily suspends page-turn following, preserving inspected state. Resuming resolves current playing verse. Do not hijack search/inspection with an audio race.
7. Guard stale audio resolution against edition/navigation changes. Do not send ayah-zero/supplication to audio APIs. Stop canonical sequencing at 114:6.
8. Existing auto-play/repeat settings must reach the service if the feature UI exposes them. Test a fake playback event stream, local/offline path, and errors.

**Done:** Play calls correct canonical key; cross-page continuation stays put; manual inspection is stable; supplementary content never becomes a fabricated track.

### P13 — Launch hooks, automated tests, and CI

**Dependencies:** P06–P12.

1. Keep `-mushafAutomatedRun` and old `-mushafInitialPage` for **legacy test compatibility only**. Add typed hooks `-mushafEditionID`, `-mushafPageID`, optionally `-mushafQuranOrdinal`, and DEBUG-only `-mushafFixtureCatalog`.
2. Explicit edition/page wins over legacy argument; conflicting/unknown inputs produce deterministic test failure/diagnostic, never silently fall back to page 1. Disable production access to arbitrary filesystem fixture roots.
3. Keep `ayah-sheet-key`; add stable page-surface, current-location, page-error, text-mode, and Play identifiers. Do not make every rectangle a visible tappable SwiftUI button just for tests.
4. Add test files listed in section 6 and all mandatory cases there.
5. Pipeline scripts expose explicit verify/import/fixture/release commands, meaningful nonzero exits, machine-readable reports. Tests must not need network or the local APK.
6. Add fixture pipeline checks and native test reporting to CI. Preserve the existing unsigned IPA job's intentional independence from test-harness failures, but **production publication/promotion** requires successful required tests and content approval. An artifact built with failing tests is not release-certified.
7. `check_release.cjs` rejects fixture/unapproved catalogs, missing notices/assets/hash mismatches, incomplete counts/review references, and facsimile-default enabled without approval. Legacy-only releases remain possible with facsimile disabled.
8. Validate packaged resources from the generated app/IPA, not just source paths. Keep canonical audit checks separate.

**Done:** clean checkout runs fixture checks offline; native test results recorded; release gate fails closed on deliberately invalid packages.

### P14 — Approved real-content slice

**Dependencies:** P01/P04 approval for intended use; P13.

1. Ingest a representative slice: both openings, dense ordinary page, Surah boundary, Juz boundary, cross-page verse, final mixed page, supplementary-only page. Include Qamar `522` if chosen.
2. Slice is a development fixture/package, never a complete production edition. Production full-coverage validation must reject it.
3. Review native images at fit size and pixel inspection; overlays against original artwork; canonical selection and audio; color/border/margin fidelity; compact/large portrait/landscape layouts.
4. Compare against the exact approved edition, not a screenshot from a different publisher. Keep source hash, device/OS, app build, renderer, and page ID with captures.
5. If native baseline is visibly too soft, return to source acquisition. Do not add AI upscaling to make the screenshot look sharper.

**Done:** documented slice approval and defect list. **Fallback:** engineering stays fixture-ready, production remains legacy.

### P15 — Full edition import and review

**Dependencies:** P14.

1. Import all approved included pages, assets, memberships, anchors, patches, and notices.
2. Require exact declared Quran/navigation counts, complete positive-area coverage of all 6,236 canonical keys, no extras, valid continuation ordering, all 114 Surah/30 Juz anchors, no unexplained geometry defects.
3. Review all artwork/page ordering and all coordinate ownership according to qualified-review procedure; sampling is a development gate, not final completeness proof.
4. Verify exclusions, cover/supplement classification, printed labels, source/native resolution, rights and modification notices.
5. Repeat import determinism and macOS decoder checks; record content version/hashes.
6. Reject a single missing page/invalid canonical region for the production facsimile package rather than silently switching only that page to the legacy layout.

**Done:** approved reproducible complete package and review references. **Stop:** unresolved rights, false edition equivalence, defects, or inadequate native detail.

### P16 — Hardware performance and accessibility acceptance

**Dependencies:** P15; P13 fixture tests should already pass.

1. Measure cold open, rapid 50-page navigation, repeated backtracking, selection, rotation, audio advance, memory warning/backgrounding, text mode, and long sessions on an older supported device and a modern high-refresh device.
2. Record Instruments allocations/hitches, image cache cost, actual peak process memory, decode latency, and unexpected main-thread work. Compressed PNG bytes are not decoded memory.
3. Initial engineering targets: no gesture-path I/O, no stale pages, bounded current/neighbor cache, no unbounded tasks, no repeatable decode-related main-thread stall. Set device-specific numeric launch/frame/memory budgets in the progress log after baseline measurement and before approval.
4. Do not claim 120 fps because a display supports it. Fix measured causes first: duplicate decode, observation invalidation, oversized images, stale prefetch, accessibility rebuilding.
5. Manually test VoiceOver order/actions, largest Dynamic Type in text mode/chrome, Reduce Motion, light/dark, contrast, 44pt controls, and supplementary accessibility limitations.
6. Test airplane-mode fresh launch and all baseline pages; downloaded audio must work, undownloaded audio must fail clearly without affecting reading.

**Done:** approved hardware/accessibility report with actual numbers. **Fallback:** lower decode bucket/window or postpone release; no invented performance promises.

### P17 — Rollout and rollback

**Dependencies:** P15/P16 and all required tests.

**NEW:** `QuranApp/Features/Reader/ReaderFeatureConfiguration.swift` and release notes/checklist if not already created.

1. Use one explicit configuration switch for production facsimile availability/default. DEBUG fixture enablement cannot bypass Release content checks.
2. Existing users keep legacy interpretation after schema migration. Offer an explained edition switch; new installs may default to the approved facsimile only after all gates pass.
3. Preserve per-edition last read. Confirm cross-edition page-only approximations; clearly label legacy text mode.
4. If reverting the same binary/configuration to legacy, keep V2 storage and facsimile locations intact. Resolve a separate legacy fallback only with explained canonical mapping; do not overwrite saved facsimile location with a guessed legacy page.
5. Older app binaries are not promised to see post-migration V2 writes. Retained legacy tables are a historical snapshot, not a bidirectional sync protocol. A supported binary downgrade needs a separately designed/export-tested path; do not claim it is solved.
6. Release record includes source/content hashes, human approvals, tests, device measurements, notices, resource inventory, and rollback steps.

**Done:** release checklist signed off. If any gate fails, ship legacy-only or postpone; do not relax validation.

### P18 — Optional zoom/HD packs (separate later milestone)

**Dependencies:** stable released baseline; explicit scope approval. Not required for P17.

- Zoom: use native `UIScrollView` physics, initially in a dedicated fullscreen page presentation so horizontal pager and zoom pan do not compete. At minimum zoom allow normal page behavior; above minimum disable page turns or use the dedicated view. Reset zoom per page. Invert the entire composed transform for touches; do not apply zoom twice after UIKit coordinate conversion. Test pinch interruption, pan, rotation, VoiceOver, Reduce Motion, and highlights at every scale.
- HD: accept only approved higher-native-resolution or losslessly equivalent artwork. Same normalized geometry is reusable only after registration proves identical content/crop. Different geometry requires versioned maps; different pagination requires a new edition ID.
- Download packs: manifest/hash verification, authenticated source, disk preflight, resumable background transfer, temporary staging, complete validation then atomic activation, cancellation cleanup, removal, and last-good baseline fallback. Design a real authenticity/signature model before accepting arbitrary remote manifests.
- Never activate a half-downloaded pack or overwrite bundled baseline. Asset download failure must not affect baseline reading. Profile larger decoded memory again.
- If this milestone is not approved, do not add empty pack-manager frameworks during initial work.

## 5. Failure and fallback matrix

| Failure | Required visible behavior | Forbidden shortcut |
|---|---|---|
| Source rights unresolved | Legacy production, synthetic engineering | Bundling APK assets “temporarily” in public builds |
| Exact 849 artwork unavailable | Ask for edition decision; retain legacy | Relabel Qamar's 847 as 849 |
| Zero-area/misowned region | Reject production package; human repair | Dropping key or inventing tiny box |
| Missing image/hash mismatch | Page error, Retry, validated text mode | Neighbor image or old-layout page under same label |
| Missing page membership | Canonical Surah/verse browser, explicit error | Guess page contents from first ayah metadata |
| Missing verse mapping | Error with requested verse; retain current page | Use legacy `Ayah.pageNumber` in image edition |
| Old edition unavailable | Show original location and offer explicit mapping/legacy | Silently clamp ordinal to new page count |
| Migration/write failure | Preserve data; error; disable unsafe writes | Reset user DB or pretend bookmark saved |
| Memory/decode pressure | Evict neighbors; one smaller retry; error | Unbounded retry/cache or file upscale |
| Supplement tapped | Supplement description/no Quran action | Invented ayah zero or audio track |
| Undownloaded audio offline | Clear playback error; reading unaffected | Promise all recitation is offline |
| Native tests unavailable | Mark pending; require macOS before release | Claim Node tests prove iOS behavior |
| Optional HD unavailable | Complete verified bundled baseline | Blank page pending download |

## 6. Mandatory test inventory

Create **NEW** tests; keep current `MushafLayoutTests`, `QuranIntegrityTests`, `UserDatabaseTests`, and legacy `MushafInteractionUITests`.

| New test file | Minimum assertions |
|---|---|
| `Tests/QuranAppTests/MushafEditionTests.swift` | Ordering/counts/anchors; unknown edition/page; key membership/region consistency; supplements; SQL error propagation. |
| `MushafImageGeometryTests.swift` | Exact numeric fit case; horizontal/vertical letterbox; outside taps; round trips; all corners; zero/nonfinite size; disjoint fragments; shared boundary; ambiguity; same normalized map at two resolutions. |
| `MushafImageLoaderTests.swift` | Real decode; corrupt/missing/wrong hash; aspect mismatch; request coalescing; edition/version isolation; bucket reuse; bounded byte cost; eviction; stale result; single retry. |
| `ReaderLocationResolverTests.swift` | Surah/Juz/search in both fixture editions; first vs current continuation; exact bookmarks; absent key; no legacy fallback. |
| `ReaderStateTests.swift` | Out-of-order page/translation/audio/edition completions; synchronous selection key; captured last-read save; bookmark failures; manual navigation suspends audio follow. |
| `UserDatabaseMigrationTests.swift` | Existing on-disk schema; reopen/idempotency; preserved IDs/notes/dates; duplicate retention; invalid location preservation; transaction rollback; edition-aware CRUD/last read. |
| `MushafImageAccessibilityTests.swift` | One element per key; canonical order; current page only; paths/frames update on resize; activation; non-verse exclusion. |
| `MushafResourcePackagingTests.swift` | Bundle-only catalog/DB/image/notice lookup; preserved nested paths; no source-tree fallback; missing bundle resource failure. |
| `Tests/QuranAppUITests/AuthenticMushafUITests.swift` | Shared-row right/left holds, continuation hold, swipe without accidental selection, margin/nonverse hold, chrome, rotation, text mode, Play invocation indicator using fake service, search, bookmark, supplementary page, error/retry, relaunch location. |

Use injected repositories, image decoder, playback service, and controllable clock/suspensions in `Tests/QuranAppTests/Support/`. Prefer expectations/explicit release of suspended operations to arbitrary sleeps. UI touch coordinates come from a known **individual fragment**, never a multi-fragment union center.

### Pipeline command interface to implement

After P02/P03/P13, these commands must exist and fail with useful diagnostics:

```bash
npm run test:mushaf --prefix pipeline
node pipeline/mushaf/generate_fixtures.cjs --output pipeline/temp/mushaf-fixtures
node pipeline/mushaf/import_edition.cjs --manifest pipeline/temp/mushaf-fixtures/manifest.json --canonical QuranApp/Resources/Database/quran_content.sqlite --output pipeline/temp/mushaf-fixture-package --fixture
node pipeline/mushaf/validate_edition.cjs --package pipeline/temp/mushaf-fixture-package --canonical QuranApp/Resources/Database/quran_content.sqlite --fixture
node pipeline/mushaf/check_release.cjs --package QuranApp/Resources/MushafEditions --mode facsimile
node pipeline/qa_audit.js
```

Confirm the existing canonical DB's exact resource path in P00; if it differs from the example, update these examples and scripts together. Do not create a second DB at the example path to make a command pass. `check_release --mode legacy` permits no installed facsimile and requires the production feature configuration to remain legacy-only; it still rejects accidentally bundled unapproved artwork.

Production import has no `--fixture` bypass. Source-specific private paths must be explicit command arguments/configuration, not developer-machine defaults.

### Native verification commands

On macOS, use the repository's generated project and actual scheme names:

```bash
xcodegen generate
xcodebuild -list -project QuranApp.xcodeproj
xcrun simctl list devices available
# Substitute an installed simulator UDID from the command above.
xcodebuild -project QuranApp.xcodeproj -scheme QuranApp -destination 'platform=iOS Simulator,id=<UDID>' test
xcodebuild -project QuranApp.xcodeproj -scheme QuranApp -destination 'platform=iOS Simulator,id=<UDID>' SWIFT_STRICT_CONCURRENCY=complete build
```

Confirm project filename from `project.yml`/generated output before invoking. Record exact executed commands without placeholders in the progress log. Keep stable `PRODUCT_MODULE_NAME = QuranApp`; do not rename it to the display product name. New code must not add strict-concurrency warnings; document pre-existing warnings rather than hiding them. SwiftPM checks alone do not replace the hosted iOS/UI tests.

## 7. Scope boundaries and agent handoff

Do not combine this work with canonical text replacement, redesigning audio downloads, changing FTS/tokenization, converting the whole project to Swift 6, adopting a new persistence library, a full settings redesign, custom pager physics, or speculative remote asset services.

At each handoff, write:

```text
Task/subtask completed:
Files changed:
Contracts preserved:
Commands actually run and results:
Native/human checks still pending:
Source/rights state:
Known failures and why they are not concealed:
Next smallest task:
Do-not-touch unrelated work:
```

A smaller agent can be prompted: “Implement only Pxx, using the contracts in this plan. Read the progress log and named source files. Do not choose a production edition, guess geometry, change canonical data, or mark unavailable tests passed. Stop at the task acceptance boundary and update the log.”

## 8. Release completion checklist

### Engineering

- [ ] Canonical database/text/IDs unchanged and legacy checks passing.
- [ ] Typed edition/page locations used by reader, search, Surah/Juz, page jump, bookmarks, last read, history, audio, and diagnostic hooks.
- [ ] Real search UI and Play action connected and tested.
- [ ] Shared geometry, strict hit testing, accessible text mode, and cancellation behavior verified.
- [ ] Bounded off-main decode/cache and packaged resource tests pass.
- [ ] Legacy data preserved; migration transaction/reopen/rollback tests pass.
- [ ] Legacy fallback is explicit, never mislabeled as an image page.
- [ ] Native tests, strict-concurrency checks, accessibility and device measurements recorded.

### Content/legal

- [ ] Exact edition/pagination selected by a human.
- [ ] Rights scope and all obligations approved for exact assets/maps/distribution.
- [ ] Native-resolution evidence accepted; no generative enlargement.
- [ ] Complete baseline artwork and included/excluded source inventory verified.
- [ ] All 6,236 canonical keys have correct positive-area regions; all continuation/anchor relationships validated.
- [ ] Every page/map reviewed according to qualified-review procedure, including special/mixed/supplementary pages.
- [ ] Source `522` repaired and reviewed if Qamar is selected.
- [ ] Reproducible hashes, notices, patches, and review records included appropriately.

### Distribution

- [ ] Clean offline install can read every bundled baseline page.
- [ ] Release contains no fixtures, raw APK, unapproved images, or source-tree path dependency.
- [ ] No fixture/incomplete edition can pass production gates.
- [ ] Rollout communication and same-binary rollback tested without destroying V2 locations.
- [ ] Release approval is distinct from merely producing an unsigned IPA.

**If any mandatory item is unchecked, do not make the facsimile reader the production default.**

## Contract appendices

The following appendices provide the detailed data, geometry, and migration contracts used by the tasks above.

## Appendix A — Edition data and API contracts

### A1. Manifest fields

Implement this schema, not an undocumented collection of filenames:

```text
schemaVersion: integer, exactly 1 initially
editionID: nonempty stable string, validated portable identifier
contentVersion: positive integer
displayName: nonempty string
publisher: string
rendererKind: legacyText | facsimile
approval:
  status: fixture | unapproved | approved
  decisionReference: string or null
  reviewReference: string or null
canonicalDatabaseSHA256: 64 lowercase hex characters
sourceArchiveSHA256: 64 lowercase hex characters or null
coordinateSpace: normalized-top-left
quranPageCount: positive integer
navigationPageCount: integer >= quranPageCount
noticePath: validated relative path
pages: ordered array of Page objects
anchors: array of Anchor objects
excludedSourceAssets: [{ sourceAssetID, reason }]
```

`Page`:

```text
pageID, title, sourceAssetID: strings
navigationIndex: positive integer
quranOrdinal: positive integer or null
printedLabel: string or null
kind: quran | quranAndSupplement | supplement | frontMatter
sourceWidth, sourceHeight: positive integer pixels (null only for legacyText)
imagePath, imageSHA256: validated path/hash (null only for legacyText)
verses: [{ surah, ayah, readingOrder, startsHere, endsHere }]
regions: [{ regionID, kind, surah, ayah, fragmentOrder, sourceOrder,
            label, minX, minY, maxX, maxY }]
```

- `verses` contains distinct canonical keys in semantic order, including continued verses. Each key needs at least one positive-area region in a facsimile.
- `startsHere`/`endsHere` mean first/last page containing that verse. Derive from full ordered memberships and verify against source; they do not mean first/last rectangle.
- Region `kind`: `ayah`, `bismillah`, `decoration`, `supplication`. Only `ayah` carries canonical surah/ayah; other kinds have both null and may have a descriptive label. Al-Fatihah 1:1 is canonical, not an introductory ayah-zero region.
- `fragmentOrder` is 1-based within one verse on one page. `sourceOrder` is 1-based and unique among all regions on a page. Region IDs are stable within a page.
- `Anchor`: `{ kind: surah|juz, number, pageID, surah, ayah }`. Production requires all 114 Surah and 30 Juz anchors, each matching trusted start keys and actual membership.
- `quran`/`quranAndSupplement` have an ordinal and membership. `supplement`/`frontMatter` have null ordinal and no canonical ayah regions. Do not classify a mixed final page as supplication-only.
- Unknown schema versions fail explicitly. Unknown fields should be rejected initially to catch misspellings; extend schema intentionally when adding fields.
- Production references must point to real approved decision/review records. A JSON `approved` string alone is not evidence; release CI checks the approved source register and requires human release review.

Example single page, with placeholders that **must be replaced by generated values**:

```json
{
  "pageID": "a",
  "navigationIndex": 1,
  "quranOrdinal": 1,
  "printedLabel": null,
  "kind": "quran",
  "title": "Synthetic page A — NOT A MUSHAF",
  "sourceAssetID": "fixture-a",
  "sourceWidth": 720,
  "sourceHeight": 1057,
  "imagePath": "editions/fixture-geometry-v1/v1/pages/a.png",
  "imageSHA256": "<computed 64-character hash>",
  "verses": [
    { "surah": 1, "ayah": 1, "readingOrder": 1,
      "startsHere": true, "endsHere": false }
  ],
  "regions": [
    { "regionID": "a-r1", "kind": "ayah", "surah": 1, "ayah": 1,
      "fragmentOrder": 1, "sourceOrder": 1, "label": null,
      "minX": 0.55, "minY": 0.20, "maxX": 0.90, "maxY": 0.27 }
  ]
}
```

The complete fixture must include a later page containing the continuation of 1:1, another canonical key for shared-row tests, and a supplementary-only page. Its graphics remain synthetic. Canonical IDs are looked up from existing DB keys, never guessed from these examples.

### A2. Sidecar SQLite schema

Use this design in `pipeline/mushaf/schema.sql`. Extra indexes are allowed; weaker constraints require a documented decision. This is a **new database**, not SQL to execute against the canonical/user database.

```sql
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
      REFERENCES page_verses(edition_id, page_id, surah_id, ayah_number),
    CHECK (
      (kind = 'ayah' AND surah_id IS NOT NULL AND ayah_number IS NOT NULL)
      OR (kind <> 'ayah' AND surah_id IS NULL AND ayah_number IS NULL)
    )
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
      REFERENCES page_verses(edition_id, page_id, surah_id, ayah_number),
    CHECK ((kind = 'surah' AND number BETWEEN 1 AND 114)
        OR (kind = 'juz' AND number BETWEEN 1 AND 30))
);
```

Importer/validator additionally enforce:

1. Every numeric value is finite and correctly typed; integer indices are not fractional JSON numbers.
2. All four image metadata fields exist for every facsimile page and none for a legacy-text page. SQL cannot enforce this edition-to-page rule alone.
3. Counts match; navigation indices and Quran ordinals are each contiguous in their own sequences.
4. Page memberships and canonical regions match in both directions. Production coverage is the complete existing 6,236-key set using **valid positive-area regions**, not merely raw source labels.
5. Every verse has exactly one first/last membership; continuations follow the Quran sequence. Any noncontiguous occurrence is rejected pending explicit source investigation, not hidden with an exception flag.
6. Anchors match canonical start keys, not legacy page metadata. Production ordering respects canonical reading sequence.
7. Differing-key overlaps produce a review error. Tiny source boundary-rounding discrepancies must be resolved/documented and tested rather than broadly excused by an arbitrary percentage tolerance.
8. Legacy rows may omit rectangles because their renderer obtains geometry from Core Text. This exception must not be available to facsimile editions.
9. Store schema/canonical hash/source/correction provenance in metadata or hashed manifest. No Arabic or translation duplication in the sidecar.

### A3. Swift model and query signatures

Proposed interfaces, not existing APIs:

```swift
struct VerseKey: Hashable, Codable, Sendable {
    let surah: Int
    let ayah: Int
    // Validated creation and decoding; ayah maximum checked with canonical lookup.
}

struct ReaderLocation: Hashable, Codable, Sendable {
    let editionID: String
    let pageID: String
    let anchorVerse: VerseKey?
}

enum ReaderDestination: Sendable {
    case exact(ReaderLocation)
    case quranOrdinal(editionID: String, ordinal: Int)
    case verse(editionID: String, key: VerseKey)
    case surah(editionID: String, number: Int)
    case juz(editionID: String, number: Int)
}

protocol MushafEditionRepositoryProtocol: Sendable {
    func fetchEditions() async throws -> [MushafEdition]
    func fetchPages(editionID: String) async throws -> [MushafPageSummary]
    func fetchPage(editionID: String, pageID: String) async throws -> MushafPageContent?
    func fetchLocations(editionID: String, verse: VerseKey) async throws -> [ReaderLocation]
    func fetchAnchor(editionID: String, kind: NavigationAnchorKind, number: Int) async throws -> ReaderLocation?
    func fetchPageForQuranOrdinal(editionID: String, ordinal: Int) async throws -> ReaderLocation?
}
```

- `MushafEdition`: edition table fields plus installed version/verification availability.
- `MushafPageSummary`: page table fields, value types only, no decoded image.
- `MushafPageContent`: summary, ordered memberships, normalized regions. Canonical text is composed through existing repository data by the page loader, not stored in this DB.
- `NormalizedRect`: finite validated min/max doubles with strict positive area. Custom decoding must invoke validation; synthesized Codable must not bypass invariants.
- `MushafRegion`: ID, type, optional VerseKey, fragment/source order, rectangle, optional label.
- `ReaderLocationResolver.resolve(destination, preferredCurrentLocation, policy)` returns a validated location or `editionUnavailable`, `pageUnavailable`, `verseUnmapped`, `invalidOrdinal`, or repository error. `policy` distinguishes first occurrence and prefer-current-if-containing.
- Exact saved page stays exact even if its optional anchor has another earlier occurrence. Validate that a supplied anchor belongs to that page; never silently redirect an exact location because of the anchor.
- Cache all lightweight summaries/anchor indices per edition if useful; page regions and images remain bounded. Repository helpers may batch canonical fetches but may not alter the canonical DB.

## Appendix B — Geometry, gestures, and image loading

### B1. Aspect-fit math

For positive finite source `(W,H)` and container `(Vw,Vh)`:

```text
s = min(Vw/W, Vh/H)
imageWidth = W*s
imageHeight = H*s
ox = (Vw-imageWidth)/2
oy = (Vh-imageHeight)/2

container touch -> normalized:
u = (touchX-ox)/imageWidth
v = (touchY-oy)/imageHeight

normalized rect -> container:
x = ox + minX*imageWidth
y = oy + minY*imageHeight
width = (maxX-minX)*imageWidth
height = (maxY-minY)*imageHeight
```

Reject outside-image touches before any numerical clamping. Zero/nonfinite inputs produce no geometry, no selection, and no accessibility frames. Use the canvas's actual laid-out bounds, not an assumed full screen height that includes chrome/safe areas.

Required numerical regression:

```text
source 720×1057; container 360×700
s = 0.5
imageRect = (x:0, y:85.75, width:360, height:528.5)
(180,350) -> (0.5,0.5)
(180,20) -> outside image, not an ayah
```

A 1440×2114 geometrically identical image uses the same normalized rectangles; do not multiply coordinates by two. Different crop/deskew/artwork requires registration/new maps. A decoder thumbnail's rounded dimensions must not introduce a second independently calculated overlay aspect ratio.

Later zoom uses a complete transform `T = pan/zoom × fit` and its inverse. If UIKit converts the touch into unzoomed content coordinates, apply only the remaining fit inverse—do not apply the zoom inverse again. Add explicit tests for this convention before enabling zoom.

### B2. Hit-testing contract

1. Read current validated in-memory regions only.
2. Convert touch through the shared transform.
3. Use half-open bounds (`min <= value < max`); an exact outside image edge may select nothing.
4. Match only `ayah` regions. Same-key multiple matches deduplicate; differing-key matches return `ambiguous` with no verse selection.
5. Do not use nearest-verse heuristics in blank margins. Do not inflate every region to 44pt where it collides with neighbors; offer an accessible verse list instead.
6. Highlight each matching page fragment separately. A bounding union can cover unrelated words and must not become the highlight or a test touch target.
7. Hold recognition publishes canonical key immediately, before translation fetch. Gesture callbacks perform no SQL, disk, image decode, or network work.
8. Selection change may fade a subtle overlay unless Reduce Motion is set, but page/geometry changes are atomic, not animated path morphs.

### B3. Accessibility contract

- One element per distinct visible-page verse in canonical reading order, even if multiple fragments exist.
- Label includes Surah/ayah identity and trusted Arabic text as appropriate. A hint describes activation. Continuation status can be included without duplicating the verse in the rotor.
- Accessibility frame/path derives from the same geometry. Convert to screen coordinates using UIKit accessibility conversion APIs after layout; recompute after bounds/window changes.
- Activating the element calls the same selection/action path as hold; no dependence on a fabricated tap coordinate.
- Offscreen neighbors expose no duplicate verse elements. Give chrome and text-mode entry points stable accessible controls of at least 44pt.
- Full text view supports Dynamic Type and does not claim to preserve printed line breaks. Use reviewed supplementary text or disclose its absence; do not send supplication through translation/audio APIs keyed by Quran ayah.
- Dark mode adjusts surrounding surfaces, not Quran pixels. Contrast must remain sufficient around the bright printed page.

### B4. Loader state machine

```text
absent -> queued -> verifying -> decoding -> ready
                             \-> failed
any obsolete request -> cancelled/discarded completion
ready at old size -> decoding larger bucket while old valid image remains visible
memory warning -> drop nonvisible cache entries
```

Use a page-specific load token and current edition/version checks in addition to task cancellation. Shared/coalesced requests need subscriber accounting: cancelling an obsolete neighbor subscription must not cancel a decode still needed by the visible page. Check cache cost after inserting/replacing results; account for pinned visible image and record when it exceeds budget by itself rather than claiming the budget includes no exceptions.

ImageIO options to verify against the SDK include `kCGImageSourceShouldCache = false` at source creation and thumbnail options `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceThumbnailMaxPixelSize`, `kCGImageSourceCreateThumbnailWithTransform`, `kCGImageSourceShouldCacheImmediately`. Decode on the actor/executor; assign display state on MainActor. Errors carry edition/page identifiers and safe descriptions, not personal notes or private source paths.

Approximate full RGBA costs explain why downsampling is mandatory: 720×1057 ≈2.9 MiB, 1440×2114 ≈11.6 MiB, 3301×5100 ≈64.2 MiB per image before overhead. Use actual decoded row bytes for cache accounting and Instruments for process peak.

## Appendix C — User-data schema, migration, and cross-edition behavior

### C1. Why use separate V2 tables

The existing service creates `bookmarks`, `reading_sessions`, and `app_preferences`; page numbers are bare integers and bookmark page is non-null. There is no existing edition column. This plan retains those tables as a legacy snapshot and creates separately named reader tables. It does not change the meaning of `page_number` in place or write image-edition integers into old columns.

Do not run snapshot migration early while the shipping app still writes through old bookmark/history/last-read APIs. Switch **all production reader persistence call sites**, including the legacy renderer, to V2 together. Legacy methods can remain for compatibility tests during this milestone, but must have no production reader callers after migration is enabled. Generic unrelated preferences can continue using `app_preferences`.

### C2. V2 user tables

Create these in the **user database**, not in the content sidecar. Validate the precise old schema with `PRAGMA table_info` first. Use a dedicated migration table instead of overwriting a possibly future global `user_version`.

```sql
CREATE TABLE reader_schema_migrations (
    version INTEGER PRIMARY KEY,
    completed_at TEXT NOT NULL
);

CREATE TABLE reader_bookmarks_v2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL CHECK(kind IN ('verse','page')),
    ayah_id INTEGER,
    surah_id INTEGER,
    verse_number INTEGER,
    identity_status TEXT NOT NULL CHECK(identity_status IN ('valid','invalid','notApplicable')),
    edition_id TEXT NOT NULL,
    page_id TEXT NOT NULL,
    anchor_surah_id INTEGER,
    anchor_verse_number INTEGER,
    location_status TEXT NOT NULL CHECK(location_status IN ('valid','unresolved')),
    edition_name_snapshot TEXT NOT NULL,
    page_label_snapshot TEXT NOT NULL,
    legacy_page_number INTEGER,
    title TEXT NOT NULL,
    arabic_snippet TEXT,
    translation_snippet TEXT,
    note TEXT,
    created_at TEXT NOT NULL
);
CREATE INDEX idx_reader_bookmarks_verse ON reader_bookmarks_v2(ayah_id);
CREATE INDEX idx_reader_bookmarks_page ON reader_bookmarks_v2(edition_id, page_id, kind);

CREATE TABLE reader_sessions_v2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    edition_id TEXT NOT NULL,
    page_id TEXT NOT NULL,
    anchor_surah_id INTEGER,
    anchor_verse_number INTEGER,
    location_status TEXT NOT NULL CHECK(location_status IN ('valid','unresolved')),
    legacy_page_number INTEGER,
    start_time TEXT NOT NULL,
    duration_seconds REAL NOT NULL
);
CREATE INDEX idx_reader_sessions_page ON reader_sessions_v2(edition_id, page_id);

CREATE TABLE reader_last_locations_v2 (
    edition_id TEXT PRIMARY KEY,
    page_id TEXT NOT NULL,
    anchor_surah_id INTEGER,
    anchor_verse_number INTEGER,
    location_status TEXT NOT NULL CHECK(location_status IN ('valid','unresolved')),
    updated_at TEXT NOT NULL
);
```

Notes:

- There is no foreign key from the writable user DB to an installed edition DB. Locations must survive temporary edition unavailability/removal.
- Nullable identity fields intentionally preserve malformed legacy records. Validate new writes strictly; display migrated invalid rows as recoverable data, not as legitimate canonical verses.
- Do not add unique ayah/page indexes during migration: old duplicates may carry different notes. Preserve them all. Prevent **new** duplicates transactionally through the service.
- `legacy_page_number` retains the old integer verbatim. New image bookmarks leave it null. Snapshot labels let the bookmark list describe an unavailable edition.
- `created_at`/`start_time` strings are copied verbatim. Parsing failure must not replace stored history with today's date; expose a display warning/unknown date while retaining raw storage.
- New page bookmarks may store a canonical anchor without becoming verse bookmarks; `kind` and verse identity fields define bookmark type. Supplements may have no anchor.

### C3. Migration transaction

1. Open canonical identity lookup and old user DB. Before migration, validate expected old table/column shapes. An unknown incompatible schema is a stop condition, not permission to drop/recreate it.
2. If a completed migration version greater than supported V2 exists, stop writes and report incompatible newer data. If V2 marker exists, do not copy legacy rows again.
3. For an on-disk DB, create a consistent local pre-migration backup using `sqlite3_backup` (or another verified SQLite snapshot API). Do not copy only the `.sqlite` file while WAL contains live changes. Keep backup private in app support; backup failure blocks destructive migration actions. In-memory tests can skip backup.
4. Gather immutable canonical ID/key validation data **before** the transaction. The migration transaction itself contains no `await`; actor reentrancy must not interleave other writes.
5. `BEGIN IMMEDIATE`; create V2 tables/indices and migration table inside the transaction.
6. Copy each bookmark preserving its original ID and payload:
   - `kind = verse` if old `ayah_id` is non-null, otherwise `page` (matching old semantics).
   - Compare existing ayah ID/surah/verse against canonical lookup. Preserve inconsistent raw values and mark `identity_status = invalid`; do not guess which one was intended. Valid page bookmarks use `notApplicable`.
   - `edition_id = legacy-qudratullah-13-849`.
   - If old page is in `1...849`, set `page_id = q` plus four-digit zero-padded page, and `location_status = valid`.
   - Otherwise preserve integer, use a nonnavigable stable ID such as `unresolved-bookmark-<id>`, and mark `unresolved`.
   - Optional anchor is set only when canonical identity is valid **and** legacy membership confirms that key appears on that saved page. A valid verse bookmark may have a stale page; preserve both without inventing membership.
   - Copy notes/titles/snippets/dates unchanged; do not trim or deduplicate.
7. Copy sessions with IDs, raw times/durations, legacy edition/page conversion, and unresolved IDs for invalid pages. Do not attribute old sessions to a new facsimile.
8. Read old `app_preferences.last_read_page` without using a helper that silently defaults malformed values:
   - Missing value: initialize legacy first Quran page.
   - Valid `1...849`: store corresponding legacy page.
   - Invalid/unparseable value: preserve original preference and create an unresolved last-location state, then ask the user to start at a valid location. Do not pretend restoration succeeded.
9. Set namespaced preference `reader.v2.preferred_edition_id` to legacy for migrated users. Do not alter theme/audio/translation preferences. Fresh installation default choice is a separate bootstrap decision after approved catalog verification.
10. Verify copied counts, IDs, raw payloads, and next autoincrement behavior. Use checksums/row comparisons in tests; do not log personal notes in production diagnostics.
11. Insert V2 completion marker **last**, then `COMMIT`. Any error executes `ROLLBACK`; old data remains intact. Test failure after DDL, midway through copying, and immediately before marker/commit.
12. Reopen DB and verify migration is idempotent. Never auto-restore an old backup on an unrelated later launch failure, which would erase newer V2 edits.

### C4. V2 API surface and write semantics

Add explicitly named methods to `UserDatabaseServiceProtocol` and implement them in its actor. The following are responsibility/signature guides; choose final Swift argument labels consistently:

```text
fetchReaderBookmarks() -> [ReaderBookmark]
fetchReaderVerseBookmarks(ayahID) -> [ReaderBookmark]
isReaderPageBookmarked(location) -> Bool
addReaderVerseBookmark(canonical identity, origin location, snapshots, text/note) -> ReaderBookmark
addReaderPageBookmark(location, snapshots, title/note) -> ReaderBookmark
removeReaderBookmark(id)
saveReaderLastLocation(location)
fetchReaderLastLocation(editionID) -> StoredReaderLocation?
setPreferredReaderEdition(editionID)
fetchPreferredReaderEdition() -> String?
recordReaderSession(location, startTime, durationSeconds)
fetchRecentReaderLocations(limit) -> [StoredReaderLocation]
```

All operations are `async throws`; new writes validate canonical identity and page membership before persistence. Pass already validated immutable values into the no-await SQL transaction. Capture location in async operations and reject stale UI responses.

- Verse bookmark deduplication is global by canonical identity; page bookmark deduplication is by edition/page, ignoring optional anchor. Actor-isolated transaction performs check+insert without a suspension.
- On a duplicate add, return the existing bookmark without overwriting its notes. If migrated duplicates already exist, preserve them and expose them in the bookmark list.
- Removing from a row removes only that ID. A quick toggle finding multiple historical duplicates must ask the user to manage them; do not delete several differently annotated records silently.
- Last-read UPSERT is per edition. Switching editions does not delete another edition's last location.
- Historical sessions retain the edition actually read. Record foreground visible dwell using a controllable/monotonic timing source, flush once on navigation/background, and avoid double counting through both dwell timers and lifecycle callbacks. Validate new durations as finite/nonnegative without rewriting old raw durations.
- Generic old bare-page APIs remain legacy-test compatibility only after rollout. Add an `rg` check/test review showing no reader/index/bookmark/audio production path still calls them.

### C5. Navigation and edition-switch policy

| Saved/current data | Required action |
|---|---|
| Exact location, edition installed | Open exact saved page; inspect anchor only if valid membership. |
| Verse bookmark, user chooses active edition | Resolve canonical key there; explain edition change; preserve stored origin. |
| Valid verse bookmark whose old page does not contain that verse | Explain the mismatch and offer the canonical verse or original page separately; do not claim the stored page is its verified location. |
| Page bookmark, original edition available | Offer Open original edition as default. |
| Page bookmark, user requests different edition | Offer an explicitly approximate jump using saved valid anchor or first canonical verse on original page. Explain that page boundaries differ. Do not rewrite original bookmark. |
| Supplementary page without canonical anchor | Open original edition/material or report unavailable; no invented canonical destination. |
| Original edition not installed | Show snapshot label and options to restore/select edition or map a valid canonical anchor; no integer clamp. |
| Malformed legacy identity/location | Show recoverable unavailable record and original label; allow user edit/delete; never lose note or guess verse. |

Edition switching uses destination priority: saved last read in target edition; otherwise a validated current canonical anchor if the user chooses “continue from this verse”; otherwise explicitly start target edition at first Quran page. Explain approximation whenever starting from page-only context. Do not call this an exact page conversion, even when source/destination verse sets happen to match.

A feature-flag rollback within the new binary uses V2 storage and preserves unavailable facsimile locations. Older binary downgrade is not synchronized: retained old tables contain only their historical snapshot. If downgrade support becomes a requirement, stop and design/test a separate export/reconciliation migration rather than adding ad hoc dual writes.

## Appendix D — Review provenance and completion evidence

For each production content version, retain:

```text
Edition decision/reference and approval date
Archive/source hashes and exact source inventory
Canonical DB hash and canonical convention
Importer/schema/tool versions and reproducible command
Inclusion/exclusion list and page-label verification
Image dimensions, file hashes, format/orientation evidence
Original maps, source hashes, and ordered correction patches
Automatic validation report (including positive-area coverage)
Page/artwork/coordinate/anchor review coverage and reviewer references
Special-page and source-522 review where relevant
License, attribution, modifications, and distribution review
Packaged-resource inventory and build/configuration identifiers
Native test reports and device performance/accessibility results
Known limitations and release decision
```

Temporary evidence under `pipeline/temp/` is not a committed production pipeline. Promote only rights-cleared fixtures, stable tooling, appropriate nonprivate reports, and approved release assets through an intentional review. The original audit remains the source of research conclusions; this plan defines how to implement them without silently relaxing them.

### Documentation verification during preparation

- Confirmed the plan contains all 19 tasks P00–P18 and all four contract appendices.
- Checked its local audit link and balanced fenced code blocks.
- Executed both SQL schema examples against separate in-memory SQLite databases: both parsed successfully. This is a syntax smoke test, not proof that future importer/migration implementations work.
- Confirmed current `project.yml` names both project and scheme `QuranApp`, uses Swift 5.9, and includes unit/UI test targets.
- No application implementation, production ingestion, native build/test, or hardware acceptance is claimed by these documentation checks.
