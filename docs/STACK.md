# Technology Stack & Toolchain Specification

## 1. Core Platform & Tooling

| Component | Specification | Rationale |
| :--- | :--- | :--- |
| **Language** | **Swift 5.10 / Swift 6** | Strict concurrency safety, modern `async/await`, structured concurrency. |
| **UI Framework** | **SwiftUI** (Pure) | Modern declarative UI, native RTL layout mirroring, clean LLM generation. |
| **Minimum iOS Target** | **iOS 17.0+** | Provides `@Observable` macro, StoreKit 2 enhancements, and modern SwiftUI animations while covering ~95%+ of active iPhones. |
| **IDE & Build System** | **Xcode 16.0+** / Swift Package Manager (SPM) | App Store submission standard; zero CocoaPods or external dependency managers. |
| **Pre-Submission Compliance Audit** | **[Appflight](https://appflight.co/)** | Static analysis of `.ipa` binary & code to catch App Store rejection risks before submission. |

---

## 2. Layer-by-Layer Architectural Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  SwiftUI Views • @Observable ViewModels • DesignSystem      │
├─────────────────────────────────────────────────────────────┤
│                      DOMAIN SERVICES                        │
│  MushafViewportEngine • AudioPlaybackService • StoreManager │
│  SearchEngine • DownloadManager • NotificationManager       │
├─────────────────────────────────────────────────────────────┤
│                    DATA PERSISTENCE LAYER                   │
│  GRDB.swift (SQLite 3) • FTS5 Search • Thread-Safe Queues  │
│  quran_content.sqlite (Read-Only) • user_data.sqlite (WAL)  │
├─────────────────────────────────────────────────────────────┤
│                     APPLE SYSTEM FRAMEWORKS                 │
│  AVFoundation • MediaPlayer • StoreKit 2 • UserNotifications│
└─────────────────────────────────────────────────────────────┘
```

### 2.1 UI & Layout Engine
* **Observation**: Apple's Observation framework (`@Observable` macro) replaces legacy `ObservableObject` and `@Published` boilerplate, preventing excessive view re-renders during high-frequency audio progress updates.
* **Navigation**: Modern `NavigationStack` with typed `Hashable` destinations:
  ```swift
  enum NavigationDestination: Hashable {
      case reader(page: Int, targetAyahId: Int? = nil)
      case surahIndex
      case juzIndex
      case search
      case bookmarks
      case settings
      case paywall
  }
  ```
* **Mushaf Viewport**:
  * Paging container: SwiftUI `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` or lightweight `UIPageViewController` bridge configured for Right-to-Left navigation.
  * Tile Rendering: Optimized image canvas loading pre-rendered AVIF/WebP tiles at $1600 \times 2400$.
  * Coordinate Overlays: Normalized `(0.0 ... 1.0)` bounding box geometry mapping touches and drawing golden highlight rectangles.

### 2.2 Audio Engine
* **Playback Framework**: `AVFoundation` (`AVQueuePlayer`, `AVPlayerItem`).
* **Session Configuration**:
  ```swift
  try AVAudioSession.sharedInstance().setCategory(
      .playback,
      mode: .spokenAudio,
      options: [.allowAirPlay, .allowBluetooth]
  )
  ```
* **Lock Screen & Media Controls**:
  * `MPNowPlayingInfoCenter`: Publishes title ("Surah {Name} – Ayah {Number}"), reciter name, artwork, duration, and elapsed time.
  * `MPRemoteCommandCenter`: Handles Play, Pause, Toggle, Next Track, Previous Track, and Scrubber events from lock screen, Dynamic Island, and AirPods.

### 2.3 Data Persistence & Search
* **Database Driver**: **GRDB.swift** (v6.x) via Swift Package Manager.
* **Content Store (`quran_content.sqlite`)**:
  * Shipped inside app bundle as read-only resource.
  * Contains Surahs, Ayahs, Ayah Bounding Boxes, Public-Domain Translations, and FTS5 search virtual tables.
* **User Store (`user_data.sqlite`)**:
  * Created in `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`.
  * Configured with WAL (Write-Ahead Logging) mode and thread-safe `DatabaseQueue`.
  * Manages bookmarks, reading history logs, and user preferences.

### 2.4 In-App Purchases & Monetization
* **Framework**: **StoreKit 2** (Pure Swift `StoreKit` APIs).
* **Components**:
  * `SubscriptionStoreView` & `ProductView` for native, guideline-compliant paywall rendering.
  * `Transaction.updates` background task listener for real-time purchase and subscription status updates.
  * Local testing via `Configuration/Subscriptions.storekit` file in Xcode schemes.

### 2.5 Offline Download Manager
* **Framework**: `URLSession` with background download configuration:
  ```swift
  let config = URLSessionConfiguration.background(withIdentifier: "com.thirteenlinequran.downloads")
  config.isDiscretionary = false
  config.sessionSendsLaunchEvents = true
  ```
* **Asset Storage**: Saved in `Application Support/Downloads/` and marked with `URLResourceValues.isExcludedFromBackup = true` to avoid consuming iCloud backup quotas.

---

## 3. Dependency Policy: Minimal Third-Party Footprint

To maximize stability, ensure clean AI vibe-coding, and protect user privacy, we enforce a strict **zero-bloat dependency policy**:

| Library | Status | License | Purpose |
| :--- | :--- | :--- | :--- |
| **GRDB.swift** | **Approved** | MIT | High-performance, thread-safe SQLite wrapper and FTS5 interface. |
| **TelemetryDeck** | **Optional** | MIT | Lightweight, privacy-first, anonymous analytics (zero cookies, zero IP logging, no ATT required). |
| **Firebase / Google Analytics** | **Banned** | Proprietary | Incompatible with "Data Not Collected" privacy commitment. |
| **Third-Party Ad SDKs** | **Banned** | Various | AdMob, Unity, AppLovin are strictly prohibited. |
| **Third-Party IAP Wrappers** | **Rejected** | Various | RevenueCat is unnecessary for a single-platform app; native StoreKit 2 is cleaner and has zero third-party dependencies. |

---

## 4. Xcode Project Structure Blueprint

```
QuranApp/
├── App/
│   ├── QuranApp.swift                  // App Entry Point & Dependency Container
│   └── AppDelegate.swift               // Background Audio & Session Lifecycles
├── DesignSystem/
│   ├── ColorTokens.swift               // Ivory, Parchment, Midnight OLED, Gold
│   ├── TypographyTokens.swift          // SF Pro & IndoPak Font Definitions
│   └── Components/
│       ├── IslamicBanner.swift         // Vector Decorative Surah Header
│       └── PrimaryButton.swift
├── Domain/
│   ├── Models/                         // Surah, Ayah, AyahBound, Bookmark, Reciter
│   ├── Database/
│   │   ├── QuranDatabaseService.swift  // Read-only Content Access & FTS5 Search
│   │   └── UserDatabaseService.swift   // Bookmarks, History & Settings
│   ├── Audio/
│   │   ├── AudioPlaybackService.swift  // AVQueuePlayer & Reciter Synchronization
│   │   └── NowPlayingManager.swift     // Lock-screen & MPRemoteCommandCenter
│   ├── Downloads/
│   │   └── DownloadManager.swift       // Background URLSession & Tile Manager
│   └── StoreKit/
│       └── StoreKitManager.swift       // StoreKit 2 Purchase & Entitlement Logic
├── Features/
│   ├── Reader/
│   │   ├── MushafContainerView.swift   // 120Hz Paging Container (RTL)
│   │   ├── MushafPageView.swift        // Page Tile & Zoom Canvas
│   │   ├── AyahHighlightOverlay.swift  // Interactive Bounding Box Coordinates
│   │   └── TranslationSheetView.swift  // Bottom Sheet for Ayah Translations
│   ├── Navigation/
│   │   ├── IndexHubView.swift          // Surah, Juz, and Page Navigation
│   │   ├── SurahListView.swift
│   │   └── JuzListView.swift
│   ├── Search/
│   │   └── LocalSearchView.swift       // Instant FTS5 Search Interface
│   ├── Bookmarks/
│   │   └── BookmarksListView.swift     // Saved Verses & Reading History
│   ├── Paywall/
│   │   └── SupporterPaywallView.swift  // Ethical StoreKit 2 Subscription View
│   └── Settings/
│       ├── SettingsView.swift          // Theme, Audio Quality, Storage Management
│       └── AboutView.swift             // Sourcing Credits, Terms, Privacy Policy
├── Resources/
│   ├── Database/
│   │   └── quran_content.sqlite        // Bundled Immutable Quran Database
│   ├── Assets.xcassets                 // Icons, Graphic Assets, Color Sets
│   └── Configuration/
│       └── Subscriptions.storekit      // Local StoreKit Sandbox Testing File
└── Support/
    └── PrivacyInfo.xcprivacy           // Mandatory Apple Privacy Manifest
```
