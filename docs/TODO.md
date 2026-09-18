# Comprehensive Project Master Task Tracker (TODO)

This document tracks all actionable tasks across the lifecycle of the 13-Line Quran application. Items are marked with status checkboxes (`[ ]` for pending, `[x]` for complete).

---

## 1. Legal, Licensing & Scholarly Governance
- [ ] **Tanzil Attribution**: Prepare standard attribution text and hyperlink to `tanzil.net` for inclusion in the in-app "About" screen.
- [ ] **Public-Domain Translations**: Verify public-domain provenance for:
  - [ ] Marmaduke Pickthall (1930 edition).
  - [ ] Abdullah Yusuf Ali (1934 original edition).
  - [ ] Fateh Muhammad Jalandhari (1944 Urdu edition).
- [ ] **EveryAyah Attribution**: Confirm attribution copy for audio recitations streamed from EveryAyah/Quran Foundation CDN.
- [ ] **Licensing Outreach**:
  - [ ] Draft inquiry to Quran Foundation for formal commercial developer API documentation.
  - [ ] Draft inquiry to Tarteel/QUL regarding the Indo-Pak 13-line layout dataset.
- [ ] **Scholarly Verification**: Establish contact with a qualified Hafiz / Islamic scholar to review the digital 13-line page alignment and ayah boundary coordinates before public release.
- [ ] **Legal Review (Optional)**: If modern translations (e.g. *The Clear Quran*) are pursued in V1.5, engage IP counsel to negotiate publisher distribution agreements.

---

## 2. Quran Content & Data Pipeline
- [x] **Reference Corpus**: Check in a verified, read-only golden reference dataset of 114 Surahs and 6,236 Ayahs.
- [x] **13-Line Layout Dataset**: Construct and audit the SQLite database of layout and word positions for all 849 pages:
  - [x] Verify each page has exactly 13 lines (`mushaf_lines` contains 11,037 lines).
  - [x] Integrate authentic IndoPak Nastaleeq TTF font asset.
- [x] **SQLite Build**: Compile `quran_content.sqlite` containing:
  - [x] `surahs` table (114 rows, English & French names).
  - [x] `ayahs` table (6,236 canonical verses, IndoPak text & Imlaei search text).
  - [x] `mushaf_lines` table (11,037 layout lines mapping 1:1 to printed 13-line pages).
  - [x] `translations` table (18,708 rows: Saheeh International, Hilali & Muhsin Khan, and French Hamidullah).
  - [x] `search_index` (FTS5 virtual full-text search table with unicode61 tokenizer).
- [x] **SHA-256 Checksum**: Generate the cryptographic hash for `quran_content.sqlite` (`1b00779c9ae00ddca2232ec61a608a4cd9faf3d20e94d2f229d88df1b36f214b`) and record it in `QuranApp/Resources/Database/quran_content.sqlite.sha256`.

---

## 3. Project Scaffolding & Architecture
- [ ] **Xcode Project Setup**:
  - [ ] Create clean Xcode project targeting iOS 17.0+.
  - [ ] Configure bundle identifier: `com.company.thirteenlinequran`.
  - [ ] Enable Capabilities: Background Modes (`Audio, AirPlay, and Picture in Picture`).
- [x] **Package Dependencies**:
  - [x] Create `Package.swift` with `GRDB.swift` dependency and resource bundles.
- [x] **Folder Structure**: Establish modular folder hierarchy (`App/`, `DesignSystem/`, `Domain/`, `Features/`, `Resources/`, `Tests/`).
- [x] **Compiler Settings**: Code adheres to Swift 6 Strict Concurrency (`Sendable`, `@MainActor`, `actor QuranDatabaseService`).
- [x] **Agent Skills Integration** (`.agents/skills/`):
  - [x] `swiftui-expert` (SwiftUI 17+, Swift 6 concurrency, view invalidation, downsampling).
  - [x] `apple-fluid-motion` (Fluid springs, interruptible gestures, velocity handoffs).
  - [x] `mobile-ios-design` (Apple HIG, 44pt touch targets, Dynamic Type, navigation).
  - [x] Comprehensive roadmap activation matrix documented in [`docs/SKILLS_GUIDE.md`](docs/SKILLS_GUIDE.md).

---

## 4. Design System & Theming
- [x] **Visual Mockup & Design Extraction**: Generated via Stitch MCP (`Heritage Sepia & Tooled Leather` + `Surahs & Juz Navigation Index`).
- [x] **Color Tokens** (`QuranApp/DesignSystem/ColorTokens.swift`):
  - [x] Canvas Vellum (`#F3EDE0`) & Paper Aged (`#FAF6EE`).
  - [x] Ink Umber (`#2B2620`) & Sepia Muted (`#6E6459`).
  - [x] Saddle Amber (`#9E6B38`) & Border Sepia (`#DFD7C7`).
  - [x] Ayah Selection Glaze (`rgba(158, 107, 56, 0.20)`).
- [x] **Typography Tokens** (`QuranApp/DesignSystem/TypographyTokens.swift`):
  - [x] Headline & Body styles (Newsreader / Apple New York serif).
  - [x] UI labels & badges (SF Pro).
  - [x] Arabic Naskh/Nastaleeq calligraphy scaling helpers.
- [x] **Decorative Assets**: Implement vector `IslamicBanner` Surah divider in pure SwiftUI (`IslamicBanner.swift` & `QuranPageFrame.swift`).
- [ ] **Contrast Audit**: Verify all foreground/background color combinations satisfy WCAG AA contrast standards.

---

## 5. Mushaf Reader Engine
- [x] **Paging Viewport**:
  - [x] Build RTL horizontal paging container (`TabView` in `MushafReaderView.swift`).
  - [x] Build windowed memory cache (keeping only pages $N-1, N, N+1$ loaded in `MushafReaderViewModel.swift`).
  - [x] Build 13-line layout engine (`MushafLineView.swift` & `MushafPageView.swift`).
- [ ] **Zoom & Pan**:
  - [ ] Implement pinch-to-zoom (up to 2.5x).
  - [ ] Implement double-tap to reset zoom.
- [x] **Overlay Controls**:
  - [x] Build floating top bar (Surah title, Juz number, Page number, Translation selector).
  - [x] Build bottom bar (Sheikh Khalifa Al Tunaiji controls, Page scrubber slider).
  - [x] Single tap in page center toggles overlay visibility with smooth spring animation.
- [ ] **Keep-Awake**: Implement `UIApplication.shared.isIdleTimerDisabled = true` while reading.

---

## 6. Interactive Ayah Highlighting & Selection (Phase 4)
- [x] **Word & Line Ayah Clustering**: Each line parses words mapped directly to canonical `(surah, ayah)` keys.
- [x] **Highlight Overlay**: Render semi-transparent golden rounded glaze (`AppColors.ayahHighlightGlaze` and `AppColors.ayahHighlightBorder`) over active ayah words with fluid spring animation (`.spring(response: 0.28, dampingFraction: 0.88)`).
- [x] **Multi-Line Handling**: Verified that ayahs spanning multiple lines (e.g. Al-Fatihah 1:7 across lines 6, 7, and 8) highlight all segments simultaneously.
- [x] **Touch Gestures & Haptics**:
  - [x] Single tap: Selects ayah, triggers haptic feedback (`UISelectionFeedbackGenerator().selectionChanged()`).
  - [x] Presents `AyahActionSheetView` with `.presentationDetents([.fraction(0.44), .medium, .large])`.
- [x] **Ayah Action Sheet** (`AyahActionSheetView.swift`):
  - [x] Display Surah name, Ayah number, page and juz badges.
  - [x] Display authentic IndoPak calligraphy text.
  - [x] In-sheet translation author picker (Saheeh, Hilali-Khan, French Hamidullah).
  - [x] 5 Action Buttons (44x44pt HIG touch target standard):
    - [x] "Play" (`play.circle.fill`).
    - [x] "Bookmark" (`bookmark.fill` / `bookmark`).
    - [x] "Copy" (`doc.on.doc` with clipboard toast).
    - [x] "Share" (`square.and.arrow.up` with native iOS `ShareLink`).
    - [x] "Hifdh Repeat Loop" ($1\times, 3\times, 5\times, 10\times$).

---

## 7. Audio Playback Engine
- [x] **AVFoundation Setup**: Configure `AVAudioSession` with `.playback` category and `.spokenAudio` mode.
- [x] **Sequential Playback**:
  - [x] Build `AudioPlayerService` wrapping `AVPlayer` with `@Observable` and `@MainActor`.
  - [x] Stream Sheikh Khalifa Al Tunaiji from EveryAyah CDN: `https://everyayah.com/data/khalefa_al_tunaiji_64kbps/{surah:03d}{ayah:03d}.mp3`.
  - [x] Automatically advance to the next ayah and update reader's highlighted verse.
  - [x] Automatically turn the Mushaf page when recitation crosses page boundaries.
- [x] **Lock-Screen Media Center**:
  - [x] Populate `MPNowPlayingInfoCenter` with Surah name, Ayah number, reciter name, and track details.
  - [x] Implement `MPRemoteCommandCenter` handlers for Play, Pause, Toggle, Next, and Previous.
- [x] **Audio Interruption & Route Changes**: Gracefully handle incoming cellular calls, alarms, Siri interruptions, and headphone disconnects.
- [x] **Mini-Player**: Docked floating player showing reciter name, active ayah, play/pause buffering state, and scrubber.

---

## 8. Navigation & Search
- [x] **Index Hub**:
  - [x] Segmented control: [Surahs (114), Juz (30), Pages (849)].
  - [x] Surah List: 114 rows showing circular number badge, Arabic calligraphy, English title & meaning, distinct Meccan/Medinan pills, Juz spans, start page, and "Currently Reading" indicator.
  - [x] Juz List: 30 rows showing canonical opening title (Arabic & transliterated), starting Surah/Ayah, and start page.
  - [x] Pages View: Direct numeric jump to any page (1–849) plus 30-Juz rapid milestone grid.
- [x] **Local Search**:
  - [x] Connect search field to `search_index` SQLite FTS5 table with unicode61 tokenizer.
  - [x] Implement 300ms debounced search query execution with task cancellation (<15ms response).
  - [x] Render matched verses with golden highlighted keywords using `AttributedString`.
  - [x] Include `page_number` in `search_index` to open reader directly on tap without redundant secondary fetch.
  - [x] Tapping a search result switches to Read tab, navigates to exact 13-line page, and selects & highlights the ayah.

---

## 9. User Data & Persistence
- [x] **User Database**: Create `user_data.sqlite` in `Application Support` via native SQLite3 WAL mode.
- [x] **Bookmarks**:
  - [x] Create table `bookmarks (id, ayah_id, surah_id, verse_number, page_number, title, arabic_snippet, translation_snippet, note, created_at)`.
  - [x] Add / remove bookmarks with instant UI updates and duplicate prevention.
  - [x] Bookmark list view with modal sheet, filter pills (All, Verses, Pages), and native swipe-to-delete.
- [x] **Last-Read Memory**:
  - [x] Auto-save `last_read_page` whenever user rests on a page for $>2$ seconds (cancellable Task debounce).
  - [x] App launch immediately opens to `last_read_page` without visual page flash.


---

## 10. Offline Download Manager
- [x] **Background Download Manager**: Implement `@Observable @MainActor DownloadManager` for Sheikh Khalifa Al Tunaiji audio recitation (64kbps).
- [x] **Download Storage & Apple Guideline Compliance**: Save MP3s into `Application Support/13LineQuran/Downloads/` and mark with `isExcludedFromBackup = true`.
- [x] **Surah Audio Packs**: One-tap download of all verses for any Surah with concurrent chunking (4 verses at a time) and cancellation.
- [x] **Seamless Local Playback**: Coordinate `AudioPlayerService` to check local disk first, providing zero-latency offline playback with streaming fallback.
- [x] **Offline Storage UI**: Settings screen showing disk usage metrics (MB used, Surah count), download list, and "Clear All Audio" action with confirmation.


---

---

## 11. Settings, Themes, Onboarding & Accessibility Polish
- [x] **Visual Reading Themes**:
  - [x] Heritage Sepia & Tooled Leather (Default).
  - [x] Soft Ivory Parchment.
  - [x] Midnight OLED Dark (Pure black `#000000` with warm amber scripture glow).
- [x] **Onboarding Flow**:
  - [x] Screen 1: Welcome & core promise ("The 13-Line Mushaf, Beautifully Offline").
  - [x] Screen 2: Choose default theme and translation (Saheeh, Hilali-Khan, Hamidullah).
  - [x] Screen 3: Ready to recite — jump directly into Al-Fatihah.
  - [x] First-launch detection via `@AppStorage("hasCompletedOnboarding")`.
- [x] **VoiceOver & Accessibility Polish**:
  - [x] Accessible semantic labels on all icon buttons ("Play audio", "Add bookmark", "Next page", "Open index").
  - [x] Dynamic Type compliance across UI chrome and settings.
  - [x] Verify RTL layout direction compatibility.
- [x] **Scholarly Attributions & Licensing**:
  - [x] Clean, comprehensive About & Attribution sheet.

---

*(Note: StoreKit 2 & Paywall dropped per ADR-008 — 100% Free, Ad-Free & Open / Sadaqah Jariyah)*

---

## 14. Quality Assurance & Integrity Testing
- [ ] **Automated Test Suite**:
  - [ ] Run `QuranIntegrityTests` asserting 114 Surahs, 6,236 Ayahs, and 848 pages.
  - [ ] Run bounding box coordinate range audit.
  - [ ] Run StoreKit sandbox purchase and restore tests.
- [ ] **Device Testing Matrix**:
  - [ ] Test on iPhone SE (4.7" compact screen).
  - [ ] Test on standard iPhone (6.1").
  - [ ] Test on iPhone Pro Max (6.7"/6.9" large screen).
- [ ] **Network & Interruption Testing**:
  - [ ] Test cold launch in Airplane Mode.
  - [ ] Test audio playback with incoming phone call interruption.
  - [ ] Test audio playback when device screen locks.

---

## 15. App Store Submission Preparation
- [ ] **Pre-Submission Compliance Audit (Appflight)**:
  - [ ] Scan compiled `.ipa` binary and code via [Appflight](https://appflight.co/) to detect App Store rejection risks, unhandled guideline requirements, missing usage descriptions, or undeclared required reason APIs before submitting to Apple.
- [ ] **Privacy Manifest**: Include `Support/PrivacyInfo.xcprivacy` with required reason API declarations.
- [ ] **App Store Connect**:
  - [ ] App Name: "13 Line Quran – Mushaf Reader" (≤30 chars).
  - [ ] Subtitle: "Traditional Indo-Pak Mushaf" (≤30 chars).
  - [ ] Category: Books / Reference.
  - [ ] Age Rating: 4+.
  - [ ] App Privacy: Answer "No, we do not collect data."
- [ ] **Marketing Assets**: Capture screenshots on 6.9", 6.7", and 6.5" displays.
- [ ] **Review Notes**: Write explicit review notes explaining background audio and StoreKit sandbox testing.
- [ ] **TestFlight Beta**: Conduct external TestFlight round with real 13-line Mushaf readers.
