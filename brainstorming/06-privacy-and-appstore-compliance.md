# Privacy Strategy & App Store Compliance Checklist

## 1. Privacy Strategy

### 1.1 What data does this app actually need?
Walking through every feature in doc 02: **almost none.** Reading position, bookmarks, notes, streak/progress, and settings are the entire set of "personal" data this app generates, and every one of them can live entirely on-device with no server ever seeing it. This is unusual for a modern app and is a genuine, marketable differentiator (see doc 01's Muslim Pro comparison) — treat "we don't need your data" as a headline feature, not just a compliance checkbox.

### 1.2 Do you need each of the following?

| Capability | Needed? | Why / why not |
|---|---|---|
| User accounts (email/password or social login) | **No** | Nothing in V1 requires identifying a user; all premium entitlement is handled by StoreKit against the user's existing Apple ID. |
| Sign in with Apple | **No** | Only required when using a third-party social login for a primary account (guideline §4.8) — this app has no login at all. |
| CloudKit / iCloud sync | **Optional, recommended** | The one sync feature (last-read/bookmarks/notes across devices) should use CloudKit's *private* database, which is scoped to the user's own Apple ID and never visible to you as the developer — the best available way to offer sync without becoming a data controller for religious-practice data. |
| Analytics | **Yes, but anonymous-only** | Product decisions need basic usage/conversion signals; use TelemetryDeck-style anonymous analytics (doc 04 §3.12), never user-identified analytics. |
| Crash reporting | **Yes** | Non-negotiable for shipping a reliable app; scope strictly to device/OS/stack-trace data (doc 04 §3.13). |
| Push notifications | **No** | Reading reminders are handled entirely by local notifications (`UNNotificationRequest`), which require no server, no push token, and no Apple Push Notification service registration at all. |
| Advertising | **No** | Explicitly excluded per doc 01/02 — conflicts with the privacy-first positioning and is unnecessary given the subscription model. |

### 1.3 Recommended architecture, restated simply
**Local-first by default, CloudKit-private for sync, no accounts, no server, minimal anonymous analytics, no ads.** This is simultaneously the most privacy-respecting option, the cheapest to build and operate, the lowest legal-exposure option under GDPR (see below), and the simplest for an AI coding agent to implement correctly, since there is no backend to design, secure, or maintain.

### 1.4 GDPR and religious data
Religious belief/practice is GDPR Article 9 "special category" data — this in principle applies the moment reading history, bookmarks, or notes are tied to an identifiable person and processed by *you* (as opposed to processed only by Apple's CloudKit infrastructure on the user's behalf). Because this architecture keeps that data device-local or in Apple-managed CloudKit private databases that you never access, **you are not acting as a data controller/processor for that data** in the same way you would be if you ran your own backend database of user reading activity. This is a genuine, substantive privacy win from the architecture choice in doc 04, not just a legal technicality — but confirm the reasoning with privacy counsel (doc 01 §7) before scaling to a large EU user base, and formally document your Article 6 + Article 9 basis for whatever *does* touch a server (i.e., essentially nothing in V1 beyond anonymous analytics events, which should not be identifiable or linkable to religious practice in the first place — design your analytics event schema to avoid ever sending, e.g., "user read Surah X for Y minutes" as an identified event).

### 1.5 Children's privacy (COPPA / kids-focused rules)
This app is not designed for or marketed to children specifically (it targets adult daily Quran readers), so Kids Category rules (guideline §1.3/§5.1.4) don't apply by default. Keep it that way deliberately: don't use "for kids"/"for children" language in metadata (which is reserved for the Kids Category per §2.3.8), and keep third-party SDKs to the minimal, non-advertising set described above regardless — this keeps you safely outside COPPA/Kids Category obligations without needing special handling.

### 1.6 Privacy policy content (what it must say, per guideline §5.1.1(i))
Must clearly state: what data is collected (essentially: anonymous usage analytics + crash diagnostics; optionally, CloudKit-synced personal content the developer cannot access), how it's collected, all uses of that data, that any third party you share data with (analytics/crash SDKs) provides equivalent protection, your data retention/deletion policy, and how a user can revoke consent or request deletion. Given how little data this app actually touches, this can and should be a short, plain-language document — a long, dense privacy policy would actually undercut the "trustworthy, calm" positioning.

---

## 2. App Store Launch Checklist

### 2.1 Accounts & setup
- [ ] Apple Developer Program enrollment ($99/year), as an individual or organization — note that highly-regulated-category apps require an organizational account, but a Quran reading app does not fall into that category, so individual enrollment is fine.
- [ ] Bundle ID registered (reverse-DNS, e.g., `com.yourcompany.quranapp`) in the Apple Developer portal.
- [ ] Certificates & provisioning profiles configured (Xcode's automatic signing is sufficient for a solo/small-team project).
- [ ] App Store Connect record created, matching the bundle ID.

### 2.2 Legal & policy documents
- [ ] Privacy policy published at a stable URL, linked in App Store Connect metadata *and* accessible from within the app (Settings → Privacy), per §5.1.1(i).
- [ ] Terms of use (can use Apple's standard EULA if you have no custom terms beyond it).
- [ ] Content-source attributions documented in-app (doc 05 §4) and available to App Review on request (guideline §5.2.2 requires you to provide authorization/permission documentation on request).
- [ ] Written licensing confirmations on file (or in progress) from Quran Foundation and Tarteel/QUL per doc 05 — keep this correspondence; App Review or a future dispute may ask for it.

### 2.3 App Privacy questionnaire (App Store Connect)
- [ ] Complete the "App Privacy" nutrition-label questionnaire accurately: given the architecture above, expect to declare "Diagnostics" (crash data) and possibly minimal "Usage Data" (analytics), both **not linked to identity** and **not used for tracking** — resulting in the simplest, most favorable privacy label the framework offers. Do not declare data types you don't actually collect, and do not omit ones you do (both are guideline violations under §2.3.1).
- [ ] `PrivacyInfo.xcprivacy` manifest included in the app target and in every third-party SDK that requires one (check each SDK's own manifest is present and current at integration time — this is a moving target maintained per-SDK).

### 2.4 Age rating
- [ ] Answer the App Store Connect age-rating questionnaire honestly; expect a 4+ rating for a Quran reading app with no user-generated content, no mature themes, and no third-party ad content — matching the age rating of every serious competitor researched in doc 01.

### 2.5 Store listing
- [ ] App name (≤30 characters), keeping it distinct from existing "Quran 13 Line"-style names to avoid confusion under §4.1/§2.3.7.
- [ ] Subtitle (≤30 characters) describing the 13-line/Mushaf focus specifically — this is your differentiation surface in search.
- [ ] Keywords reflecting "13 line quran," "hafizi quran," "mushaf," "quran offline," etc.
- [ ] Description written in plain language, accurately describing free vs. Premium features per §2.3.2 (any promoted IAP must be clearly described).
- [ ] Screenshots showing the app **in actual use** (the reader, the translation panel, the audio player), not just a splash/login screen, per §2.3.3.
- [ ] App preview video (optional but recommended) — real screen capture only, per §2.3.4.
- [ ] App icon: simple, calm, timeless — avoid generic "green Islamic app" clichés if possible; this is a place the "premium, not generic" positioning should show up immediately.
- [ ] Category: Reference or Lifestyle (verify against current App Store Category Definitions at submission time; competitors researched span both).

### 2.6 In-App Purchase / Subscription configuration
- [ ] Subscription group created ("Premium") with monthly + annual auto-renewable products, each ≥7-day period (§3.1.2).
- [ ] Subscription pricing, localized per storefront as desired.
- [ ] Introductory/free-trial offer configured, with in-app copy disclosing duration, what happens at trial end, and cancellation instructions before purchase (§3.1.2(c), §4.9).
- [ ] "Restore Purchases" implemented and tested (required — guideline §3.1.1 references restorable IAPs generally, and it's a hard App Review expectation in practice).
- [ ] StoreKit Configuration file set up for local testing (Xcode scheme), plus a **Sandbox tester account** in App Store Connect for end-to-end purchase testing before submission.

### 2.7 Review notes & demo access
- [ ] Because there is no login, App Review needs no demo account — explicitly state this in review notes ("No account or login is required; all features are accessible on first launch") to preempt a common reviewer question.
- [ ] Explain any non-obvious premium-gated feature explicitly in review notes (§2.1(b)), especially the khatm planner and offline-download-pack behavior, since reviewers may not intuitively understand memorization-tool terminology.

### 2.8 Export compliance
- [ ] Answer Xcode/App Store Connect's export compliance question: standard use of Apple-provided encryption (HTTPS/TLS for networking, on-device StoreKit/CloudKit encryption) typically qualifies for the standard exemption, requiring no annual self-classification report — confirm current requirements in App Store Connect at submission time, since this is periodically updated and depends on exactly what cryptography (if any) you add beyond Apple's own frameworks.

### 2.9 TestFlight
- [ ] Internal testing build first (your own team/reviewers), covering the full functional + content-integrity + device matrix from document 07.
- [ ] External TestFlight beta with a small group of real, daily Quran readers (ideally including hafiz/memorization-focused users, given the 13-line format's core audience) — this population will catch layout/pagination issues no generic QA process will.
- [ ] Explicitly ask beta testers to verify against their own physical 13-line Mushaf copies for a sample of pages — a uniquely valuable real-world content-accuracy check beyond the automated pipeline in doc 05.

### 2.10 Submission & release
- [ ] Final build tested for crashes/bugs on-device (not just simulator) per §2.1(a).
- [ ] All metadata finalized, no placeholder text/links remaining.
- [ ] Submit for review; monitor App Store Connect status; be ready to respond quickly to any reviewer questions (fast, specific responses shorten re-review cycles).
- [ ] Plan release timing (manual release after approval is recommended for a first launch, so you can coordinate announcement/marketing rather than auto-releasing the moment review completes).

---

## 3. Common Rejection Risks Specific to This App

1. **§1.1.5 (inaccurate/misleading religious text)** — the single highest-stakes rejection risk category for this app specifically. Mitigate entirely through the content-verification pipeline (doc 05 §6) and scholarly sign-off (doc 01 §7) *before* every submission, not after a rejection.
2. **§5.2.2/5.2.3 (unauthorized third-party content)** — have your Quran Foundation / QUL / translator licensing correspondence on hand and ready to share if a reviewer asks; this is a plausible first-review question for any app whose entire value proposition is "we display someone else's copyrighted-adjacent content."
3. **§2.3.1(a) (undocumented premium features)** — write specific, complete review notes for every premium feature; generic "unlocks more content" descriptions invite a request for clarification and a review delay.
4. **§3.1.1 (attempting to unlock content outside IAP)** — make sure there is no code path (even a debug/test one accidentally left in) that unlocks Premium via anything other than StoreKit.
5. **§4.2 (minimum functionality / "just a PDF viewer")** — this is exactly the trap several existing 13-line competitors fall into; your differentiated navigation, audio, search, and offline architecture (not just "we show Quran pages") is what avoids this classification, so make sure the review build actually demonstrates that depth rather than only the reading surface.
6. **Privacy manifest / declaration mismatches** — a genuinely common, avoidable rejection source: make sure every third-party SDK's declared data use in its manifest matches what you declare in the App Privacy questionnaire, and that both match reality.
