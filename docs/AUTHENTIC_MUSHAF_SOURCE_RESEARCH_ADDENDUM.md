# Authentic Mushaf — Source Research Addendum

Status: **research only**. No production asset, license, coordinate map, or pagination
decision is approved by this document. It records fresh web research performed for the
"which source should we use" question and separates *inspected evidence* from
*publisher claims* and *unverified leads*.

Companion documents:

- `docs/AUTHENTIC_MUSHAF_AUDIT.md` — independent audit of the current Qamar APK artwork/maps.
- `docs/AUTHENTIC_MUSHAF_IMPLEMENTATION_PLAN.md` — execution plan for the image-backed reader.

## 0. Method and limitations

- A dedicated `web_search` tool was **not available** in this environment. Searches were done
  with live HTTP retrieval of search-engine results, official publisher pages, Internet Archive
  metadata APIs, the GitHub REST API, and QUL/Tarteel pages. This is disclosed rather than
  claiming a `web_search` call.
- Automated image comparisons here are **indicative**, not perceptual-hash proof. They use a
  decoded-luma comparison with offset search. They can confirm "same page rendering" when
  correlations are high (control ≈ 0.9) but cannot prove identity in edge cases.
- A Public Domain Mark or CC0 tag chosen by an uploader is **not** proof of provenance or of
  worldwide public-domain status. Archived PDFs are leads until rights and native resolution
  are confirmed with the rights holder.

## 1. Is the proposed image source Qamar, and does CC BY-SA 4.0 apply?

**Source identity — confirmed.** The audited artwork is Qamar Apps' "Quran 13 Line" publication
(Android package shipped in `pipeline/qamar_app.apk`; iOS `id=885800827`). So the *proposed
source is Qamar*.

**License claim — confirmed, with an unresolved conflict.**

- `https://www.qamarapps.com/license` (fetched, HTTP 200) states verbatim:
  > "All Qamar Apps publications are licensed under a Creative Commons
  > Attribution-ShareAlike 4.0 International License."
- The app's own `aboutus.html` / store listing states: "The entire publication is copyright
  protected, any unauthorized reproduction or use in any form is strictly forbidden."

These are not logically contradictory (a copyright owner may license some or all rights under
CC), but the **scope is ambiguous**: the CC sentence names "publications" broadly, while the
copyright sentence claims the *visual content* is "digital enhancement to the original script"
and fully protected. It is not established whether the CC BY-SA 4.0 grant covers:

1. the exact page images,
2. the HTML coordinate maps,
3. redistribution inside a native iOS app, and
4. derivative/modified forms (rescaled, recompressed, re-laid-out, annotated).

**If CC BY-SA 4.0 does apply**, obligations for distribution include at minimum: attribution,
a link to the license, an indication of changes, and **ShareAlike** on "adapted material"
(which can be triggered by rescaling/reformatting) plus no additional legal/technological
restrictions. That could force CC BY-SA terms onto parts of the app. This must be clarified in
writing by the publisher before any production use.

**Action:** request written confirmation from `support@qamarapps.com` covering exact files,
derivative forms, and redistribution inside an app. Until then, production use is **gated**.

## 2. New finding: Qamar's own web eBook is higher-resolution

Qamar publishes "Quran 13 Line" as a first-party web eBook (FlippingBook-style viewer) at
`https://ebooks.qamarapps.com/ebooks/quran-13-line/HTML/`.

Inspected evidence:

- Viewer advertises 854 pages; a table of contents exists with Juz and Surah anchors
  (e.g. `page-6.html` = Juz 1 / Al-Fatihah, `page-33.html` = Juz 2, …).
- Page background images are served as PNG from
  `…/files/assets/common/page-substrates/pageNNNN.png`.
- **Dimensions are 1162×1684** for every page sampled; the audited APK images are 720×1057.
  This is ~1.7× linear / ~2.9× areal resolution.
- Page payload ≈ 0.63–1.98 MB PNG (opening/ornate pages larger). ~847 Quran pages would be
  roughly 600–700 MB before any optimization.
- Existing substrates were verified for pages 4–20, 105, 613, 848–852.

**Important caveat — not a confirmed drop-in upgrade.** An automated identity comparison between
the web images and the audited APK images returned low correlation:

| Comparison | Best correlation |
|---|---|
| APK page 4 vs APK page 5 (control, same rendering) | **0.917** |
| Web page 6 vs APK pages 4–7 | 0.03–0.58 |
| Web page 7 vs APK pages 4–7 | 0.03–0.57 |
| Web page 8 vs APK pages 4–7 | ≤0.07 |

Interpretation: both are 13-line Mushaf pages, but the web eBook appears to be a **different
rendering/pagination** than the APK artwork, so it cannot be assumed to share the APK's
coordinate maps. Treat it as a *separate edition candidate* requiring its own pagination check
and its own geometry.

Also note the APK coordinate system: `coords` in `Html/004.html` run up to x≈643.35, y≈949.95
within a 720×1057 image, so **the existing maps are in the 720×1057 space** and neither transfer
to 1162×1684 by a single scale factor without registration.

## 3. Broad source survey (fresh)

### 3.1 Qamar artwork (APK + web eBook)

- Pros: complete 847 Quran-bearing pages, matching coordinate maps already present (APK),
  plausible CC BY-SA 4.0, verified map defects are localized (e.g. 26:143/26:144).
- Cons: ambiguous license scope; APK resolution low (720×1057); web eBook resolution higher but
  unconfirmed identical; needs licensing clarification and map repair/review.

### 3.2 QUL / Tarteel (layout + fonts, not scans)

- `https://qul.tarteel.ai/resources/mushaf-layout/236` — "Indopak 13 lines layout (Qudratullah)",
  **849 pages**.
- `https://qul.tarteel.ai/resources/mushaf-layout/313` — "Indopak 13 lines layout (Taj company)",
  **847 pages**.
- These layouts are **font-based** (per-page fonts such as `p1.ttf`/`p1.woff2`) with
  word/line/page position data, not scanned ink. Metadata advertises downloading the layout
  "as JSON data — line, page and word position data".
- The export path is a **SQLite database delivered by email to an account holder**
  (`Export::MushafLayoutExportJob`), so access requires an account.
- Code repository `TarteelAI/quranic-universal-library` is **MIT** (verified: repo license
  `MIT`, `LICENSE` present). MIT covers the *code*, not necessarily the data/assets.
- QUL FAQ: "The resources available on QUL vary in their copyright status. Some are in the
  public domain, while others may be subject to specific licenses. We recommend reviewing the
  licensing information provided by each resource's author before use."
- Best role: an **authentic-pagination, font-rendered** path for the exact 849-page Qudratullah
  layout (or 847 Taj) with machine-readable geometry — not a facsimile of printed ink. Would
  require confirming per-layout data license/attribution.

### 3.3 Publishers (physical only, no digital license found)

- Taj Company — `https://tajquran.com/`: sells 13-line Muarra/Tajweed editions, has Android
  apps ("checked by certified Quran Proofreaders"); no downloadable artwork or license.
  Contact `orders@tajquran.com`.
- Qudratullah Company — `https://qudratullah.com.pk/`: sells 13-line and 15-line editions; no
  digital assets or license. Contact via the site.
- Neither publisher exposes a licensable high-resolution digital edition.

### 3.4 Dawat-e-Hidayat

- `https://www.dawatehidayat.org/pages/13line_quran.html`: 30 Juz PDFs (~1.2–1.8 MB each),
  complete ZIPs (~39 MB) and a color-coded Tajweed PDF (~79 MB).
- Small per-Juz sizes suggest modest native resolution; no permission/rights statement found.
- Lead only.

### 3.5 Internet Archive

| Identifier | Original file | Size | Rights / notes |
|---|---|---|---|
| `QuranAl-majeed-13Line` | `1-QuraanAlMajeed13Line-Complete.pdf` | 34.1 MB | **CC BY-NC-ND 3.0** — NonCommercial + NoDerivatives. **Incompatible** with an app that rescales/annotates and may monetize. Reject. |
| `13LinesQuran-by-zAk` | `13LinesQuran-ByzAk.pdf` | 63.8 MB | CC0, but creator = inter-islam.org; rights not established by the tag. |
| `13-line-quran` (2025) | `13 line Quran.pdf` | 44.7 MB | Uploader chose **Public Domain Mark**; `ppi` 300; "Text PDF". Not provenance. |
| `AlQuran13LinesQudratUllahCompany` | `AlQuran13LinesQudratUllahCompany.pdf` | 17,289,466 B | "Image Container PDF", `ppi` 450, no license field. |
| `holy-quran-13-lines-qudratullah-company` | `Holy Quran- 13-Lines Qudratullah Company.pdf` | 17,289,466 B | Same size as above → probable duplicate. No license field. |
| `qm-13-ln` | `Complete Quraan 13 Line IP New.pdf` | 141.1 MB | "Text PDF", creator Waterval Islamic Institute / Nurul Huda. |
| `dalcanciaa-quran-13-line-tajweed-pack` | `tajweed_pack.zip` | 151.5 MB | "Complete offline **850** color-coded Tajweed page pack for 13-line Quran app". License not shown. |
| `13-line-clear-quran-hifz-english-scan` | PDF | 23.8 MB | Mustafa Khattab "Clear Quran" — translation likely copyrighted. |

Note: the earlier-audited Archive item
`13-line-quran-with-beautiful-color-coded-tajweed-rules-pdf` (original 82.8 MB PDF, 850-page
header, sampled embedded images 720×1057) is consistent with the Qamar artwork, but direction
of derivation is unproven.

The **`dalcanciaa-quran-13-line-tajweed-pack`** item (850 pages, 151.5 MB) is directly relevant
to the previously found GitHub lead `dalcanciaa/quran-13-line-assets` (whose repo root held only
a README). It should be inspected next, including any bundled license.

### 3.6 GitHub repositories (image/PDF packs)

| Repository | Content | License |
|---|---|---|
| `asadktp/13_Line_Quraan` | "13 Line Quran JPEG", **847** JPEGs across `Juz_1/…`, ~160–230 KB each, repo ~114 MB | **No license file** (all rights reserved by default) |
| `Aban3049/-Quran-Pdf-s-Black-White-13-Line` | 30 Juz PDFs, ~1.3–1.9 MB each | No license file |
| `MohsinIshfaq/Qalam-Quran-App` | `assets/mushaf/13_line/complete_quran_13_line.pdf` 44.8 MB + 30 Juz PDFs | `LICENSE` present (1070 B, likely code license; PDFs unclear) |
| `akeelamini1-coder/13` | "13 Line Quran Juz 1" only | No license; partial |
| `dalcanciaa/quran-13-line-assets` | root README only | n/a |

A complete 847-page JPEG set (`asadktp`) is notable, but with no license it cannot be used
without permission.

### 3.7 Quran.com / other APIs

- `https://api.quran.com/api/v4/mushafs` (re-inspected) still does not expose a 13-line image
  edition. This is not proof that none exists privately.

## 4. Comparison summary

| Candidate | Pagination | Native resolution | Coordinates | Rights clarity | Verdict |
|---|---|---|---|---|---|
| Qamar APK artwork | 847 Quran pages | 720×1057 | Yes (720×1057 space) | Ambiguous CC BY-SA 4.0 vs copyright notice | Practical; needs written clarification + map repair |
| Qamar web eBook | 854 viewer pages (847 Quran) | **1162×1684** | No (would need new maps) | Same Qamar ambiguity | Higher-res lead; identity unconfirmed |
| QUL layout 236 | **849** (Qudratullah) | Font (vector) | Yes (word/line JSON/SQLite) | Code MIT; data terms per-resource | Best for exact-849 authentic pagination, font-rendered |
| QUL layout 313 | 847 (Taj) | Font (vector) | Yes | as above | Font alternative |
| Taj / Qudratullah publishers | print editions | print | no | physical purchase only | No digital license found |
| Dawat-e-Hidayat PDFs | 30 Juz | likely low | no | no statement | Lead only |
| Archive `QuranAl-majeed-13Line` | 13-line | ? | no | CC BY-NC-ND | **Incompatible** |
| Archive `dalcanciaa…tajweed-pack` | 850 pages | ? | no | unknown | Inspect next (151 MB, 850 pages) |
| GitHub `asadktp/13_Line_Quraan` | 847 | JPEG ~160–230 KB | no | none (ARR) | Permission required |
| Generative upscaling | — | — | — | — | **Rejected** (can fabricate Quranic detail) |

## 5. Recommendation

**A. If a 847-page edition is acceptable (recommended practical path):**
Use **Qamar's own artwork** as the image edition, because it is the only surveyed candidate with
complete pagination *and* existing coordinate maps. Preferred order:

1. Obtain **written clarification** of the CC BY-SA 4.0 scope from `support@qamarapps.com`
   (exact images and maps, redistribution in an app, derivative forms).
2. Verify whether the **1162×1684 web eBook** is the same edition as the APK by human
   side-by-side inspection; if yes, prefer it and rescale/register the maps (or build new maps),
   if no, keep the APK images as a separate edition.
3. Repair the known map defects (e.g. 26:143/26:144 zero-area regions) and run the human review
   in the implementation plan.

**B. If exact 849-page Qudratullah continuity is mandatory:**
Use **QUL layout 236 (Indopak 13 lines, Qudratullah, 849 pages)** with its per-page fonts and
word/line position data, after confirming the per-layout data terms. This reproduces the exact
849-page pagination with machine-readable geometry, though it is a font rendering rather than a
facsimile of printed ink. Alternatives:

- license native-resolution 849-page artwork directly from Qudratullah (no digital license found
  yet), or
- commission a rights-cleared high-resolution scan of an authorized print.

**Do not** ship a 847-page edition relabelled as 849, and do not use CC BY-NC-ND or unlicensed
packs. Keep development on rights-safe synthetic fixtures until a decision record
(`docs/mushaf/EDITION_DECISION.md`) is APPROVED.

## 6. Open items

1. Send and log the Qamar licensing clarification request.
2. Human side-by-side: web eBook vs APK vs QUL layout for the same ayah.
3. Inspect `dalcanciaa-quran-13-line-tajweed-pack` contents and any license.
4. Confirm QUL per-layout data license/attribution for layouts 236 and 313.
5. Confirm native resolution of the Archive Qudratullah PDFs (e.g. `AlQuran13LinesQudratUllahCompany`)
   versus the APK 720×1057.
