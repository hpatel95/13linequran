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
- [ ] **Reference Corpus**: Check in a verified, read-only golden reference dataset of 114 Surahs and 6,236 Ayahs.
- [ ] **13-Line Bounding Box Dataset**: Construct and audit the SQLite database of Ayah Bounding Boxes for all 848 pages:
  - [ ] Verify each page has exactly 13 lines.
  - [ ] Verify bounding boxes cover every ayah without clipping.
  - [ ] Confirm normalized coordinate bounds: $0.0 \le minX < maxX \le 1.0$ and $0.0 \le minY < maxY \le 1.0$.
- [ ] **848-Page Image Optimization**:
  - [ ] Process vector-rasterized 13-line pages into high-definition AVIF/WebP tiles ($1600 \times 2400$).
  - [ ] Verify total uncompressed footprint is $\le 90$ MB for the entire 848-page set.
  - [ ] Ensure dual-layer alpha separation so ink can be tinted dynamically by SwiftUI shaders.
- [ ] **SQLite Build**: Compile `quran_content.sqlite` containing:
  - [ ] `surahs` table.
  - [ ] `ayahs` table.
  - [ ] `ayah_bounds` table.
  - [ ] `translations` table.
  - [ ] `translations_fts` (FTS5 virtual full-text search table).
- [ ] **SHA-256 Checksum**: Generate the cryptographic hash for `quran_content.sqlite` and record it in the app's build configuration.

---

## 3. Project Scaffolding & Architecture
- [ ] **Xcode Project Setup**:
  - [ ] Create clean Xcode project targeting iOS 17.0+.
  - [ ] Configure bundle identifier: `com.company.thirteenlinequran`.
  - [ ] Enable Capabilities: Background Modes (`Audio, AirPlay, and Picture in Picture`).
- [ ] **Package Dependencies**:
  - [ ] Add `GRDB.swift` via Swift Package Manager.
  - [ ] (Optional) Add `TelemetryDeck` via Swift Package Manager.
- [ ] **Folder Structure**: Establish modular folder hierarchy (`App/`, `DesignSystem/`, `Domain/`, `Features/`, `Resources/`, `Support/`).
- [ ] **Compiler Settings**: Enable Swift 6 Strict Concurrency Checking (`-strict-concurrency=complete`) with zero warnings.
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
  - [x] Arabic Naskh calligraphy scaling helpers.
- [ ] **Decorative Assets**: Implement vector `IslamicBanner` Surah divider in pure SwiftUI paths.
- [ ] **Contrast Audit**: Verify all foreground/background color combinations satisfy WCAG AA contrast standards.

---

## 5. Mushaf Reader Engine
- [ ] **Paging Viewport**:
  - [ ] Build RTL horizontal paging container (`TabView` or `UIPageViewController`).
  - [ ] Implement smooth 120Hz ProMotion swipe animations between pages 1 and 848.
  - [ ] Build windowed memory cache (keeping only pages $N-1, N, N+1$ loaded).
- [ ] **Zoom & Pan**:
  - [ ] Implement pinch-to-zoom (up to 2.5x).
  - [ ] Implement double-tap to reset zoom.
- [ ] **Overlay Controls**:
  - [ ] Build floating top bar (Surah title, Juz number, Page number).
  - [ ] Build bottom bar (Audio play, Bookmark toggle, Page scrubber).
  - [ ] Single tap in page center toggles overlay visibility with smooth fade animation.
- [ ] **Keep-Awake**: Implement `UIApplication.shared.isIdleTimerDisabled = true` while reading.

---

## 6. Interactive Ayah Bounding Boxes & Selection
- [ ] **Coordinate Converter**: Map normalized `(min_x, min_y, max_x, max_y)` to actual rendered image coordinates inside `GeometryReader`.
- [ ] **Highlight Overlay**: Render semi-transparent golden rounded rectangle (`#C5A059` at 22% opacity) over active ayah bounds.
- [ ] **Multi-Line Handling**: Ensure ayahs spanning multiple lines highlight all matching line segments simultaneously.
- [ ] **Touch Gestures**:
  - [ ] Single tap: Selects ayah, plays audio or shows highlight.
  - [ ] Long press: Triggers haptic feedback (`UIImpactFeedbackGenerator(style: .medium)`) and presents `TranslationSheetView`.
- [ ] **Translation Bottom Sheet**:
  - [ ] Display Surah name and Ayah number.
  - [ ] Display Arabic text snippet.
  - [ ] Display Pickthall/Yusuf Ali translation text.
  - [ ] Action buttons: "Play from Here", "Bookmark Ayah", "Copy Verse".

---

## 7. Audio Playback Engine
- [ ] **AVFoundation Setup**: Configure `AVAudioSession` with `.playback` category and `.spokenAudio` mode.
- [ ] **Sequential Playback**:
  - [ ] Build `AudioPlaybackService` wrapping `AVQueuePlayer`.
  - [ ] Load sequential ayah URLs: `https://everyayah.com/data/{reciter}/{surah:03d}{ayah:03d}.mp3`.
  - [ ] Automatically advance to the next ayah and update the reader's highlighted verse.
  - [ ] Automatically turn the Mushaf page when recitation crosses page boundaries.
- [ ] **Lock-Screen Media Center**:
  - [ ] Populate `MPNowPlayingInfoCenter` with Surah name, Ayah number, reciter name, and album artwork.
  - [ ] Implement `MPRemoteCommandCenter` handlers for Play, Pause, Toggle, Next, and Previous.
- [ ] **Audio Interruption**: Gracefully handle incoming cellular calls, alarms, and Siri interruptions.
- [ ] **Mini-Player**: Docked floating player showing reciter name, play/pause button, and dismiss button.

---

## 8. Navigation & Search
- [ ] **Index Hub**:
  - [ ] Segmented control: [Surah, Juz, Page].
  - [ ] Surah List: 114 rows showing number, Arabic name, English title, revelation type, and start page.
  - [ ] Juz List: 30 rows showing Juz title, starting verse snippet, and start page.
- [ ] **Local Search**:
  - [ ] Connect search field to `translations_fts` SQLite FTS5 index.
  - [ ] Implement debounced search query execution (<15ms response).
  - [ ] Render matched verses with highlighted keywords.
  - [ ] Tapping a search result immediately opens the reader to that exact page and ayah.

---

## 9. User Data & Persistence
- [ ] **User Database**: Create `user_data.sqlite` in `Application Support` via GRDB.
- [ ] **Bookmarks**:
  - [ ] Create table `bookmarks (id, ayah_id, page_number, created_at, note)`.
  - [ ] Add / remove bookmarks with instant UI updates.
  - [ ] Bookmark list view with swipe-to-delete.
- [ ] **Last-Read Memory**:
  - [ ] Auto-save `last_read_page` whenever user rests on a page for $>2$ seconds.
  - [ ] App launch immediately opens to `last_read_page`.

---

## 10. Offline Download Manager
- [ ] **Background URLSession**: Implement `DownloadManager` using background session configuration.
- [ ] **Download Storage**: Save downloaded audio files into `Application Support/Downloads/` and mark with `.isExcludedFromBackup = true`.
- [ ] **Surah/Juz Audio Packs**: Enable one-tap download of all MP3s for a chosen Surah or Juz.
- [ ] **Offline Storage UI**: Settings screen showing disk usage breakdown (App size, Page tiles, Audio cache) with "Clear Cache" action.

---

## 11. StoreKit 2 & Monetization
- [ ] **Product Configuration**:
  - [ ] Monthly Supporter Subscription (`com.company.thirteenlinequran.supporter.monthly`).
  - [ ] Annual Supporter Subscription (`com.company.thirteenlinequran.supporter.annual`).
  - [ ] Lifetime Supporter Pass (`com.company.thirteenlinequran.supporter.lifetime`).
- [ ] **Local StoreKit Testing**: Create `Subscriptions.storekit` file in Xcode for automated sandbox testing.
- [ ] **Paywall UI**:
  - [ ] Build `SupporterPaywallView` using StoreKit 2 `SubscriptionStoreView` or custom cards.
  - [ ] Prominent "Restore Purchases" button.
  - [ ] Functional links to Privacy Policy and Terms of Use (EULA).
  - [ ] Clear disclosure of renewal terms and cancel-anytime instructions.
- [ ] **Entitlement Listener**: Implement background `Transaction.updates` listener to unlock features immediately upon transaction completion.

---

## 12. Settings & Onboarding
- [ ] **Onboarding Flow**:
  - [ ] Screen 1: Welcome & core promise ("The 13-Line Mushaf, Beautifully Offline").
  - [ ] Screen 2: Choose default theme and translation.
  - [ ] Screen 3: Optional reading reminder time picker.
- [ ] **Settings Screen**:
  - [ ] Appearance picker (Light, Dark OLED, Warm Sepia).
  - [ ] Audio settings (Default reciter, audio quality).
  - [ ] Storage management (Downloads, cache size).
  - [ ] Supporter status & Restore Purchases.
  - [ ] About screen with full licensing attributions.

---

## 13. Accessibility & RTL Polish
- [ ] **VoiceOver**:
  - [ ] Map underlying Unicode text to each ayah bounding box element.
  - [ ] Add accessible labels to all icon buttons ("Play audio", "Add bookmark", "Next page").
  - [ ] Rotor support for navigating by Ayah or Surah.
- [ ] **Dynamic Type**: Ensure all UI chrome, settings labels, and translation sheets scale properly under Accessibility font sizes.
- [ ] **RTL Mirroring**: Verify that navigation stack and back buttons mirror naturally under Arabic system locales.

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
