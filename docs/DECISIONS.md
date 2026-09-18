# Architecture Decision Records (ADRs)

This document records the foundational architectural decisions for the 13-Line Quran application. Each record outlines context, alternatives considered, the final decision, and consequences.

---

## ADR-001: Native Swift & SwiftUI Platform (vs. React Native/Expo)

* **Status**: Accepted (Revised September 2026)
* **Date**: September 2026
* **Deciders**: Lead Architect, AI Vibe-Coding Lead

### Context
We need to build a commercial-grade, high-performance Quran reading app for iPhone. We must decide between Native Swift/SwiftUI and React Native (Expo). A major constraint is that the core developer operates on a **Windows machine**.

### Alternatives Considered
1. **React Native (Expo)**: With the New Architecture (Fabric/TurboModules), Reanimated 4 (120Hz support), and EAS Build, Expo is highly viable. It offers a vastly superior Windows iteration loop (instant JS refresh on a physical iPhone via a dev client, no Mac required). However, its audio capabilities (`expo-audio`), while greatly improved, lack built-in persistent offline caching and granular lock-screen coordination which are central to our app's core loop.
2. **Native Swift + SwiftUI (iOS 17+)**: Native provides direct access to `AVQueuePlayer` and StoreKit 2, offering the highest reliability for our complex audio and IAP requirements. However, the Windows iteration loop is brutal (requiring push -> cloud Mac build -> download artifact for every test).

### Decision
**Stay Native Swift and SwiftUI**.

While Expo is no longer the compromise it was in 2023 and is fully capable of rendering our UI (via Skia/Reanimated), we have already successfully built the two hardest, most differentiating components in Swift:
1. The `MushafReaderView` (hybrid tile engine with vector overlays)
2. The `AudioPlayerService` (offline caching, gapless `AVQueuePlayer`, lock-screen metadata)

Throwing away this working, highly-tuned native code to rebuild it behind a JavaScript abstraction—especially one where our exact audio requirements are the weakest link—is not pragmatic. The decision stands on **sunk differentiated engineering**, not framework theology.

### Consequences
* **Positive**:
  * We retain our highly reliable, custom `AVQueuePlayer` and StoreKit 2 implementations without relying on third-party TS wrappers (like `react-native-track-player` or RevenueCat).
  * Direct access to iOS 17+ APIs natively.
* **Negative**:
  * The Windows iteration loop remains slow and requires a Cloud Mac for compilation.
  * Android is not supported; a future Android port will require a separate Kotlin codebase.

---

## ADR-002: Hybrid Digital Tile Engine with Vector Ayah Bounding Boxes

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Domain Expert, iOS Architect

### Context
The 13-line Mushaf format has an immutable physical lithographic geometry: exactly **849 pages** in the canonical Qudratullah Company (Lahore) edition. Hafiz (memorizer) users rely on photographic spatial memory. We must decide how to render the 849 pages.

### Alternatives Considered
1. **Dynamic Font Layout via CoreText**: Render verses dynamically into 13 lines using Indo-Pak fonts and line layout data.
   * *Rejected*: Complex Arabic vertical ligatures and diacritics cause glyph clipping and variable line-wrapping across screen sizes, altering page boundaries and breaking Hifz memory.
2. **Raw Scanned Bitmap Images**: Display raw scanned JPEGs/PNGs.
   * *Rejected*: Huge binary download size (1.5–2 GB), blurry on Super Retina screens, broken dark mode, and zero VoiceOver accessibility.
3. **Hybrid Digital Tile Engine**: Clean, vector-rasterized high-definition page tiles in AVIF/WebP format paired with an immutable SQLite database of normalized Ayah Bounding Boxes `(min_x, min_y, max_x, max_y)` and an invisible Unicode text accessibility mirror.

### Decision
Adopt the **Hybrid Digital Tile Engine** calibrated across all **849 pages**.

### Consequences
* **Positive**:
  * Total page asset size for all 849 pages compressed to **~75–85 MB**.
  * Perfect visual fidelity identical to the traditional printed 13-line lithograph.
  * Instant tap-to-select ayah, golden highlight tinting, and synchronized audio playback highlights.
  * Full Apple VoiceOver accessibility via the underlying Unicode mirror.
  * Custom dark and sepia shaders can re-tint the ink and paper layers cleanly.
* **Negative**:
  * Requires building and verifying the 849-page coordinate mapping database upfront.

---

## ADR-003: Dual-Database SQLite Architecture via GRDB.swift

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Technical Lead, Data Architect

### Context
The app manages two distinct classes of data: read-only immutable Quran content (verses, translations, coordinates, metadata) and mutable user data (bookmarks, reading history, preferences). We must choose the persistence framework.

### Alternatives Considered
1. **SwiftData for User Data + SQLite for Content**:
   * *Rejected*: SwiftData in iOS 17/18 exhibits multi-threading concurrency faults inside async `Task` contexts, schema migration fragility, and opaque runtime errors that frequently derail AI coding agents.
2. **Core Data**:
   * *Rejected*: Verbose boilerplate, complex `.xcdatamodeld` file editing that AI agents frequently corrupt, and high ceremonial overhead.
3. **GRDB.swift (SQLite) for Both**:
   * Pure SQL / type-safe Swift records, thread-safe `DatabaseQueue` / `DatabasePool`, and WAL mode.

### Decision
Use **GRDB.swift** (or a lightweight SQLite3 wrapper) to manage two isolated databases:
1. `quran_content.sqlite`: Read-only, pre-compiled, bundled with the app, verified by SHA-256 hash. Contains FTS5 full-text search index.
2. `user_data.sqlite`: Read-write, located in `Application Support`, handles bookmarks, reading logs, and settings.

### Consequences
* **Positive**:
  * 100% deterministic concurrency and zero mysterious crash states.
  * Clean separation of concerns: updating Quran content can never corrupt user bookmarks.
  * FTS5 provides instant offline search across thousands of verses with zero latency.
* **Negative**:
  * Requires importing GRDB.swift as an SPM (Swift Package Manager) dependency.

---

## ADR-004: 100% Offline-First Core with Zero Remote Leash

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Product Manager, Technical Lead

### Context
Document 05 suggested that Quran Foundation API's 7-day re-sync policy should govern offline data storage.

### Alternatives Considered
1. **7-Day Remote Content Sync Lease**: Enforce a 7-day re-sync window where content must re-validate with a remote server.
   * *Rejected*: Catastrophic UX for users traveling on flights, during Hajj/Umrah with zero connectivity, or in remote areas.
2. **100% Local-First Core**: Bundle the entire 13-line Mushaf structure, coordinates, metadata, and default translation directly in the app.

### Decision
The core reading experience is **permanently local and 100% offline**. External APIs (Quran Foundation, EveryAyah) are strictly used for auxiliary services (streaming audio, downloading extra reciter packs), never as a runtime gating mechanism.

### Consequences
* **Positive**:
  * The app functions indefinitely in airplane mode from the moment of installation.
  * Zero server uptime dependency for core reading.

---

## ADR-005: Public-Domain Translations for V1

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Legal Specialist, Product Manager

### Context
Tanzil translations are restricted to non-commercial use. Popular modern translations (*The Clear Quran*, *Sahih International*) are copyrighted by commercial publishers who enforce DMCA takedowns against commercial apps.

### Alternatives Considered
1. **Bundle Modern Translations without License**:
   * *Rejected*: Immediate legal liability, risk of App Store removal, and developer account termination under Guideline 5.2.2.
2. **Bundle Verified Public-Domain Translations**:
   * English: Marmaduke Pickthall (1930) and Abdullah Yusuf Ali (1934 original).
   * Urdu: Fateh Muhammad Jalandhari (1944).

### Decision
Launch V1 strictly with **verified public-domain translations**. Formal licensing discussions with modern publishers (e.g. Furqaan Foundation, Darussalam) will be pursued post-launch for V1.5.

### Consequences
* **Positive**:
  * 100% legally clean; zero risk of copyright infringement or DMCA takedowns.
* **Negative**:
  * Language in Pickthall/Yusuf Ali is somewhat archaic compared to modern editions.

---

## ADR-006: Audio Recitation Strategy & Fair-Use Streaming

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Audio Engineer, Monetization Strategist

### Context
Recitation audio files are distributed under open Islamic commons (EveryAyah, Quran Foundation), but some have CC-BY-NC tags. We need an ethical and legally compliant audio model.

### Decision
1. **Free Tier**: Free, ad-free streaming of 1–2 primary reciters (e.g., Mishary Rashid Alafasy, Mahmoud Khalil Al-Husary). We do **not** sell access to the recitation of the Quran.
2. **Supporter Tier**: Monetizes mobile utility—unlimited offline audio downloads, advanced multi-verse repeat looping for Hifz memorization, and custom playback speeds.
3. **Engine**: Implemented via native `AVQueuePlayer`, `AVAudioSession` (`.playback` category), with complete lock-screen `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration.

---

## ADR-007: Zero-Account, Privacy-First Architecture

* **Status**: Accepted
* **Date**: September 2026
* **Deciders**: Privacy Officer, Lead Architect

### Context
Religious reading history is sensitive personal data (GDPR Article 9 "special category"). Many competing apps have suffered reputational damage by tracking users or selling location data (e.g., Muslim Pro / X-Mode scandal).

### Decision
1. **Zero Accounts**: No sign-up, no email collection, no passwords, no third-party social logins.
2. **Zero Advertising**: No ad SDKs (no AdMob, no Meta Audience Network).
3. **Private Sync**: Optional future sync uses Apple's private CloudKit database tied silently to the user's iCloud, where the developer has zero access to user data.
4. **App Privacy Label**: File App Store declaration as **"Data Not Collected"**.

---

## ADR-008: 100% Free, Ad-Free & Open (Zero Paywall / Sadaqah Jariyah)

* **Status**: Accepted (Supercedes prior Supporter Pass draft)
* **Date**: September 2026
* **Deciders**: Product Lead, User / Stakeholder

### Context
Monetizing a Quran app requires great care and reverence. Users strongly reject aggressive paywalls, subscriptions, countdown timers, fake discounts, and advertising during worship. Furthermore, all core scripture and audio recitations are community and public-domain trusts.

### Decision
1. **Zero Paywall & Zero Subscriptions**:
   * The app is 100% free and 100% ad-free forever.
   * There are no paywalls, no StoreKit subscriptions, no locked features, and no in-app purchases.
2. **Unrestricted Utility**:
   * All offline audio recitation packs (Sheikh Khalifa Al Tunaiji, 64kbps) are 100% free to download.
   * All reading themes (Sepia, Soft Ivory, Midnight OLED Dark) are 100% free and unlocked.
   * Full-text FTS5 search, bookmarks, and reading history are completely unrestricted.
3. **Purity of Experience**:
   * The app is presented as a pure, focused religious utility (Sadaqah Jariyah) with zero commercial distraction.
