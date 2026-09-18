# Vibe-Coding Development Roadmap (Phases 0–16)

## How to use this document
Each phase is a self-contained unit of work for your AI coding agent. **Never ask an agent to jump ahead to a later phase's files.** Complete each phase's Definition of Done before starting the next. The copy-paste prompts in document 09 correspond 1:1 to these phases — this document explains *why* each phase exists and what "done" means; document 09 is what you actually paste into your coding agent.

Your originally-proposed phase sequence was good; two adjustments based on this research: **Phase 4 (Quran content engine) must come before any UI work beyond basic scaffolding**, since the content-verification pipeline and licensing decisions from doc 05 constrain how the reader can be built — building the reader first and retrofitting content integrity later is the single biggest rework risk in this project. And **licensing outreach (emails to Quran Foundation / Tarteel-QUL) should start in Phase 0, in parallel with engineering, not block it** — engineering can proceed on the technical pipeline using the CC-BY Tanzil corpus as a placeholder/reference dataset while those confirmations are pending.

---

### Phase 0 — Research & Content Licensing (parallel, not blocking)
- **Objective:** get written commercial-use confirmations in motion; finalize the exact translation/tafsir/reciter list for V1.
- **Dependencies:** none.
- **Deliverables:** emails sent to Quran Foundation and Tarteel/QUL (doc 05 §2.2/2.6); a confirmed V1 content list (1 translation, 1 tafsir, 1–2 reciters) with licensing status noted per item; IP attorney engaged.
- **Not an engineering phase** — no code written here.
- **Risk:** licensing responses may take weeks; don't let this block Phase 1–3, which are content-source-agnostic.

### Phase 1 — Product Specification
- **Objective:** lock the V1 scope (doc 02) as a concrete, written reference the coding agent can be pointed at.
- **Deliverables:** doc 02 (already produced) treated as the source of truth; a short internal "V1 scope lock" note confirming what's explicitly excluded, to prevent scope creep once building starts.
- **Definition of done:** you can answer "is X in V1?" for any feature by pointing at doc 02 without re-litigating it.

### Phase 2 — Design System
- **Objective:** establish the visual language (colors, typography, spacing, the light/dark/sepia reading palettes) before any screen is built, so every subsequent phase draws from one consistent source.
- **Deliverables:** a `DesignSystem` module (doc 04 §4) — color tokens (including the three reading-mode palettes), type scale, spacing constants, and 2–3 reusable components (primary button, card, list row) built and visually reviewed in isolation (e.g., in a SwiftUI preview canvas), before any real screen consumes them.
- **Tests:** none required beyond visual review; this phase produces no business logic.
- **Definition of done:** you've looked at the reading-mode palettes on an actual device in a dark room and a bright room and they feel calm and legible in both.
- **Risk:** if skipped, every subsequent phase invents its own colors/spacing, and unifying them later is expensive — do not skip this phase to "save time."

### Phase 3 — Project Scaffolding
- **Objective:** stand up the folder structure (doc 04 §4), app entry point, and empty tab navigation shell with placeholder screens.
- **Deliverables:** a launchable app with the 4-tab structure (Read/Discover/Bookmarks/Progress) navigating between empty placeholder screens; CI configured to run tests on every commit (even though there are few tests yet).
- **Tests:** a basic smoke test confirming the app launches and each tab is reachable.
- **Definition of done:** the app runs on a real device, tab navigation works, and the project structure matches doc 04 §4 exactly (so every later phase has a predictable place to put its files).

### Phase 4 — Quran Content Engine (the most important engineering phase)
- **Objective:** build the read-only content database layer, the golden reference corpus, and the full content-verification pipeline from doc 05 §6 — before any reader UI exists.
- **Dependencies:** Phase 3.
- **Deliverables:** bundled SQLite content database (Arabic text + 13-line layout data + metadata, sourced per doc 05, using Tanzil's CC-BY corpus as the working reference while Phase 0's licensing confirmations are pending), the `ContentIntegrity` test suite (byte-for-byte diff, ayah counts, no duplicates/gaps, Unicode integrity, sajdah positions), and a `QuranContentStore` service exposing read APIs (get page, get ayah, get surah metadata) to the rest of the app.
- **Tests:** the full integrity suite from doc 05 §6/doc 07 §2, run in CI on every commit from this point forward.
- **Definition of done:** the integrity suite passes; a throwaway debug screen can print any ayah's text and metadata correctly; **no reader UI exists yet, and that's correct** — this phase is entirely about the data being provably right before anyone builds a way to look at it.
- **Risk:** the temptation to "just get something on screen" and skip straight to Phase 5 — resist this; it inverts the risk order for the one part of this app where a mistake is unacceptable.

### Phase 5 — Mushaf Reader
- **Objective:** build the actual page-rendering UI, consuming `QuranContentStore` from Phase 4.
- **Dependencies:** Phase 2 (design system), Phase 4 (content + verified data).
- **Deliverables:** the Reader screen (doc 03 §3.2) — page canvas rendering from structured layout data, swipe/tap navigation, pinch-zoom, light/dark/sepia modes, portrait single-page and landscape two-page layouts, keep-awake while in the reader.
- **Tests:** snapshot/visual-regression tests for a representative sample of pages (including surah-boundary pages, sajdah pages, juz-boundary pages); a navigation test suite (swipe forward/back at every boundary condition from doc 07 §1).
- **Definition of done:** you can read the entire first juz on a real device, in all three appearance modes, in both orientations, and it feels calm and fast — no placeholder content remains.

### Phase 6 — Navigation & Search
- **Objective:** build the Discover tab (doc 03 §3.4) — surah/juz lists, search, deep-linking into the Reader.
- **Dependencies:** Phase 5.
- **Deliverables:** surah/juz list screens, incremental search (surah name, page number, and — once a translation is bundled — translation text via SQLite FTS5), deep-link navigation from any search result directly into the correct Reader page.
- **Tests:** search-result-accuracy tests against known queries; deep-link tests confirming exact-page-and-ayah landing.
- **Definition of done:** every surah/juz/page is reachable in under 3 taps from any screen in the app.

### Phase 7 — Audio
- **Objective:** build the audio engine, download manager, and player UI (doc 03 §3.10, doc 04 §3.7).
- **Dependencies:** Phase 6 (needs a specific ayah/page context to play from); Phase 0's confirmed reciter/audio source.
- **Deliverables:** `AudioEngine` service, `DownloadManager` (background `URLSession`-based), mini-player + full-screen player UI, lock-screen/Control Center integration, ayah-highlight-sync in the Reader while playing.
- **Tests:** playback/interruption/background-transition tests from doc 07 §1; download-resume tests (kill the app mid-download, relaunch, confirm resumption); checksum verification of every downloaded audio asset before use.
- **Definition of done:** you can start playback, lock the phone, control it from the lock screen, receive a phone call, and have playback resume sensibly afterward — all on a real device, not just simulator.

### Phase 8 — Bookmarks & Progress
- **Objective:** build the SwiftData user-data layer and the Bookmarks/Progress screens (doc 03 §3.5/§3.6).
- **Dependencies:** Phase 5 (needs ayah selection in the reader) and Phase 7 (progress tracking should account for both reading and listening).
- **Deliverables:** `UserDataStore` (SwiftData models for bookmarks, notes, highlights, history, streak state), Bookmarks/Notes/History screen, Progress screen with streak + simple reading-goal logic.
- **Tests:** persistence-across-restart tests; boundary tests (bookmarking the very first/last ayah of a surah); a test confirming user data and content data are never cross-contaminated (doc 04's separation principle) even under a simulated content-pack update.
- **Definition of done:** bookmarks/notes survive an app restart, a content-pack update, and (if Phase 9's sync is later added) a device switch.

### Phase 9 — Offline / Downloads & Content Sync
- **Objective:** build `ContentSyncClient` against the Quran Foundation API (per Phase 0's confirmed terms), the unified Downloads settings screen (doc 03 §3.9), and the background re-sync scheduling.
- **Dependencies:** Phase 4 (extends the same content pipeline to downloadable premium packs), Phase 7 (shares download infrastructure with audio).
- **Deliverables:** downloadable translation/tafsir packs wired through the same verification pipeline as the bundled content; Downloads settings screen; `BackgroundTasks`-based periodic re-sync respecting the ≤7-day cadence from doc 05.
- **Tests:** full offline-mode test (network fully disabled) covering every downloaded and non-downloaded content state; storage-full and interrupted-download tests from doc 07 §4.
- **Definition of done:** a fresh install, fully set up and downloaded once, remains 100% functional with airplane mode on indefinitely, with the app correctly and calmly indicating if content is stale past the resync window without breaking usability.

### Phase 10 — Premium / Subscriptions
- **Objective:** implement StoreKit 2 subscription management and the paywall UI (doc 03 §3.8, doc 04 §3.11).
- **Dependencies:** Phases 6, 7, 9 (there must be real gated features — additional translations, reciters, tafsir, notes — to sell before building the paywall around them).
- **Deliverables:** `SubscriptionManager`, StoreKit Configuration file for local testing, paywall screen using `SubscriptionStoreView`, entitlement-gating wired into every premium feature identified in doc 02, "Restore Purchases" flow.
- **Tests:** sandbox purchase/restore/cancel/lapse tests (doc 07 §1); a test confirming no code path unlocks premium content without a verified StoreKit entitlement.
- **Definition of done:** a sandbox purchase unlocks the correct features immediately, restores correctly on a simulated fresh install, and a lapsed subscription leaves premium content visible-but-locked rather than deleted.

### Phase 11 — Settings & Onboarding
- **Objective:** build the Settings screen (doc 03 §3.7) and the first-launch onboarding flow (doc 03 §3.1).
- **Dependencies:** essentially everything above — this phase wires together defaults and preferences for features that must already exist.
- **Deliverables:** full Settings screen; onboarding flow with sensible pre-selected defaults and a clear initial-download step.
- **Tests:** first-launch-to-first-readable-page timing test; settings-persistence tests; permission-denial graceful-degradation tests (notifications declined, etc.).
- **Definition of done:** a completely fresh install reaches a readable Quran page in well under a minute on a normal connection, with no confusing or unexplained steps.

### Phase 12 — Analytics & Crash Reporting
- **Objective:** integrate TelemetryDeck (or equivalent) and Sentry/MetricKit per doc 04 §3.12/§3.13, and finalize the privacy manifest.
- **Dependencies:** ideally added last among infrastructure, once the real user flows (onboarding, paywall, feature usage) exist to instrument meaningfully.
- **Deliverables:** anonymous event instrumentation on key funnels (onboarding completion, paywall view/conversion, feature usage), crash reporting wired and verified (force a test crash, confirm it's captured), `PrivacyInfo.xcprivacy` finalized against every dependency's actual data use.
- **Tests:** a manual verification that a forced crash appears in the crash dashboard; a manual/automated check that no identifiable data appears in any analytics event payload.
- **Definition of done:** App Privacy questionnaire answers (doc 06 §2.3) can be filled out accurately by inspecting this phase's actual implementation, not by guessing.

### Phase 13 — QA
- **Objective:** run the full test matrix from document 07 end-to-end, across the device/OS/network/appearance grid, before considering the app release-ready.
- **Dependencies:** all functional phases complete.
- **Deliverables:** a completed QA pass with issues logged and triaged; the content-integrity suite green on the final release candidate; external TestFlight round with real 13-line-Mushaf users (doc 06 §2.9) completed and feedback incorporated.
- **Definition of done:** every item in document 07's functional and content-integrity tables has been explicitly tested and passed on real devices, not just reasoned about.

### Phase 14 — App Store Preparation
- **Objective:** complete every item in document 06 §2 (metadata, privacy questionnaire, screenshots, IAP configuration, review notes).
- **Dependencies:** Phase 13 (don't finalize marketing screenshots against a pre-QA build).
- **Deliverables:** a fully configured App Store Connect listing, ready for submission.
- **Definition of done:** every checklist item in document 06 §2 is checked off, and a colleague (or a fresh pair of eyes) has reviewed the listing for accuracy against the actual shipped feature set.

### Phase 15 — TestFlight (external, pre-submission)
- **Objective:** final real-world validation with a broader external group before public submission.
- **Deliverables:** a stable external build, feedback triaged, any last content/UX issues fixed and re-verified through the full pipeline (not patched ad hoc).
- **Definition of done:** no open crash reports, no open content-integrity issues, and positive qualitative feedback from testers who specifically use the 13-line format for memorization.

### Phase 16 — Launch
- **Objective:** submit, respond to any App Review questions promptly and specifically (referencing doc 06 §3's anticipated risk areas), and release.
- **Deliverables:** approved, released app; a short post-launch monitoring plan (crash-free rate, paywall conversion, any App Review follow-up) for the first two weeks.
- **Definition of done:** the app is live, and you have a dashboard/routine for noticing problems quickly rather than waiting for App Store reviews to surface them.
