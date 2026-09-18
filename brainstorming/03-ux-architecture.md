# UX Architecture

## 1. Design Principles (apply to every screen below)

1. **The Mushaf is the home screen.** Most apps put a dashboard first. This app should open straight into the reading experience (last-read page) after first launch — everything else (search, bookmarks, settings) is one tap away via a minimal chrome that disappears while reading.
2. **Chrome recedes.** Navigation bars, tab bars, and controls fade out on read/scroll and reappear on tap — the page should fill the screen when someone is actually reading.
3. **No modals for reading actions.** Ayah selection, translation toggle, and audio controls live in lightweight sheets/overlays, never full-screen takeovers that break reading flow.
4. **Every screen must have a legible empty/loading/error state** — silence and blank screens are the most common "why does this feel unfinished" complaint in app reviews.

---

## 2. App Navigation Structure

Bottom tab bar, 4 items (kept deliberately small):

1. **Read** (default/home) — the Mushaf reader, opens to last-read position
2. **Discover** — surah list, juz list, search, surah info
3. **Bookmarks** — bookmarks, notes/highlights (premium), reading history
4. **Progress** — streak, reading goal, khatm planner (premium), settings entry point

A persistent, unobtrusive "Settings" gear lives in the Progress tab rather than consuming a 5th tab slot — settings are low-frequency.

---

## 3. Screen-by-Screen Specification

### 3.1 Onboarding
- **Purpose:** get a first-time user reading within ~15 seconds, establish trust (privacy-first, no forced login) before asking for anything.
- **Layout:** 3 short screens max — (1) welcome + core promise ("Read the 13-line Mushaf, beautifully, offline"), (2) choose default translation + reciter (with sensible defaults pre-selected so skipping is safe), (3) notification permission ask *only if* the user opts into a reading reminder — never ask for permissions the user hasn't invited.
- **Interactions:** "Continue" primary action each screen; a visible "Skip" everywhere except step 1.
- **Empty/loading:** initial content download (Arabic text + first translation) happens here, with a calm progress indicator and estimated size/time — not a spinner with no context.
- **Error state:** offline at first launch → clear message ("You'll need an internet connection once to download the Quran text — about X MB — then everything works offline") with a retry button, not a dead end.
- **Accessibility:** each onboarding screen fully VoiceOver-labeled; skip button always reachable first via VoiceOver rotor.
- **Dark mode:** onboarding respects system appearance from first frame — no flash of light theme before dark mode applies.

### 3.2 Reader (core screen)
- **Purpose:** display the current Mushaf page(s) faithfully and let the user move through the Quran with minimal friction.
- **Layout:** portrait = single page, centered, page number + surah/juz indicator in a slim top bar that auto-hides; landscape (or iPad) = two-page spread. Bottom-edge swipe-up reveals a lightweight ayah/audio toolbar.
- **Components:** page canvas (custom rendering, see doc 04), page-turn swipe gesture with a subtle animation matching a physical page, tap-and-hold or tap on an ayah for the selection popover (copy/share/bookmark/note/play-from-here), floating mini audio-player bar when audio is active, pull-down (or tap top bar) to reveal surah/juz/page jump control.
- **Interactions:** horizontal swipe = next/previous page; tap edge zones = same (large touch targets, no accidental triggers); pinch = zoom; double-tap = quick zoom toggle; long-press ayah = selection mode.
- **Empty state:** N/A (there is always a page to show once content is downloaded); if content isn't yet downloaded, show the onboarding download flow instead of an empty reader.
- **Loading state:** page transitions must be instantaneous (pre-rendered/cached adjacent pages) — a spinner here would be a serious UX failure for the core loop.
- **Error state:** if a specific asset (e.g., a font glyph or an audio file) fails to load, degrade gracefully (fall back to a system font glyph rather than showing a blank/broken box) and log the failure silently to crash reporting — never show a raw error to the user mid-read.
- **Accessibility:** VoiceOver reads ayah-by-ayah (using the underlying Unicode text layer, not glyph images — see doc 04's accessibility risk note), with rotor navigation by ayah/surah; Dynamic Type affects the surrounding chrome (buttons, labels) but not the fixed Mushaf page layout itself (see doc 02's typographic note); Reduce Motion disables the page-turn animation in favor of an instant cut.
- **Dark mode:** the Mushaf page itself should use a dedicated "reading" palette per mode (true black backgrounds are harsh for long reading sessions; prefer a soft dark warm-grey in dark mode and a warm off-white/sepia rather than pure white in light mode) — this is a place to invest real design care.

### 3.3 Translation/Tafsir Panel
- **Purpose:** show the selected ayah's translation/tafsir without leaving the reading context.
- **Layout:** bottom sheet, resizable (peek/half/full), dismissible by swipe-down; Arabic ayah repeated at the top of the sheet for context, translation text reflows normally (Dynamic Type applies here, unlike the Mushaf page).
- **Interactions:** swipe between ayahs within the sheet without closing it; tab/segmented control to switch translation or tafsir source if multiple are downloaded.
- **Empty state:** if a premium translation/tafsir isn't downloaded, show a clear inline "Download" or "Unlock with Premium" affordance rather than hiding the option entirely.
- **Loading/error:** inline skeleton text while downloading; clear retry on failure.
- **Accessibility:** sheet is a proper accessibility container with a clear heading; VoiceOver users can dismiss via a standard "Close" button, not gesture-only.

### 3.4 Discover (Surah / Juz / Search)
- **Purpose:** fast navigation to any point in the Quran by name, number, or content.
- **Layout:** segmented control at top (Surah / Juz), search field always visible above the list; tapping a surah/juz row jumps straight into the Reader.
- **Components:** surah rows show name (Arabic + transliteration + translation), revelation place, ayah count, and last-read indicator if applicable; search results show matched text with the match highlighted and surah:ayah reference.
- **Interactions:** search is instant/incremental (debounced), works across surah names, transliterations, and (if downloaded) translation text; tapping a result deep-links straight to that ayah's page.
- **Empty state:** no results → a warm, specific message ("No matches for 'X' — try a surah name or page number") rather than a generic blank list.
- **Loading:** if searching translation text that hasn't been downloaded yet, prompt to download rather than silently returning incomplete results.
- **Error:** N/A mostly (local search); if remote lookup is ever involved, standard retry pattern.
- **Accessibility:** search field auto-focuses appropriately (not on VoiceOver, to avoid stealing focus unexpectedly); list rows are single accessible elements combining all the row's text into one coherent label.
- **Dark mode:** standard system list styling, high-contrast search highlight in both modes.

### 3.5 Bookmarks / Notes / History
- **Purpose:** a single place to revisit saved ayahs, personal notes/highlights (premium), and recent reading activity.
- **Layout:** segmented control (Bookmarks / Notes & Highlights / History); each row shows ayah reference, a short Arabic snippet, and timestamp.
- **Interactions:** swipe-to-delete; tap to jump to that ayah in the Reader; long-press for quick actions (edit note, change highlight color).
- **Empty state:** distinct, encouraging empty states per tab ("Bookmarks you save while reading will show up here" with a small illustrative icon, not just blank).
- **Loading:** instantaneous (all local data).
- **Error:** N/A (local-only); if CloudKit sync is enabled and fails, show a small non-blocking "sync paused" indicator rather than an alarming error.
- **Accessibility:** swipe-actions must have VoiceOver-accessible equivalents (custom actions on the row), not gesture-only delete.

### 3.6 Progress / Streak / Khatm Planner
- **Purpose:** light, non-gamified motivation — how much you've read, how consistent you've been, and (premium) a structured plan to finish the whole Quran.
- **Layout:** simple stat cards (streak count, pages read this week, % of Quran completed) above a khatm planner card (premium) showing a calculated daily-page target and a calendar-style progress view.
- **Interactions:** tapping the khatm card (free users) shows a premium upsell explaining exactly what it does — never a bare paywall with no context.
- **Empty state:** first-time view explains what the stats will show once you start reading, rather than showing "0" everywhere with no framing.
- **Loading/Error:** local-only, instantaneous; no error states beyond corrupt-local-data recovery (see doc 07 security section).
- **Accessibility:** stats read as full sentences to VoiceOver ("7-day reading streak", not a bare "7").

### 3.7 Settings
- **Architecture (grouped list):**
  - **Reading:** default translation, default reciter, Arabic script/Mushaf layout (if more than one is offered later), theme (light/dark/sepia/system), keep-awake toggle, zoom reset
  - **Audio:** playback speed default, sleep timer default, download quality, manage downloads (per-reciter storage used, with a clear "delete" per item)
  - **Notifications:** reading reminder toggle + time picker (local notifications only)
  - **Premium:** subscription status, manage/restore purchases, "What's included" explainer
  - **Privacy:** link to privacy policy, link to terms, data-collection summary in plain language, "export my data" / "delete my data" actions
  - **About:** version, content sources & attributions (required by your content licenses — see doc 05), acknowledgments, support/contact link (required by guideline §1.5)
- **Interactions:** standard grouped-table navigation; destructive actions (delete downloads, delete data) require confirmation.
- **Empty/loading/error:** settings load instantly from local state; subscription status has a small loading state while StoreKit confirms entitlement on cold launch.
- **Accessibility:** every row has a clear label + value announced together ("Default translation, Saheeh International").
- **Dark mode:** standard system grouped-list appearance in both modes.

### 3.8 Paywall
- **Purpose:** convert clearly and honestly, without dark patterns.
- **Layout:** use StoreKit 2's native `SubscriptionStoreView` as the backbone (reduces custom-code surface for a vibe-coded app — fewer places to introduce compliance bugs) with a custom header above it explaining, in plain language and 3–4 concrete bullet points, exactly what premium unlocks (translations, reciters+offline, tafsir, notes, khatm planner) — no vague "unlock everything" language.
- **Interactions:** always show price, billing period, and cancellation info before purchase (guideline §3.1.2(c)/§4.9); a visible, easy-to-find "Restore Purchases" button; a close/dismiss button that is never hidden or delayed (no forced 5-second wait before the X appears).
- **Empty/loading:** while StoreKit product data loads, show the benefit copy immediately and let prices populate in place rather than blocking the whole screen on a spinner.
- **Error:** StoreKit unavailable (e.g., no network) → clear message, not a silent failure; purchase failures show the actual reason where StoreKit provides one.
- **Accessibility:** every price/term is announced by VoiceOver in full sentences, not just visually implied by layout.
- **Dark mode:** consistent with the app's calm visual language — no jarring "salesy" bright colors that break the app's overall tone.

### 3.9 Download / Offline Management
- **Purpose:** give the user clear, granular control over what's stored on-device.
- **Layout:** grouped by content type (Mushaf text/pages, Translations, Tafsir, Audio by reciter), each row shows size and download/delete state.
- **Interactions:** batch "Download all" and per-item download/delete; visible progress bars during download; Wi-Fi-only download toggle in Settings.
- **Empty/loading:** clear per-item progress (%, MB downloaded/total) — never an indefinite spinner for a multi-MB download.
- **Error:** paused/failed downloads show a retry affordance inline, and the app must gracefully resume rather than restart from zero after an interruption (see doc 07 reliability section).
- **Accessibility:** progress announced periodically to VoiceOver (not on every percentage tick — throttled announcements).

### 3.10 Audio Player (expanded / full-screen)
- **Purpose:** full playback controls when audio is the primary focus (e.g., listening while not actively looking at the page).
- **Layout:** reciter name/photo (if available and rights-permit), current surah:ayah, scrubber, repeat/sleep-timer/speed controls, lock-screen-equivalent transport controls mirrored here.
- **Interactions:** standard media controls; repeat-range picker (premium) as a simple two-value ayah picker.
- **Empty/loading/error:** buffering state clearly shown; offline playback of undownloaded content shows a clear "not downloaded" state with a one-tap download action instead of silent failure.
- **Accessibility:** full VoiceOver support for all transport controls; works correctly with the physical remote/AirPods controls and Control Center.

### 3.11 Profile / Account
- **Not needed as a distinct screen in V1.** There is no login. "Account" surface is limited to the Premium subscription status shown inside Settings (§3.7) and, if CloudKit sync is enabled, a simple "Synced with iCloud" indicator with no separate account screen, credentials, or profile data — consistent with the local-first, no-mandatory-account architecture recommended throughout this research.

---

## 4. Key User Flows (end-to-end)

1. **First launch → reading:** Onboarding (pick translation/reciter, download core content) → lands directly on Al-Fatiha, page 1 → user starts reading immediately.
2. **Daily return:** App launch → Reader opens directly to last-read page (no home screen detour) → streak indicator briefly acknowledges the day's visit → user reads.
3. **Discovering a specific ayah:** Tab to Discover → search or browse → tap result → Reader opens to that exact page with the target ayah briefly highlighted.
4. **Studying an ayah:** In Reader, tap ayah → selection popover → "Translation" opens the bottom sheet → user reads translation/tafsir without losing their page.
5. **Listening while following along:** Tap ayah → "Play from here" → mini player appears → ayah highlighting advances in sync → user can background the app and control playback from the lock screen.
6. **Upgrading to Premium:** User taps a gated feature (e.g., a second translation) → contextual paywall explaining specifically what that action unlocks → StoreKit purchase sheet → immediate unlock, no app restart required.
7. **Going offline intentionally (e.g., before travel):** Settings → Downloads → "Download all" → clear per-item progress → confirmation when complete → app is fully usable offline from that point, verified by a lightweight offline-mode indicator when connectivity drops.
