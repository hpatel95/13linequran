# Product Specification, Feature Classification & Roadmap

## 1. Product Vision (restated as design constraints)

Every feature decision below is filtered through: *does this serve someone who opens this app to read Quran almost every day for years?* If a feature exists mainly to look impressive in a screenshot, cut it. Calm beats clever.

---

## 2. Core Reading Experience

| Feature | V1 | Notes |
|---|---|---|
| 13-line Mushaf rendering (single page) | **Free** | The core product. Must be flawless before anything else ships. |
| Two-page spread (landscape/iPad) | **Free** | Requested repeatedly by hafiz users in competitor reviews; matches how people actually memorize (they remember page *shape*). |
| Swipe between pages | **Free** | Primary navigation. Must feel like turning a physical page — no jank, no flash of unstyled content. |
| Tap-to-navigate (surah/juz/page picker) | **Free** | |
| Search (by surah name, juz, page number, and Arabic/translated text) | **Free** (text search may be **Premium** if it requires downloading extra search-index content — see doc 04) | |
| Bookmarks (unlimited) | **Free** | This is core utility, not premium bait. |
| Last-read position (auto-saved) | **Free** | Non-negotiable baseline expectation. |
| Reading history/log | **Free** | Simple local log of pages visited with timestamps. |
| Dark mode | **Free** | |
| Light mode | **Free** | |
| Sepia/"paper" reading mode | **Free** | Common, cheap to build, genuinely useful for low-light reading without full dark mode's harsh contrast against Arabic glyphs. |
| Adjustable page/text scale (zoom level, not font substitution) | **Free** | See religious-appropriateness note below. |
| Pinch-to-zoom on the Mushaf page | **Free** | |
| Landscape/portrait adaptive layout | **Free** | Portrait = single page; landscape = two-page spread on larger devices. |
| Keep-awake while reading | **Free** | `UIApplication.isIdleTimerDisabled` while the reader is foregrounded; huge, cheap UX win (competitor reviews call this out explicitly as a wanted feature). |
| Page numbers, Juz/Hizb/Rub' indicators | **Free** | Structural metadata, must be 100% accurate (see doc 05's verification pipeline). |
| Sajdah (prostration) indicators | **Free** | |
| Manzil navigation | **Premium or V1.1** | Lower-traffic navigation mode; fine to ship slightly later. |
| Surah information panel (revelation place, ayah count, themes) | **Free**, sourced text | Short, scholarly-reviewed blurb per surah. |
| Ayah selection (tap to select a single ayah) | **Free** | Needed as the entry point for copy/share/bookmark-single-ayah/play-from-here. |
| Copy ayah text (Arabic + active translation) | **Free** | |
| Share ayah (as styled image or text) | **Free**, basic; **Premium**, custom-styled share cards | |
| Notes on ayahs | **Premium** | Meaningful "study tool" tier feature; keep simple (plain text, one note per ayah) in V1. |
| Highlights/color tags on ayahs | **Premium** | |

**A religious/typographic note on "adjustable text presentation":** for a Mushaf-format app, the Arabic page must render as a faithful reproduction of the fixed page layout — you are not free to reflow Arabic text to different font sizes the way you would an ordinary reading app, because ayah-per-line and ayah-per-page placement is part of what makes a "13-line Mushaf" a 13-line Mushaf (this is exactly what memorizers rely on — the spatial memory of where an ayah sits on the page). **Zoom (pinch/pan) is the correct mechanism, not reflow.** Reflow is appropriate for the *translation panel* only. Flag this distinction clearly for your AI coding agent — it is an easy, damaging mistake to "helpfully" make Arabic text Dynamic-Type-reflowable like the rest of the UI.

---

## 3. Audio

| Feature | V1 | Notes |
|---|---|---|
| 2–4 reciters at launch | **Free tier: 1 reciter** streaming-only; **Premium: full reciter roster + offline** | Fewer, well-chosen reciters beats a huge mediocre list. Source via Quran Foundation's audio API (see doc 05). |
| Ayah-by-ayah playback with highlight-as-read | **Free** | Table-stakes for a Mushaf app used for recitation practice. |
| Continuous surah/juz playback | **Free** | |
| Repeat single ayah | **Free** | |
| Repeat range (ayah X to Y, N times) | **Premium** | Real memorization utility — reasonable to gate. |
| Background audio + lock-screen controls (MPNowPlayingInfoCenter) | **Free** | Required baseline for any audio app; not a premium feature by convention or guideline. |
| AirPods/Bluetooth remote controls (play/pause/skip) | **Free** | Comes largely "for free" from correct `MPRemoteCommandCenter` integration. |
| Offline download management (per-surah, per-reciter, per-juz packs) | **Free: manual per-surah**; **Premium: full-Quran one-tap download, multiple reciters offline simultaneously** | |
| Playback speed control | **Free** | |
| Sleep timer | **Free** | Cheap, well-loved utility. |
| Audio quality selection (data-saver vs. high quality) | **Free** | Respect users on limited data plans — a real consideration for a global Muslim audience. |

---

## 4. Translation & Tafsir

| Feature | V1 | Notes |
|---|---|---|
| One default translation, Arabic + translation view | **Free** | See doc 05 for exactly which translation(s) are safe to ship day one. |
| 2–4 additional translations | **Premium** | Gate *variety*, not *access* — never gate the only translation a first-time user needs. |
| Ayah-by-ayah translation view (vs. Arabic-only Mushaf view) | **Free** | This is effectively a second "reading mode," not a premium feature. |
| One tafsir (e.g., a well-known, rights-clear commentary) | **Premium** | Tafsir is a deeper study tool; reasonable to place behind the paywall, unlike the translation itself. |
| Additional tafsir volumes | **Premium** | |
| Language selection for translation/tafsir UI | **Free** | |
| Downloadable offline translation/tafsir packs | **Free** for the default translation; **Premium** for the rest | |

---

## 5. Reading Tools, Habit & Progress

Be ruthless here — this is where feature creep kills calm apps.

| Feature | V1 | Notes |
|---|---|---|
| Bookmarks | **Free** | (repeated from above for completeness) |
| Collections (grouping bookmarks) | **Premium, V1.1** | Nice-to-have, not core. |
| Notes | **Premium** | |
| Highlights | **Premium** | |
| Reading streak (consecutive days opened + read) | **Free** | Cheap, motivating, zero privacy cost if fully local. |
| Simple daily reading goal (e.g., "N pages/day") | **Free** | |
| Khatm (full-Quran completion) planner | **Premium** | Real feature with real complexity (pacing math, catch-up logic) — appropriate for the paid tier, but should exist in V1 if you want a differentiated "serious reader" pitch. |
| Progress tracking (pages/juz completed) | **Free**, basic; **Premium**, detailed stats/history | |
| Local notifications/reminders (custom reading time) | **Free** | No push infrastructure needed — local `UNNotificationRequest` only. |
| "Daily ayah" | **V1.1**, Free | Nice retention hook, not core-loop critical for V1. |
| Cross-device last-read sync | **Premium**, via CloudKit private database | See doc 03/06 — this is the *only* sync feature that should exist in V1, and it should never require a login. |

---

## 6. What is explicitly NOT in V1

Say no to, for now: social features of any kind, user-generated content (guideline §1.2 overhead for zero product benefit here), Apple Watch app, widgets beyond a simple "resume reading" widget, Siri/Shortcuts integration, iPad-specific redesign beyond responsive layout, Mac Catalyst, AI-based recitation feedback (that's Tarteel's whole product — don't half-build it), community/sharing features, gamification beyond a simple streak counter, multiple qira'at (recitation styles) beyond Hafs, any advertising of any kind.

---

## 7. V1 / V1.1 / V1.5 / V2 Roadmap

### V1 — Must launch (the "exceptionally polished, small" release)
- Single 13-line Mushaf layout, Hafs recitation, Uthmani/IndoPak script rendered from verified structured data (not scanned images)
- Surah/juz/page/ruku navigation, search, bookmarks, last-read position, reading history
- Light/dark/sepia modes, pinch-zoom, landscape two-page spread, keep-awake
- 1 free reciter (streaming) + full offline download as the flagship premium unlock
- 1 free translation (ayah-by-ayah view) + 2–3 premium translations
- 1 premium tafsir
- Simple streak + reading goal (free), khatm planner (premium)
- Onboarding, one clear paywall, StoreKit 2 subscription (monthly/annual) with a free trial
- No login required; optional CloudKit-based last-read sync as the only account-adjacent feature
- Full accessibility pass (VoiceOver, Dynamic Type on UI chrome, contrast)
- Privacy policy, App Privacy questionnaire, all legal review items from doc 01 closed out

### V1.1 — Important improvements
- Collections (organized bookmarks), "daily ayah" surface, additional reciters, repeat-range playback, notes search, widget for resume-reading, Manzil navigation, additional language localizations for UI chrome

### V1.5 — Advanced features
- Additional Mushaf layout option (e.g., standard 15-line Uthmani, as an alternate "Mushaf" the user can switch to) — a natural, content-architecture-compatible expansion once the pipeline in doc 05 is proven
- Additional qira'at (recitation styles) if licensing allows
- Study-mode enhancements: word-by-word translation/morphology overlay, similar-ayah discovery
- Apple Watch companion (streak + simple resume)
- Family sharing support for subscription

### V2 — Ambitious
- iPad-optimized multi-pane study layout
- Offline-first, on-device semantic search across translations
- Deeper habit/community features *if* validated by V1 retention data (not assumed upfront)
- Additional platforms (macOS Catalyst) if usage data supports it

---

## 8. Monetization Strategy

**Model:** single auto-renewable subscription ("Premium"), monthly + annual, StoreKit 2, with a free trial (7–14 days) per Apple's subscription rules (§3.1.2 requires ≥7-day minimum period, which a trial period naturally satisfies). Consider one **lifetime/non-consumable** option in V1.1+ once you have real conversion data — a meaningful share of religious-app users specifically dislike recurring subscriptions for a "book," and a one-time option is a strong trust signal, even if priced at a premium multiple of annual (e.g., 3–4x annual price).

**What's free vs. paid, restated as a single sentence:** *the Quran itself, one translation, one reciter, and all core navigation/reading tools are permanently free; the subscription monetizes convenience and depth — more translations, more reciters with full offline packs, tafsir, notes/highlights, khatm planning, and detailed progress.*

**Pricing recommendation (judgment call, not a verified fact):** anchor below the "AI/everything app" tier (Muslim Pro/Tarteel sit at ~$12.99/month). Target **$2.99–$4.99/month or $19.99–$29.99/year**, with an optional lifetime unlock around $59.99–$79.99 once validated. This reflects: (a) strong free competitors set a low anchor for "just reading," (b) your paid tier is convenience/depth, not access to revelation, which matters for trust and word-of-mouth in this specific community, (c) a lower price increases the odds of sustainable long-term subscriptions from a values-driven, price-sensitive-but-loyal user base.

**Do not:** run ads (guideline-compliant but destroys the "calm, trustworthy" positioning and directly conflicts with your privacy differentiation against Muslim Pro), gate the Arabic text or the one free translation behind any paywall (this alone would likely draw negative reviews and community backlash independent of App Review), or use dark patterns in the paywall (§5.6 Developer Code of Conduct explicitly calls out "manipulative practices" and "raising prices in a tricky manner").
