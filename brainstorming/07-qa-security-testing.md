# QA, Testing Strategy & Security/Reliability

## 1. Functional Testing

| Area | What to test |
|---|---|
| Navigation | Surah/juz/page/ruku jump lands on the exact correct page; deep links from search/bookmarks land on the exact ayah; swipe navigation never skips or duplicates a page at boundaries (surah start/end, juz boundaries, page 1 and the final page). |
| Search | Surah-name search (Arabic, transliteration, translated name), page-number search, in-translation text search (once downloaded); empty-query and no-result states; search across right-to-left and left-to-right mixed content. |
| Bookmarks | Add/remove/persist across app restarts; behave correctly at the exact first and last ayah of a surah/juz. |
| Audio | Play/pause/seek; ayah-highlight-sync accuracy; continuous playback across ayah/surah/juz boundaries; background playback continues correctly when the app is backgrounded and when the screen locks; lock-screen/Control Center/AirPods controls all function; interruption handling (phone call, other audio app, Siri) resumes or pauses correctly per iOS convention. |
| Downloads | Start/pause/resume/cancel/delete for both content packs and audio; resume correctly after an interrupted download (app killed mid-download, network dropped mid-download); storage-full handling (see §4). |
| Offline mode | Full core reading/audio/search functionality with network fully disabled from a cold launch; correct, calm messaging when a premium action requires content that hasn't been downloaded yet, rather than a silent failure. |
| Subscriptions | Purchase flow (sandbox), trial-to-paid conversion, cancellation, downgrade/upgrade between monthly and annual, **Restore Purchases from a fresh install / new device**, subscription lapsing gracefully (content remains visible-but-locked, not deleted, when a subscription ends). |
| Settings | Every toggle persists correctly and takes effect immediately (theme, keep-awake, audio quality, notification time). |
| Notifications | Local reading-reminder notification fires at the configured time; tapping it deep-links into the Reader; permission-denied state handled gracefully (feature disabled with clear explanation, not a repeated permission nag). |
| Deep links | Any URL scheme/Universal Link used by a widget or notification correctly opens to the intended page even from a cold app launch. |

---

## 2. Quran-Content Integrity Testing (see doc 05 §6 for the full pipeline — this is the QA-process view of the same system)

Automated, run on every build/content update, not just before release:
- Byte-for-byte / character-for-character diff of the active Arabic text against the golden Tanzil-sourced reference corpus.
- Ayah-per-surah counts match the known-correct table for all 114 surahs; total ayah count matches the expected figure confirmed with your scholarly reviewer.
- No duplicate or missing (surah, ayah) keys; sequential integrity across the entire corpus.
- Page/line layout dataset: every ayah/word appears exactly once across the full 13-line pagination, with no words dropped or duplicated at page/line boundaries; total page count matches the expected figure for the chosen layout.
- Surah/juz/hizb/rub'/sajdah/manzil metadata matches known-correct reference tables.
- Unicode integrity: no replacement characters, no malformed UTF-8, no unexpected combining-mark corruption anywhere in the corpus.
- RTL rendering correctness: automated screenshot/snapshot tests of a representative sample of pages (including pages with mixed basmala/surah-heading lines, sajdah markers, and juz-boundary markers) checked against a manually-verified baseline image, to catch layout-engine regressions that wouldn't show up in a pure text diff.
- **Human sign-off gate:** no content-affecting release ships without your scholarly reviewer's explicit approval, independent of and in addition to the automated suite — the automated suite proves *nothing changed unexpectedly*, the human reviewer confirms *it's correct in the first place*.

---

## 3. Device & Environment Testing Matrix

| Dimension | Coverage |
|---|---|
| iPhone sizes | Smallest actively-supported screen (e.g., iPhone SE-class), a mid-size model, and a Pro Max-class large screen — Mushaf page layout must remain legible and correctly proportioned at every size without cropping or excessive whitespace. |
| iOS versions | Current release and at least one prior major version (per your chosen minimum deployment target) to catch API behavior differences. |
| Appearance | Light, Dark, and the sepia reading mode, each tested against every major screen, not just the Reader. |
| Dynamic Type | Default through the largest accessibility text sizes, on every screen with reflowable text (Settings, Discover, translation panel) — confirm the *fixed* Mushaf page correctly does *not* reflow (per doc 02's typographic rule) while surrounding chrome does. |
| Locale | Arabic system locale (RTL system-wide layout mirroring) and English/other UI locales, confirmed independently — the Mushaf page is always RTL regardless of system locale, but surrounding chrome should mirror correctly under an RTL system locale. |
| Network conditions | Full offline, slow/constrained (Network Link Conditioner or equivalent), and normal — confirm downloads pause/resume sensibly rather than failing outright under a flaky connection. |
| Storage | Low/near-full device storage — confirm the app fails downloads gracefully with a clear message rather than corrupting a partially-written content pack (ties directly to doc 05's "never activate an unverified pack" rule). |
| Battery | Low Power Mode — confirm background audio/downloads behave per system-imposed constraints rather than the app assuming unlimited background execution. |
| App lifecycle | Background/foreground transitions mid-audio-playback, mid-download, and mid-page-turn-animation; force-quit and relaunch mid-download to confirm resumability; cold launch performance (time to first readable page) measured explicitly as a quality bar. |
| Bluetooth/AirPods | Connect/disconnect during playback; verify automatic routing behavior matches system convention (e.g., pausing on disconnect per standard iOS audio behavior) rather than fighting it. |
| Screen lock | Lock/unlock during active reading and during active playback; confirm lock-screen now-playing info and controls are accurate and responsive. |

---

## 4. Security, Content Integrity & Reliability Risks

| Risk | Mitigation |
|---|---|
| **Content corruption** (partial download, disk error, bad merge introducing a text change) | The verification pipeline in doc 05 §6, run at build time, at download time, and as a runtime tripwire on every launch; atomic pack-swap (verify fully before activating, never activate partially-written data). |
| **Subscription fraud** (jailbreak-based entitlement spoofing, replayed/shared receipts) | Rely on StoreKit 2's built-in JWS-signed transaction verification (`Transaction.currentEntitlements`) rather than any custom validation logic; avoid rolling your own receipt-parsing code, which is a common source of both bugs and exploitable gaps. |
| **Download/offline-sync failures** (interrupted downloads, partial audio files, stale content past the 7-day Content Sync window) | Use `URLSession` background sessions with resumable downloads; checksum every downloaded asset before use; treat a missed 7-day re-sync window as a soft warning to the user ("content may be out of date, connect to refresh") rather than a hard failure, since offline usability must never break even if the compliance re-sync is delayed by the user's own connectivity choices. |
| **Data corruption in user-generated data** (bookmarks/notes/progress) | Keep the user-data store (SwiftData) completely separate from the content-data store (SQLite) as described in doc 04, so a content update can never corrupt user data and vice versa; consider a lightweight local backup/export of user data the user can trigger manually as an extra safety net, independent of CloudKit sync. |
| **CloudKit sync conflicts** (same bookmark edited on two devices while offline) | Use CloudKit's built-in conflict resolution with a simple, predictable policy (e.g., last-write-wins per record) — acceptable for low-stakes personal data like bookmarks/notes, where perfect merge semantics aren't worth the complexity. |
| **Third-party dependency risk** (an SDK is abandoned, breaks on an iOS update, or silently changes its data practices) | Keep the dependency list deliberately small (per doc 04: TelemetryDeck, Sentry, GRDB, optionally RevenueCat) and each one replaceable — avoid deep architectural coupling to any single SDK's specific API surface where reasonably possible. |
| **Privacy/regulatory risk** (a future feature accidentally introduces identifiable processing of religious-practice data) | Treat doc 06 §1.4's GDPR reasoning as a standing architectural constraint for every future feature, not a one-time review — any proposal to add a custom backend or user-identified analytics event should be checked against this before implementation, not after. |
| **App Store/API dependency risk** (Quran Foundation changes its API, deprecates an endpoint, or changes licensing terms) | Their developer terms commit to "commercially reasonable advance notice (typically 30 days)" for breaking changes — build a monitoring habit (subscribe to their Updates page) and keep the `ContentSyncClient` isolated (doc 04's architecture) so a future API migration is a contained change, not a rewrite. |

---

## 5. Testing Tooling Notes

- Use Xcode's `XCTest` for unit/integration tests, `XCUITest` for UI flow tests, and snapshot-testing (e.g., a lightweight snapshot-test library) specifically for the Mushaf page renderer's visual regression coverage described in §2.
- Wire the content-integrity suite (doc 05 §6) into whatever CI you use (Xcode Cloud is a reasonable zero-infrastructure default given the "avoid unnecessary infrastructure" principle) so it runs on every pull request/commit, not just manually before release.
- TestFlight external testing (doc 06 §2.9) is your most valuable real-world QA signal for the content-accuracy dimension specifically — recruit testers who already own and use a physical 13-line Mushaf.
