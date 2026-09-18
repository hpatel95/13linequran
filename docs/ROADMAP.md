# Phased Development Roadmap (V1 to V2)

This roadmap defines the sequential, modular milestones for developing the 13-Line Quran application. Each phase has explicit dependencies, deliverables, required tests, and an unambiguous Definition of Done (DoD).

---

## Milestone Summary

```
Phase 0: Legal & Content Preparation (Parallel)
   │
Phase 1: Project Scaffolding & Design System
   │
Phase 2: Immutable SQLite Content Engine & Integrity Test Suite
   │
Phase 3: 13-Line Mushaf Viewport & 120Hz Paging Canvas
   │
Phase 4: Ayah Bounding Box Overlays & Selection Sheet
   │
Phase 5: Background Audio Recitation & Lock-Screen Center
   │
Phase 6: Navigation Hub (Surah/Juz) & Local FTS5 Search
   │
Phase 7: User Data Engine (Bookmarks & Reading History)
   │
Phase 8: Offline Download Manager (Audio Packs & Mushaf Tiles)
   │
Phase 9: StoreKit 2 Supporter Subscriptions & Paywall
   │
Phase 10: Settings, Onboarding & Accessibility Polish
   │
Phase 11: End-to-End QA, Device Matrix & Pre-Release Audit
   │
Phase 12: App Store Connect, TestFlight & Public Release
```

---

## Phase Details

### Phase 0: Legal & Content Preparation (Parallel Track)
* **Objective**: Prepare verified content databases, confirm licensing documentation, and organize the 848-page asset library.
* **Dependencies**: None (proceeds in parallel with engineering).
* **Deliverables**:
  * Clean SQLite dataset containing 114 Surahs, 6,236 Ayahs, and 848-page coordinate mapping.
  * Public-domain translation texts (Pickthall 1930, Yusuf Ali 1934, Jalandhari Urdu 1944).
  * 848 optimized AVIF/WebP page tiles ($1600 \times 2400$).
  * Outreach emails to Quran Foundation and Tarteel/QUL on file.
* **Definition of Done**: All assets and databases are validated by SHA-256 checksums and stored in a designated preparation directory.

---

### Phase 1: Project Scaffolding & Design System
* **Objective**: Set up the Xcode project structure, target iOS 17+, import GRDB via SPM, and establish the visual design tokens.
* **Dependencies**: None.
* **Deliverables**:
  * `App/QuranApp.swift`, `App/AppDelegate.swift`.
  * `DesignSystem/ColorTokens.swift` (Ivory, Parchment, Midnight OLED, Gold).
  * `DesignSystem/TypographyTokens.swift` (Dynamic Type styles, Arabic script helpers).
  * `DesignSystem/Components/IslamicBanner.swift`, `PrimaryButton.swift`.
  * Basic 3-tab navigation shell (Read, Discover, Settings) with empty placeholder views.
* **Tests**: Smoke test confirming project compiles with zero warnings and launches to the tab shell.
* **Definition of Done**: Project runs cleanly on simulator and real device with functioning theme tokens.

---

### Phase 2: Immutable SQLite Content Engine & Integrity Suite
* **Objective**: Build the thread-safe read-only Quran content database access layer and automated integrity test suite.
* **Dependencies**: Phase 1.
* **Deliverables**:
  * `Domain/Models/QuranModels.swift` (`Surah`, `Ayah`, `AyahBound`, `Translation`).
  * `Domain/Database/QuranDatabaseService.swift` (GRDB wrapper with async read APIs).
  * `Tests/QuranIntegrityTests.swift`.
* **Tests**:
  * Assert `surahs.count == 114`.
  * Assert `ayahs.count == 6236`.
  * Assert canonical ayah counts for all 114 Surahs (Surah 1 = 7, Surah 2 = 286 ... Surah 114 = 6).
  * Assert all 849 pages have normalized coordinates $(0.0 \le min < max \le 1.0)$.
* **Definition of Done**: Integrity test suite passes 100% in Xcode Test Navigator; throwaway debug view successfully queries and prints any ayah.

---

### Phase 3: 13-Line Mushaf Viewport & 120Hz Paging Canvas
* **Objective**: Implement the horizontal Right-to-Left Mushaf reader with smooth 120Hz page flipping and pinch zoom.
* **Dependencies**: Phases 1, 2.
* **Deliverables**:
  * `Features/Reader/MushafContainerView.swift` (RTL paging container).
  * `Features/Reader/MushafPageView.swift` (High-res tile loader with pinch-to-zoom and double-tap zoom reset).
  * `Features/Reader/ReaderOverlayView.swift` (Top and bottom chrome that auto-hides on tap).
  * `Features/Reader/MushafReaderViewModel.swift` (`@Observable` state tracker for current page, surah, and juz).
* **Tests**: Navigation unit tests verifying edge transitions (Page 1, Page 849, Juz boundaries).
* **Definition of Done**: User can swipe through pages 1 to 849 smoothly with zero frame drops; tapping toggles UI chrome; pinch-to-zoom scales up to 2.5x and snaps back.

---

### Phase 4: Ayah Bounding Box Overlays & Selection Sheet
* **Objective**: Render interactive bounding boxes over the 13-line page tiles, allowing ayah selection, highlight tinting, and actions.
* **Dependencies**: Phases 2, 3.
* **Deliverables**:
  * `Features/Reader/AyahHighlightOverlay.swift` (Dynamic coordinate-to-screen geometry converter).
  * `Features/Reader/TranslationSheetView.swift` (Bottom sheet displaying Arabic snippet, Pickthall translation, and action buttons).
  * Integration of single-tap and long-press gestures in `MushafPageView`.
* **Tests**: Hit-testing unit tests verifying that touches within a bounding box resolve to the exact `surah:ayah` reference.
* **Definition of Done**: Tapping or long-pressing any ayah highlights its bounding box with a 22% gold tint and slides up the translation sheet with matching text.

---

### Phase 5: Background Audio Recitation & Lock-Screen Controls
* **Objective**: Build the background audio streaming engine with verse-by-verse synchronization and lock-screen media controls.
* **Dependencies**: Phases 2, 4.
* **Deliverables**:
  * `Domain/Audio/AudioPlaybackService.swift` (`AVQueuePlayer` wrapper managing sequential ayah playback).
  * `Domain/Audio/NowPlayingManager.swift` (`MPNowPlayingInfoCenter` & `MPRemoteCommandCenter` handlers).
  * `Features/Reader/MiniPlayerView.swift` (Docked bottom player showing reciter name, play/pause toggle, and ayah counter).
* **Tests**: Audio interruption tests (simulating incoming phone call and route change); URL string schema verification tests.
* **Definition of Done**: User taps "Play" on any ayah; recitation streams seamlessly; the active ayah highlight advances in real-time with the audio; audio continues playing with lock-screen controls when the iPhone is locked.

---

### Phase 6: Navigation Hub (Surah/Juz/Page) & Fast FTS5 Search
* **Objective**: Build the Discover navigation drawer and instant offline search engine.
* **Dependencies**: Phases 2, 3.
* **Deliverables**:
  * `Features/Navigation/IndexHubView.swift` (Segmented picker: Surah, Juz, Page).
  * `Features/Navigation/SurahListView.swift` (List of 114 Surahs with Arabic calligraphy and start page).
  * `Features/Navigation/JuzListView.swift` (List of 30 Juz with starting ayah snippet).
  * `Features/Search/LocalSearchView.swift` (Debounced SQLite FTS5 search across Surahs and translation text).
* **Tests**: FTS5 query performance tests (verifying <15ms response times across 6,236 verses).
* **Definition of Done**: Tapping any Surah or Juz immediately deep-links the reader to the exact page; typing a search term highlights matching verses and jumps to the target ayah on tap.

---

### Phase 7: User Data Engine (Bookmarks & Reading History)
* **Objective**: Implement local persistence for user bookmarks, last-read tracking, and reading history in `user_data.sqlite`.
* **Dependencies**: Phases 2, 4.
* **Deliverables**:
  * `Domain/Database/UserDatabaseService.swift` (GRDB actor managing bookmarks and history).
  * `Domain/Models/UserModels.swift` (`Bookmark`, `ReadingHistoryEntry`, `AppSettings`).
  * `Features/Bookmarks/BookmarksListView.swift` (Saved verses list with swipe-to-delete).
* **Tests**: Persistence tests confirming bookmark insertion, deletion, and cold-launch state recovery.
* **Definition of Done**: Bookmarking an ayah persists across app force-quits; launching the app immediately reopens to the user's last-read page.

---

### Phase 8: Offline Download Manager (Audio & Page Tiles)
* **Objective**: Build the background download manager for offline Surah/Juz audio recitations and complete Mushaf tile sets.
* **Dependencies**: Phases 3, 5.
* **Deliverables**:
  * `Domain/Downloads/DownloadManager.swift` (Background `URLSession` manager with progress reporting).
  * `Features/Settings/OfflineStorageView.swift` (Storage breakdown, "Download All" buttons, cache clear).
* **Tests**: Interrupted download resumption tests; disk-space verification tests.
* **Definition of Done**: User can download an entire Surah for offline playback; disconnecting Wi-Fi/cellular maintains uninterrupted audio playback.

---

### Phase 9: Settings, Themes, Onboarding & Accessibility Polish
* **Objective**: Deliver multi-theme visual rendering (Sepia, Soft Ivory, Midnight OLED Dark), a serene 15-second onboarding experience, and comprehensive Apple accessibility (VoiceOver, Dynamic Type).
* **Deliverables**:
  * `DesignSystem/ThemeManager.swift` (Dynamic theme palette: Sepia, Ivory, Midnight OLED).
  * `Features/Onboarding/OnboardingView.swift` (3-screen serene onboarding with theme & translation selection).
  * `Features/Settings/SettingsView.swift` (Live theme switcher, audio settings, offline storage links, attributions).
  * Accessibility polish across all icon buttons, search fields, and sheets.
* **Definition of Done**: Fresh install launches onboarding with immediate theme selection; switching themes updates reader canvas, chrome, and index instantly; all controls pass VoiceOver audit.

*(Note: Prior StoreKit 2 Paywall draft dropped per ADR-008 — 100% Free, Ad-Free & Open / Sadaqah Jariyah)*

---

### Phase 11: End-to-End QA, Device Matrix & Pre-Release Audit
* **Objective**: Execute the complete functional and device testing matrix across iPhone models and iOS versions.
* **Dependencies**: All functional code complete.
* **Deliverables**:
  * Execution of test matrix across iPhone SE, iPhone 15/16, and iPhone Pro Max.
  * Verified `Support/PrivacyInfo.xcprivacy` manifest declaring zero tracking and required reason APIs.
  * Pre-submission `.ipa` binary and compliance scan via [Appflight](https://appflight.co/) (identifying Apple review rejection risks, privacy manifest oversights, and guideline violations before submission).
  * Complete TestFlight internal beta build.
* **Definition of Done**: Zero crashes, zero memory leaks during rapid page turning, 100% passing integrity tests, and clean report from Appflight pre-submission audit.

---

### Phase 12: App Store Connect, TestFlight & Public Release
* **Objective**: Prepare App Store Connect metadata, conduct external TestFlight beta with Hafiz users, and submit for App Review.
* **Dependencies**: Phase 11.
* **Deliverables**:
  * App Store screenshots (6.9", 6.7", 6.5").
  * Review notes explaining background audio and StoreKit sandbox testing.
  * App Privacy questionnaire marked as "Data Not Collected".
* **Definition of Done**: App approved by Apple App Review and released to the App Store.

---

## Post-V1 Horizon

### V1.1 (Fast Follow)
* Khatm Planner (daily page calculator based on target finish date).
* Reading streaks and lightweight daily progress stats.
* Audio repeat range looping ($N\times$ repetitions between ayah $X$ and $Y$).
* Home Screen and Lock Screen widgets (Resume Reading, Verse of the Day).

### V1.5 (Advanced Features)
* Word-by-word tap translation and morphology overlay.
* Additional licensed modern translations (Clear Quran, Sahih International) upon formal publisher agreements.
* Additional famous reciters (Minshawi, Shuraym, Shaatree).
* Private CloudKit bookmark synchronization across iPhone and iPad.

### V2.0 (Ambitious Expansion)
* Dedicated iPad two-page spread study layout.
* On-device semantic search.
* Apple Watch companion app.
* Mac Catalyst build.
