# Technical Architecture

## 1. Stack Decision

### 1.1 Comparison

| Criterion | Native Swift + SwiftUI | Flutter | React Native |
|---|---|---|---|
| AI/vibe-coding reliability | **Best.** SwiftUI is heavily represented in modern LLM training data, has a small idiomatic surface for common patterns (List, NavigationStack, @Observable), and Xcode's compiler errors give an AI agent precise, actionable feedback to self-correct against. | Good, but Dart is a smaller corpus and Flutter's widget-tree verbosity gives an agent more surface area to get subtly wrong. | Widest training data of the three, but JS/TS + native-bridge bugs (especially around native modules for audio/StoreKit) are a common source of AI-introduced, hard-to-diagnose issues. |
| Native iOS integration (StoreKit 2, CloudKit, MPNowPlayingInfoCenter, widgets, Live Activities) | **Best — first-class, zero bridging.** | Requires plugins/bridges for StoreKit 2's newest APIs, CloudKit, widgets; plugin quality/maintenance varies. | Same bridging tax as Flutter, generally worse for anything StoreKit-2-specific since Apple ships Swift-only APIs first. |
| Arabic/RTL + custom text layout (13-line Mushaf rendering) | **Best.** Core Text / CoreGraphics give precise control over per-word glyph placement, essential for reproducing a fixed line-by-line Mushaf layout exactly. SwiftUI's `Text`/`AttributedString` plus a custom `Canvas`/`CoreText` layer for the Mushaf page is a well-trodden pattern. | Flutter's text engine (Skia-based) handles Arabic shaping reasonably but fine per-word/per-line pixel-perfect layout control (needed for the QUL-style line data model in doc 05) is more fragile and less documented. | Weakest of the three for this specific requirement — RN text layout is the least suited to a custom fixed-page-layout renderer; would likely need a native module anyway, eliminating RN's main advantage. |
| Offline capability | Best — native `FileManager`/SQLite/Core Data/SwiftData all first-class, no bridge overhead for large local datasets (audio files, page data). | Good, mature offline packages exist. | Good, but large offline datasets + native audio-file management again push you toward native modules. |
| App Store compliance risk | **Lowest.** You are always on Apple's officially supported, first-priority APIs. | Low-moderate — Flutter is well-established and Apple-approved, but you inherit Flutter-engine-level risk on major iOS version bumps. | Low-moderate — similar profile to Flutter. |
| Animation quality (page turns, transitions) | **Best** — SwiftUI/UIKit animations are tuned to match system feel by default. | Good — Flutter animations are smooth but have a subtly different "physics feel" than native iOS. | Weaker by default; achieving native-feeling animation requires more manual tuning. |
| Maintainability / future scalability | Best long-term for an iOS-only, quality-over-reach product; you don't pay a cross-platform abstraction tax you'll never use if you never ship Android. | Best choice **only if Android is a near-term goal** — not stated as a goal here. | Same caveat as Flutter. |
| Subscription implementation | **Best** — direct StoreKit 2, `SubscriptionStoreView`, App Store Server Notifications v2 all native. | Requires `in_app_purchase` plugin wrapping StoreKit; workable but one abstraction layer removed from Apple's latest APIs. | Similar to Flutter via `react-native-iap`. |

### 1.2 Decision

**Native Swift + SwiftUI (iOS 17+ minimum, targeting current-generation iOS at ship time).** This is not close, given: (a) no stated cross-platform requirement, (b) the single hardest technical problem in this app — pixel-faithful, per-word Mushaf page rendering — is best solved with Core Text/Canvas, which is a native-only strength, (c) vibe-coding reliability is explicitly a priority, and SwiftUI's smaller, more idiomatic surface plus Xcode's precise compiler diagnostics give an AI coding agent the tightest feedback loop of the three options, and (d) every piece of platform-specific compliance surface (StoreKit 2, privacy manifests, CloudKit, background audio, Sign in with Apple exemption logic) is simplest and lowest-risk when there's no bridge layer to reason about.

**When to revisit this decision:** if and only if Android becomes a real, funded goal post-launch — at that point, evaluate a *shared content/data layer* (the SQLite-based Quran datasets in doc 05 are platform-agnostic) with separate native UI on each platform, rather than retrofitting a cross-platform UI framework onto an app designed around native Mushaf rendering.

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SwiftUI Views (Reader, Discover, Bookmarks, Progress,    │
│  Settings, Paywall, Onboarding)                           │
├─────────────────────────────────────────────────────────┤
│  View Models / @Observable state (one per screen/flow)    │
├─────────────────────────────────────────────────────────┤
│  Domain Services:                                         │
│   - MushafRenderer (page/line layout → drawable glyphs)   │
│   - QuranContentStore (Arabic text, translations, tafsir) │
│   - AudioEngine (playback, downloads, now-playing)        │
│   - SearchIndex (surah/juz/text search)                   │
│   - BookmarkStore / NotesStore / ProgressStore            │
│   - SubscriptionManager (StoreKit 2)                      │
│   - SyncManager (CloudKit, optional)                      │
│   - ContentSyncClient (Quran Foundation Content Sync API)  │
├─────────────────────────────────────────────────────────┤
│  Persistence: SQLite (read-only, bundled + downloadable    │
│  content datasets) + SwiftData/Core Data (user-generated   │
│  data: bookmarks, notes, progress, settings)               │
├─────────────────────────────────────────────────────────┤
│  Platform: FileManager, StoreKit 2, CloudKit, AVFoundation,│
│  BackgroundTasks, UserNotifications                        │
└─────────────────────────────────────────────────────────┘
```

**Key architectural principle: content data and user data are separate stores with separate lifecycles.** Quran content (text, translations, tafsir, audio, mushaf layout) is versioned, read-only from the app's perspective, and can be wiped/re-downloaded safely at any time. User data (bookmarks, notes, progress, settings) is precious, small, and must never be touched by a content update/migration. This separation is also what makes the content-integrity verification pipeline in doc 05 possible: content data has a checksum/version and can be validated independently of anything the user has created.

---

## 3. Layer-by-Layer Detail

### 3.1 Data Layer
- **Bundled read-only SQLite databases** (shipped in the app bundle for the free tier's core content: Arabic Uthmani/IndoPak text, the 13-line Mushaf layout dataset, one translation, surah/juz/hizb/sajdah metadata) — following the exact schema pattern used by QUL exports (`pages` table: page_number/line_number/line_type/first_word_id/last_word_id/surah_number/is_centered; `words` table: word_index/word_key/surah/ayah/text). Using a schema pattern that already exists in a widely-used real dataset means less novel schema design for an AI agent to get wrong.
- **Downloadable SQLite/JSON packs** for premium content (additional translations, tafsir, audio index) — fetched via `ContentSyncClient`, stored in `Application Support`, versioned with a manifest (version number + checksum) so updates can be detected and applied atomically (download new file, verify checksum, swap, delete old — never modify in place).
- **Audio files** stored in `Library/Application Support` (not `Documents`, to control iCloud-backup behavior — see below), organized `reciter/surah/ayah.m4a` or per-surah files depending on the audio API's actual delivery granularity.
- **User data** in SwiftData (iOS 17+ native, actively maintained, less migration ceremony than Core Data for a new project) for bookmarks, notes, highlights, reading history, streak/progress state, and settings.
- **iCloud backup behavior:** exclude large downloaded content (audio, extra translations) from iCloud backup via `URLResourceValues.isExcludedFromBackup` — Apple explicitly discourages backing up re-downloadable content, and it avoids bloating the user's iCloud storage. User-generated data (bookmarks/notes, which are small) should remain backed up.

### 3.2 UI Layer
- SwiftUI throughout; the one exception is the Mushaf page renderer itself, which should be a custom `Canvas`/Core Text-backed view (wrapped as a SwiftUI `View`) rather than composed from stock `Text` views, because per-word placement fidelity to the 13-line layout data requires lower-level control than SwiftUI's text layout gives you by default.
- Navigation via `NavigationStack` with typed, `Codable` navigation values (e.g., `PageReference(surah:ayah:page:)`) so deep links (from search results, bookmarks, widgets) can push directly to a specific page without re-deriving state.
- Design tokens (colors, spacing, type scale) centralized in one file consumed everywhere — critical for vibe-coding consistency, since it gives an AI agent one place to look up "what color/spacing should this be" instead of guessing per-screen.

### 3.3 State Management
- `@Observable` (Swift Observation framework, iOS 17+) view models, one per major screen/flow, injected via SwiftUI's environment where shared across screens (e.g., `AudioPlaybackState`, `SubscriptionState`) and owned locally where screen-specific.
- Avoid a single monolithic app-wide state object — it's the single most common way an AI coding agent accidentally couples unrelated features (e.g., editing the paywall accidentally breaks bookmarks because both read/write the same giant state blob). Keep domain services independent and composed only where a screen genuinely needs more than one.

### 3.4 Local Database
- SQLite via a thin wrapper (e.g., GRDB.swift — mature, well-documented, good migration story) for the read-only content databases described above.
- SwiftData for user data.
- **Never mix the two roles** — content databases are never written to by the running app (only replaced wholesale on update); user databases are never touched by a content-pack update.

### 3.5 Offline Storage
- Core free-tier content (Arabic text + one translation + the 13-line layout + fonts) ships **inside the app bundle** — the app must be 100% functional for its free-tier core with zero network access from first launch, which both delights users and sidesteps guideline §4.2.3(ii)'s "disclose download size before downloading additional resources on first launch" concern for the essential experience.
- Premium content (extra translations/tafsir/reciters) downloads on-demand via `ContentSyncClient`, respecting the Quran Foundation Content Sync re-sync cadence (≤7 days between syncs while online) described in doc 05, with all of it fully usable offline between syncs.
- Background refresh (via `BackgroundTasks` framework) opportunistically performs the periodic content re-sync when the app is backgrounded on Wi-Fi/charging, so the 7-day sync obligation is met without the user having to think about it.

### 3.6 Networking
- A single thin networking layer wrapping `URLSession` (async/await), used only by `ContentSyncClient` (Quran Foundation API) and, if used, `SyncManager`'s CloudKit calls (which go through Apple's CloudKit APIs directly, not raw networking).
- No custom backend server for V1. This app does not need one: content comes from Quran Foundation's API, subscription state comes from StoreKit 2 (verified on-device via `Transaction.currentEntitlements`), and cross-device sync (if any) comes from CloudKit. Avoiding a custom backend eliminates an entire category of security/privacy/ops risk and cost with no product downside at this scale — revisit only if a future feature genuinely requires server-side logic (none currently do).

### 3.7 Audio Engine
- `AVQueuePlayer`/`AVPlayer` for playback, `AVAudioSession` configured for the `.playback` category so audio continues in the background and interacts correctly with other apps (e.g., pausing appropriately for phone calls, resuming per user preference after interruptions).
- `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` for lock-screen/Control Center/AirPods controls — required for a genuinely good audio experience and effectively free once `AVAudioSession` is configured correctly.
- A dedicated `DownloadManager` (built on `URLSession` background configuration, not the foreground session) for audio-file downloads, so downloads survive app suspension/termination and resume correctly — this is a common source of real-world bugs (see doc 07) and deserves careful, isolated implementation and testing.

### 3.8 Search Engine
- V1: local, on-device search over bundled/downloaded SQLite content — surah/juz/page/ruku lookup is a simple indexed query; Arabic/translation text search uses SQLite's FTS5 (full-text search) extension, which GRDB supports directly, avoiding any need for a third-party search service or network dependency.
- This keeps search instant, fully offline, and privacy-preserving (search queries never leave the device).

### 3.9 Content Management
- `ContentSyncClient` is the single integration point with Quran Foundation's Content Sync APIs (mushaf layouts, translations, tafsirs, recitations) — see doc 05 for the exact licensing constraints this must respect (attribution, re-sync cadence, no raw redistribution).
- A `ContentVerificationService` runs at the end of every content download/update (see doc 05 for the full pipeline) before the new content pack is "activated" — if verification fails, the update is discarded and the previous known-good pack remains active. **The app must never allow a corrupted or failed-verification content pack to become active**, even silently — this is the single most important reliability rule in the entire system, given the subject matter.

### 3.10 Download Manager
- Described in 3.7/3.9 above; unified across audio and content-pack downloads so the Settings → Downloads screen (doc 03 §3.9) has one consistent model to display progress/pause/resume/delete for any asset type.

### 3.11 Subscription System
- StoreKit 2 exclusively (no StoreKit 1/receipt-based code paths). One subscription group ("Premium") with monthly and annual auto-renewable products, plus (V1.1+) a non-consumable "Lifetime" product.
- Entitlement state read via `Transaction.currentEntitlements` on launch and on `Transaction.updates` stream; no custom server-side receipt validation needed for V1 given no server-dependent premium features (all premium content is delivered the same way to everyone — the subscription only gates *access*, checked entirely on-device).
- Consider **RevenueCat** as an optional abstraction layer if you want cross-referenceable subscription analytics/dashboards without building your own — it's a mature, widely-used wrapper over StoreKit 2 with its own privacy manifest, though it's an added dependency to evaluate against the "avoid unnecessary infrastructure" principle. For a single-platform, single-subscription-group app, plain StoreKit 2 is likely sufficient and simpler to reason about for an AI agent.

### 3.12 Analytics
- **TelemetryDeck** (or equivalent anonymous-signal analytics) for coarse product metrics (onboarding completion, paywall views/conversions, feature usage) — no user-level identifiers, no cross-app tracking, no ATT prompt required. This is the recommended default given the privacy-first positioning from doc 01.
- Explicitly avoid Firebase Analytics/Google Analytics for this app — the broader Google data-collection surface conflicts with the "out-privacy Muslim Pro" positioning and adds unnecessary App Store privacy-label complexity.

### 3.13 Crash Reporting
- **Sentry** (cloud-hosted or self-hosted) with on-device symbolication where possible, collecting device/OS/stack-trace data only — no user identifiers attached. Ships its own privacy manifest; verify current manifest compliance at integration time.
- Apple's own **MetricKit** (built-in, zero third-party dependency) is worth using in addition for basic crash/hang diagnostics with zero added privacy-label surface — a genuinely "free" starting point before adding any third-party SDK at all.

### 3.14 Remote Configuration
- **Not needed for V1.** There's no product justification for server-controlled feature flags at this scale, and it adds a server dependency and privacy-label surface for no launch-blocking benefit. Revisit only if you need to run A/B tests on the paywall post-launch (and even then, StoreKit's own experimentation tools may suffice before reaching for a third-party remote-config SDK).

### 3.15 Authentication
- **Not needed for V1.** No login is required to use any V1 feature, including Premium (subscription entitlement is device/Apple-ID-scoped via StoreKit, not tied to an app-specific account). This directly satisfies guideline §5.1.1(v) ("let people use it without a login") and sidesteps §4.8 (Sign in with Apple) entirely, since no third-party/social login is used.

### 3.16 Cloud Synchronization
- **Optional, CloudKit-only, private database.** Syncs last-read position, bookmarks, notes, highlights, and streak/progress across a user's own devices, scoped to their Apple ID, with zero server-side visibility for you as the developer (Apple manages the private database; you never see the data). This is both the simplest technically-correct implementation and the one that best avoids the GDPR "special category data" exposure discussed in doc 01/06 — you are never a data controller for this synced content because you never have access to it.
- No custom backend, no user accounts, no server-side database of religious reading behavior — full stop. This is a load-bearing decision for both privacy and vibe-coding simplicity (there is no server code to write, deploy, secure, or maintain).

---

## 4. Project Structure (for the AI coding agent to follow)

```
QuranApp/
  App/                      — App entry point, environment setup
  DesignSystem/             — Colors, typography, spacing tokens, reusable components
  Features/
    Reader/                 — Mushaf reading screen + MushafRenderer
    Discover/                — Surah/Juz list, search
    Bookmarks/               — Bookmarks, notes, highlights, history
    Progress/                — Streak, goals, khatm planner
    Settings/
    Onboarding/
    Paywall/
  Domain/
    QuranContentStore/       — Read-only content access layer
    AudioEngine/
    SearchIndex/
    SubscriptionManager/
    SyncManager/             — CloudKit
    ContentSyncClient/        — Quran Foundation API integration
    ContentVerification/      — doc 05's integrity pipeline
  Persistence/
    ContentDatabase/          — SQLite/GRDB read-only layer
    UserDataStore/             — SwiftData models
  Resources/
    Bundled content databases, fonts, localized strings
  Tests/
    Unit/ Integration/ ContentIntegrity/ UITests/
```

This structure is referenced directly by the phase-by-phase prompts in document 08 — each phase should only touch the folders relevant to it, which is the primary mechanism for preventing an AI coding agent from making sprawling, unrelated changes across the codebase.
