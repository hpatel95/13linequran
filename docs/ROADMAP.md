# Phased Development Roadmap (V1 to V2)

This roadmap defines the sequential, modular milestones for developing the 13-Line Quran application. Each phase has explicit dependencies, deliverables, required tests, and an unambiguous Definition of Done (DoD).

---

## Milestone Summary

```
Phase 0: Legal & Content Preparation (Completed)
   │
Phase 1: Project Scaffolding & Design System (Completed)
   │
Phase 2: Immutable SQLite Content Engine & Integrity Test Suite (Completed)
   │
Phase 3: 13-Line Mushaf Viewport & 120Hz Paging Canvas (Completed)
   │
Phase 4: Ayah Bounding Box Overlays & Selection Sheet (Completed)
   │
Phase 5: Background Audio Recitation & Lock-Screen Center (Completed)
   │
Phase 6: Navigation Hub (Surah/Juz) & Local FTS5 Search (Completed)
   │
Phase 7: User Data Engine (Bookmarks & Reading History) (Completed)
   │
Phase 8: Offline Download Manager (Audio Packs & Storage UI) (Completed)
   │
Phase 9: Settings, Themes, Onboarding & Accessibility Polish (Completed)
   │
Phase 10: End-to-End QA, Device Matrix & Pre-Release Audit (NEXT)
   │
Phase 11: App Store Connect, TestFlight & Public Release
```

*(Note: Prior StoreKit 2 Paywall draft dropped per ADR-008 — 100% Free, Ad-Free & Open / Sadaqah Jariyah)*

---

## Phase Details

### Phase 0: Legal & Content Preparation (Completed)
* **Objective**: Prepare verified content databases, confirm licensing documentation, and organize the 849-page asset library.
* **Dependencies**: None (foundational).
* **Deliverables**:
  * Clean SQLite dataset containing 114 Surahs, 6,236 Ayahs, and 849-page coordinate mapping (Qudratullah edition).
  * Bundled public-domain & verified translations (Saheeh International, Dr. Hilali & Dr. Muhsin Khan, Dr. Muhammad Hamidullah).
  * 849 13-line layout pages ingested from QUL (Layout 17).
* **Definition of Done**: All assets and databases validated by SHA-256 checksums and verified in `QuranApp/Resources/Database/quran_content.sqlite`.

---

### Phase 1: Project Scaffolding & Design System (Completed)
* **Objective**: Set up the project structure, target iOS 17+, establish native design tokens and 3-tab shell.
* **Dependencies**: None.
* **Deliverables**:
  * `App/QuranApp.swift`, `App/RootTabView.swift`.
  * `DesignSystem/ColorTokens.swift` (Heritage Sepia, Soft Ivory, Midnight OLED).
  * `DesignSystem/TypographyTokens.swift` (IndoPak Nastaleeq styles, Arabic script helpers).
  * `DesignSystem/Components/IslamicBanner.swift`.
* **Definition of Done**: Project compiles with zero warnings and runs cleanly on iOS 17+ with initial design tokens.

---

### Phase 2: Immutable SQLite Content Engine & Integrity Suite (Completed)
* **Objective**: Build the thread-safe read-only Quran content database access layer and automated integrity test suite.
* **Dependencies**: Phase 1.
* **Deliverables**:
  * `Domain/Models/QuranModels.swift` (`Surah`, `Ayah`, `MushafLine`, `MushafWord`, `Translation`).
  * `Domain/Database/QuranDatabaseService.swift` (Actor-isolated native SQLite3 engine in WAL mode).
  * `Tests/QuranAppTests/QuranIntegrityTests.swift`.
* **Tests**:
  * Assert `surahs.count == 114`.
  * Assert `ayahs.count == 6236`.
  * Assert canonical ayah counts for all 114 Surahs.
  * Assert all 849 pages have 13 lines and Ayah 6236 on Page 849.
* **Definition of Done**: Integrity test suite passes 100%; async read APIs deliver data in under 2ms.

---

### Phase 3: 13-Line Mushaf Viewport & 120Hz Paging Canvas (Completed)
* **Objective**: Implement the horizontal Right-to-Left Mushaf reader with smooth 120Hz page flipping and pinch zoom.
* **Dependencies**: Phases 1, 2.
* **Deliverables**:
  * `Features/Reader/MushafPageView.swift` (High-performance 13-line canvas with pinch-to-zoom).
  * `Features/Reader/MushafReaderView.swift` (Top and bottom chrome that auto-hides on tap).
  * `Features/Reader/MushafReaderViewModel.swift` (`@Observable` state tracker for current page, surah, and juz).
* **Definition of Done**: Paging across all 849 pages is smooth with 120Hz ProMotion responsiveness; tapping toggles chrome cleanly.

---

### Phase 4: Ayah Bounding Box Overlays & Selection Sheet (Completed)
* **Objective**: Render word-accurate interactive bounding boxes over the 13-line canvas, allowing ayah selection, highlight tinting, and bottom sheet translation.
* **Dependencies**: Phases 2, 3.
* **Deliverables**:
  * `Features/Reader/MushafLineView.swift` (Word-cluster hit testing and golden highlight glaze).
  * `Features/Reader/AyahActionSheetView.swift` (Bottom sheet displaying Arabic text, translations, audio play button, and bookmark toggle).
* **Definition of Done**: Tapping any ayah highlights its word cluster with golden tint and smoothly presents the action sheet.

---

### Phase 5: Background Audio Recitation & Lock-Screen Controls (Completed)
* **Objective**: Build the background audio streaming engine with verse-by-verse synchronization and lock-screen media controls.
* **Dependencies**: Phases 2, 4.
* **Deliverables**:
  * `Features/Audio/AudioPlayerService.swift` (`AVPlayer` wrapper with Sheikh Khalifa Al Tunaiji 64kbps recitation).
  * `NowPlaying` & `MPRemoteCommandCenter` integration for lock-screen controls.
  * Auto-advance to next verse and automatic reader page-turning.
* **Definition of Done**: Recitation streams seamlessly; active ayah highlight advances synchronously; audio continues in background with lock-screen playback controls.

---

### Phase 6: Navigation Hub (Surah/Juz/Page) & Fast FTS5 Search (Completed)
* **Objective**: Build the Navigation Hub with 3-tab segmented index and instant offline FTS5 search.
* **Dependencies**: Phases 2, 3.
* **Deliverables**:
  * `Features/Navigation/IndexHubView.swift` (Surah, Juz, and Page tabs with search bar).
  * `Features/Navigation/SurahRowView.swift`, `JuzRowView.swift`, `PageJumpView.swift`.
  * Real-time SQLite FTS5 search across Surahs, Arabic text, and English translations.
* **Definition of Done**: Tapping any Surah, Juz, or page jumps directly into the reader; searching highlights matching words and deep-links to the exact verse.

---

### Phase 7: User Data Engine (Bookmarks & Reading History) (Completed)
* **Objective**: Implement local persistence for user bookmarks, last-read tracking, and reading history in an isolated `user_data.sqlite`.
* **Dependencies**: Phases 2, 4.
* **Deliverables**:
  * `Domain/Database/UserDatabaseService.swift` (Actor-isolated native SQLite3 in WAL mode).
  * `Domain/Models/UserModels.swift` (`Bookmark`, `ReadingSessionEntry`, `app_preferences`).
  * `Features/Bookmarks/BookmarksListView.swift` (Filter pills, swipe-to-delete).
  * 2.0-second debounced auto-save of last-read page and zero-flash cold launch resume.
* **Definition of Done**: Bookmarks persist across app relaunches; cold launch immediately restores the reader to the exact last-read page.

---

### Phase 8: Offline Download Manager (Audio Packs & Storage UI) (Completed)
* **Objective**: Build the background download manager for offline Surah audio recitations (Sheikh Khalifa Al Tunaiji) with Apple backup exclusion and zero-latency local playback.
* **Dependencies**: Phases 3, 5.
* **Deliverables**:
  * `Domain/Downloads/AudioStorageLocator.swift` (Stateless path locator, `isExcludedFromBackup = true`).
  * `Domain/Downloads/DownloadManager.swift` (Bounded concurrency pool of 4 tasks, cancellation, cache clearing).
  * `Features/Settings/OfflineStorageView.swift` (Live storage metrics, per-Surah progress, swipe-to-delete).
  * Transparent local file fallback in `AudioPlayerService`.
* **Definition of Done**: Users can download complete Surah audio packs; playback switches to local NVMe storage with zero buffering; audio functions 100% in Airplane Mode.

---

### Phase 9: Settings, Themes, Onboarding & Accessibility Polish (Completed)
* **Objective**: Deliver multi-theme visual rendering (Sepia, Soft Ivory, Midnight OLED Dark), a serene 15-second onboarding experience, and comprehensive Apple accessibility (VoiceOver, Dynamic Type).
* **Dependencies**: All prior phases.
* **Deliverables**:
  * `DesignSystem/ThemeManager.swift` (Heritage Sepia, Soft Ivory, Midnight OLED Dark with system `.preferredColorScheme`).
  * `Features/Onboarding/OnboardingView.swift` (3-screen personalized onboarding with live theme & translation preview).
  * `Features/Settings/SettingsView.swift` (Visual theme cards, translation switcher, offline storage link, Sadaqah Jariyah dedication).
  * Complete VoiceOver accessibility pass on `MushafLineView`, reader chrome, and navigation rows.
* **Definition of Done**: Fresh install opens onboarding and reaches Al-Fatihah in under 15 seconds; switching themes updates all views instantaneously; VoiceOver navigates and reads Ayahs accurately.

---

### Phase 10: End-to-End QA, Device Matrix & Pre-Release Audit (NEXT)
* **Objective**: Execute the complete functional and device testing matrix across iPhone models, iOS versions, and accessibility modes.
* **Dependencies**: All functional code complete (Phases 1–9).
* **Deliverables**:
  * Comprehensive execution of automated test suites (`QuranIntegrityTests`, `UserDatabaseTests`, `DownloadManagerTests`, `ThemeManagerTests`).
  * Verified `Support/PrivacyInfo.xcprivacy` manifest declaring zero tracking and required reason APIs.
  * Device compatibility audit (iPhone SE 4.7", standard iPhone 6.1", iPhone Pro Max 6.7"/6.9").
  * Cold launch & network interruption validation (Airplane Mode, incoming phone calls).
* **Definition of Done**: Zero crashes, zero memory leaks during rapid page turning across all 849 pages, 100% passing test suites, and clean privacy manifest.

---

### Phase 11: App Store Connect, TestFlight & Public Release
* **Objective**: Prepare App Store Connect metadata, conduct external TestFlight beta with Hafiz users, and submit for App Review.
* **Dependencies**: Phase 10.
* **Deliverables**:
  * App Store screenshots (6.9", 6.7", 6.5").
  * App Store metadata (description, keywords, promotional text, support URL).
  * App Review notes highlighting audio background modes and Sadaqah Jariyah ethos.
  * App Privacy questionnaire marked as "Data Not Collected".
* **Definition of Done**: App approved by Apple App Review and released publicly to the App Store.

---

## Post-V1 Horizon

### V1.1 (Fast Follow)
* Khatm Planner (daily page calculator based on target finish date).
* Reading streaks and lightweight daily progress stats.
* Audio repeat range looping ($N\times$ repetitions between ayah $X$ and $Y$).
* Home Screen and Lock Screen widgets (Resume Reading, Verse of the Day).

### V1.5 (Advanced Features)
* Word-by-word tap translation and morphology overlay.
* Additional licensed modern translations upon formal publisher agreements.
* Additional famous reciters (Minshawi, Shuraym, Shaatree).
* Private CloudKit bookmark synchronization across iPhone and iPad.

### V2.0 (Ambitious Expansion)
* Dedicated iPad two-page spread study layout.
* On-device semantic search.
* Apple Watch companion app.
* Mac Catalyst build.
