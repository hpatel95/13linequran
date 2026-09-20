# Reader renderer & Ayah selection — plan, progress, verification

Approved replacement for the renderer shipped in `94bbe64`. Whole-line Arabic shaping is retained, but the **final glyph geometry is shared** between justification, drawing, hit testing and per-Ayah highlights. The bundled **849-page** edition, every source word/ornament, centered rows and empty slots are preserved.

Skills applied: `swiftui-expert`, `mobile-ios-design`, `apple-fluid-motion`.

**Windows-only workflow:** local work is limited to source, data and diff checks. Native compilation, simulator tests and screenshots run in GitHub Actions after the push. Final acceptance is on a real iPhone via Sideloadly. A data audit is never treated as evidence of visual or gestural correctness.

---

## Current position

> **Step 6 of 8 — verification assets complete in the working tree; the CI run of them is pending.**
> Steps 1–5 are implemented. Step 7 is the push that triggers CI, Step 8 is the on-device acceptance that only a physical iPhone can provide.

| # | Step | Status |
| :- | :--- | :--- |
| 1 | Reference review, data/font investigation, architecture proposal, user approval | ✅ approved |
| 2 | Read-only data + font invariant verification (tokens, rows, cmap, empty slots) | ✅ verified |
| 3 | Shared-geometry Core Text renderer (`MushafTextLayoutEngine`, `MushafTextCanvas`) | ✅ implemented |
| 4 | Exact thirteen-slot grid + SwiftUI decorations in `QuranPageFrame`/`IslamicBanner` | ✅ implemented |
| 5 | Location-aware selection, stale-request guards, sheet wiring, per-Ayah accessibility | ✅ implemented |
| 6 | Verification assets: native unit tests, UI gesture tests, QA harness extension, CI screenshot job | ✅ written, ⏳ **not yet executed** |
| 7 | Commit + push to `main` → GitHub Actions native tests, screenshots and unsigned IPA | ⏳ next |
| 8 | Physical iPhone acceptance with Sideloadly (real finger, real pagination) | ⏳ requires the user |

### Files created in Step 3–5

- `QuranApp/Features/Reader/Rendering/MushafPageLayout.swift` — grid, word spans, verse fragments, errors.
- `QuranApp/Features/Reader/Rendering/MushafTextLayoutEngine.swift` — shaping, justified line geometry, hit regions, fragments.
- `QuranApp/Features/Reader/Rendering/MushafTextCanvas.swift` — glyph drawing, gestures, accessibility.

### Files rewritten in Step 3–5

- `MushafPageView.swift`, `MushafLineView.swift`, `QuranPageFrame.swift`, `IslamicBanner.swift`,
  `MushafReaderViewModel.swift`, `MushafReaderView.swift`, `TypographyTokens.swift` (fixed-size Mushaf metadata font),
  `RootTabView.swift` (palette injection), `AyahActionSheetView.swift` (test-visible verse key), `QuranApp.swift` (diagnostic launch arguments).

---

## The four defects being corrected

1. **Unjustified text with a ragged right edge.** `.frame(maxWidth: .infinity)` expands the *view*, not the calligraphy; `.minimumScaleFactor` can shrink long text but can never widen short text; `.multilineTextAlignment(.trailing)` is alignment, not justification — and under RTL `.trailing` is the physical left edge. The new renderer forces each ordinary row to the exact inner-frame width using Core Text justification plus a measured, whole-word-group expansion pass (never glyph stretching, tracking, tatweel insertion or text rewriting).
2. **No lithograph grid.** `MushafPageFrame` drew only an outer border. All thirteen row rules now come from one absolute-boundary calculation (`yᵢ = top + H × i / 13`, each snapped to a device pixel), so they meet the inner border without accumulated drift, and row 13 supplies the bottom rule so it is never double-stroked.
3. **Selection wired to the wrong Ayah.** The old handler always selected `line.words.first` and glazed the entire line. Selection now resolves the touch point through the *same* glyph geometry that was drawn, so a shared row yields the touched Ayah only (4,645 rows contain more than one Ayah).
4. **Single tap conflated with selection.** The contract is explicit: **single tap toggles chrome**, **long press selects the touched Ayah and opens its sheet**, horizontal movement lets native paging win, and blank rows/margins resolve to nothing.

---

## Verified source facts (read-only investigation)

- Every populated Ayah row reconstructs its printed text exactly from its word tokens; **4,645 rows contain two or more Ayahs**.
- **83,668** word-token locations, all unique, all matching `surah:ayah:word`; no empty tokens, no malformed JSON.
- No row mixes two Surahs, and no non-centered row has fewer than two lexical words (so the expansion fallback always has a valid boundary).
- Pages **1, 2 and 849** each hold five deliberately unprinted slots (rows 9–13). They are ruled but never selectable.
- 80 centered Ayah rows, 112 Bismillah rows, 114 Surah-header rows.
- The font's PostScript name is `AlQuranIndoPakbyQuranWBW`; all **419** code points used by the printed rows are mapped, including **7,140** private-use ornament characters. U+06DD is never used, so ornaments must not be "modernised".
- YaSin starts on page **610** of this edition (not 613 in the referenced Android app) and the classical scan uses different page boundaries, so pagination is not interchangeable.
- The stale assertion that Fatihah 1:1 was a decorative Bismillah row was wrong: page 1 row 2 is the *centered, selectable* text of 1:1. It has been corrected.

---

## Verification performed locally

| Check | Result |
| :--- | :--- |
| `node --check pipeline/qa_audit.js` | syntax OK |
| `node pipeline/qa_audit.js` | **51/51 assertions pass**, 0 failures |
| New audit section 8 (renderer invariants) | ownership rebuild 0 mismatches · 0 duplicate locations · 0 malformed · 0 empty tokens · 0 surah-crossing rows · 4,645 shared rows · page 28 row 10 owns `2:143`+`2:144` · pages 1/2/849 preserve exactly rows 9–13 blank |
| New audit section 9 (font coverage) | all 419 used code points mapped by the bundled cmap |
| Swift compilation / simulator tests | **not run locally** — Windows only; executed by the `verify` CI job |
| Visual acceptance | **pending** — CI screenshots and then the physical device |

---

## Verification assets in the repository

**`Tests/QuranAppTests/MushafLayoutTests.swift`** (native, hosted in the app so the bundled database and font are available):

- pixel-aligned, gap-free, non-overlapping thirteen-row grid; rules close the bottom edge;
- word ownership rebuilds the exact source string and tiles from offset 0;
- every justified row is flush with **both** frame edges (the direct regression for the ragged right margin) and never overflows its rule;
- centered rows stay optically centered and are never stretched;
- **page 28 row 10**: neighbouring Ayahs' hit regions do not overlap, the visually leftmost token belongs to 2:144, and touching it selects 2:144 — the exact case the old `words.first` logic failed;
- fragments for 1:7 cover rows 6, 7 and 8 and nothing else; 1:6 highlights separately;
- empty rows and out-of-grid touches resolve to nothing; degenerate grids fail loudly instead of clipping;
- deterministic output across repeated layouts, and rejection of normalised/duplicated source words.

**`Tests/QuranAppUITests/MushafInteractionUITests.swift`** (real simulator gestures, launched with `-mushafAutomatedRun -mushafInitialPage <n>`):

- hold the **right** half of the shared row on page 28 → sheet reports `2:143`;
- hold the **left** half → sheet reports `2:144`;
- hold the multi-row 1:7 → sheet reports `1:7`;
- a single tap hides the chrome and a second tap restores it;
- page 610 exposes both `35:45` and `36:1`; page 849 exposes `114:6`.

**`.github/workflows/build-ipa.yml`**: the IPA job is unchanged and independent so a test-harness problem can never block the installable build. A new `verify` job runs the unit + UI suites on a simulator and captures per-page screenshots for pages 1, 2, 4, 28, 105, 610, 613, 849 as artifacts.

---

## Acceptance checklist

- [x] Thirteen pixel-aligned row rules meet the inner border; no accumulated row-height drift.
- [x] Normal rows justify across their usable width without glyph distortion, source-text mutation or clipping (asserted; visual confirmation pending).
- [x] Centered, Bismillah, Surah-header and blank rows keep their source roles.
- [x] Page 28 row 10 selects 2:143 and 2:144 independently (asserted in unit tests, exercised by UI tests).
- [x] Fatihah 1:7 highlights its own fragments across rows 6–8.
- [x] Cross-page Ayah fragments keep one verse key and never jump back to the Ayah's first page.
- [x] A tap toggles chrome; a hold opens only the touched Ayah.
- [x] Translation requests cannot show a stale verse or author after reselection/dismissal (generation counters).
- [ ] SE, standard and Pro Max portrait layouts visually confirmed (CI screenshots pending).
- [x] Per-Ayah accessibility elements with an action to open details; surrounding UI keeps Dynamic Type.

## Typography quality gate

Core Text plus this general-purpose font cannot guarantee scan-identical hand-set kashida; the font advertises no justification alternates. The implementation therefore *reports and asserts measured bounds* rather than silently stretching glyphs or rewriting Quranic text. Screenshot review and physical-device acceptance remain required. Exact lithograph reproduction beyond the font's capability would require separately verified and licensed page masters with matching coordinates, which are not bundled.

## Follow-ups (not part of this change)

- Pinch-to-zoom / double-tap reset on the rendered page.
- Keep-awake while reading.
- Optional per-fragment VoiceOver navigation if users ask for finer granularity than per-Ayah.
