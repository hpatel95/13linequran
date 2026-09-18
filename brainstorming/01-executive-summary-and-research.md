# 13-Line Quran App — Executive Summary & Research Findings
*Research current as of September 13, 2026. All facts below are sourced; recommendations are clearly marked as such.*

---

## 1. Executive Recommendation

Build it. There is a genuine gap: **every existing 13-line Mushaf app on the App Store is a utility, not a product.** They are PDF-scan viewers or ligature-image renderers built by solo developers, with dated UI, unclear content provenance, and (based on their App Store listings) little to no privacy disclosure. Nobody has applied real design craft, a modern offline-first architecture, or a trustworthy content/licensing story to this specific format. That is your opening.

The recommended path in one paragraph: **native SwiftUI app, Quran Foundation (Quran.com) API as the primary licensed content backbone for Arabic text/translations/tafsir/audio, a custom-typeset 13-line layout (not a scanned reproduction of any single publisher's printed edition) verified against Tanzil's CC‑BY corpus, local-first storage with no mandatory account, StoreKit 2 for a single well-scoped subscription, and a ruthlessly small V1** — one Mushaf layout, one script, a handful of translations, a handful of reciters, done beautifully — rather than a broad feature set done adequately. Everything below explains why.

**Before you write a line of code**, two things need action outside of engineering:
1. **Written confirmation from Quran Foundation and from Tarteel/QUL** that your specific commercial, subscription-funded, offline-heavy use case is covered by their terms (details in document 05). This is an email, not a blocker, but it must happen before launch.
2. **A qualified Islamic scholar/reviewer** to sign off on the Arabic text, translation selection, and any tafsir before release, and periodically thereafter. This is a religious-accuracy requirement independent of copyright law, and App Store guideline 1.1.5 (below) makes textual accuracy an App Review issue too, not just a scholarly one.

---

## 2. Competitive Analysis

### 2.1 Existing 13-line Mushaf apps (direct competitors)

| App | What it actually is | Gap it leaves open |
|---|---|---|
| **Quran 13 Line** (Qamar Apps) | Long-running, image/PDF-based, functional but visually dated; no stated privacy practices on its App Store listing | No design investment; no visible content sourcing |
| **Dual Page 13 Line Quran** | New entrant (2026), true two-page spread, tajweed color-coding | Very new, unrated, single-feature focus |
| **iQra: 13 Line Qur'an** | Explicitly "a simple PDF scan… No frills" | Literally a PDF viewer — the low bar you need to clear |
| **Quran – Colour Coded Tajweed** | Deliberately minimal, image-based, no audio by design | Solo-developer scope; not a platform |
| **13 Line Quran Indopak Script** | Tajweed color-coding + bundled Hussary audio | Bundling third-party MP3s with unclear rights |
| **Mushaf Mecca (مصحف مكة)** | The most feature-rich of the group — word-level coordinates, voice recording, multiple mushaf variants including a South-Africa 13-line edition | Closest thing to a "serious" competitor; still not premium-designed |

**Takeaway:** this is a real sub-genre (large, mostly South Asian/South African/diaspora audience, memorization-focused), but no one has shipped it with modern iOS craftsmanship, a coherent subscription business, or transparent licensing. That's a defensible wedge.

### 2.2 The broader premium Quran app market

Independent of the 13-line niche, the apps people actually hold up as "best in class" today:

- **Quran.com / Quran Foundation app** — a waqf (endowment) run by the nonprofit Quran.Foundation, explicitly positioned to keep the Quran free and without commercial interest. Free, ad-free, the reference/gold-standard reading experience. You will be compared to this by every reviewer, and it sets the bar for "trustworthy."
- **Ayat** — built by King Saud University; free, multiple tafsirs, strong offline downloads, but reviewers consistently describe the interface as dated.
- **Tarteel** — the standout for AI-assisted memorization (live mistake detection while reciting), priced around $12.99/month with a $156/year family plan; explicitly *not* trying to be a general reading app.
- **Muslim Pro** — the "everything app" (100M+ downloads), $12.99/month or $34.99/year for premium, but repeatedly flagged in independent write-ups for an ad-supported free tier and a **2020 reporting that it shared location data via the "X-Mode" data broker** — a real reputational scar in this exact market that a privacy-first competitor can use as a point of differentiation.

*A note on sources:* several of the "best Quran app" roundups used in this research (Quran Gate, RecitID, FivePrayer's blog, "Dr Ali Rajabi") read as SEO content-marketing sites, and in at least one case (FivePrayer) the site's own product is ranked #1 in every comparison it publishes — a conflict of interest worth flagging. Treat their rankings as directional color, not gospel, and re-verify current App Store listings/pricing yourself before finalizing positioning.

### 2.3 What this means for your product

1. **Don't compete with Quran.com on breadth or price (free).** Compete on *this specific reading format executed with obsessive craft* — the thing none of them have done.
2. **Don't compete with Tarteel on AI/memorization tooling** — that's a different, R&D-heavy product. You can add a *simple* streak/khatm tracker without trying to out-AI Tarteel.
3. **Explicitly out-privacy Muslim Pro.** No ads, no third-party ad SDKs, no login required to read, clear plain-language privacy copy. This is cheap to do and meaningfully differentiating in this specific category.
4. **Price like a focused premium utility, not an "everything app."** Given strong free incumbents exist, plan V1 pricing modestly (see document 02 for specifics) rather than anchoring to Muslim Pro/Tarteel's $12.99/month.

---

## 3. Verified Apple Platform Facts

Pulled directly from Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (last updated June 8, 2026). These are facts, not interpretation:

- **§1.1.5 — Inflammatory religious commentary or inaccurate/misleading quotations of religious texts** is an explicit rejection ground. Textual accuracy isn't just a scholarly nicety here — it's a review-risk item.
- **§5.1.1(v) — Account Sign-In:** *"If your app doesn't include significant account-based features, let people use it without a login… If your app supports account creation, you must also offer account deletion within the app."* This directly supports a local-first, login-optional design.
- **§4.8 — Login Services (Sign in with Apple):** only triggers if you use a **third-party social login** (Google, Facebook, etc.) for the primary account. If you use no login, or only Apple's own account systems (e.g., CloudKit tied silently to the user's Apple ID, with no explicit "sign in" flow), this requirement does not apply to you.
- **§3.1.2 — Subscriptions:** must last ≥7 days, must provide ongoing value, and permissible categories explicitly include *"access to large collections of, or continually updated, media content"* — which squarely covers translations/tafsir/reciter libraries as a subscription unlock.
- **§2.3.1(a) — No hidden/undocumented features**; all IAP and premium gating must be clearly described in review notes.
- **§5.2.2/5.2.3 — Third-party content and audio/video:** you must be "specifically permitted" under the source's terms to use, display, monetize, or bundle its content — and must provide authorization on request. This is precisely why document 05 (content licensing) matters as much as it does.
- **Privacy manifests (`PrivacyInfo.xcprivacy`):** mandatory since May 1, 2024 for any app using a "required reason API" (this includes common things like `UserDefaults`, file timestamps, disk space checks) — still enforced in 2026. Any third-party SDK you add (crash reporting, analytics, IAP helper libraries) must ship its own privacy manifest or App Store Connect will flag/reject the build.
- **StoreKit 1 is deprecated** (as of WWDC 2024); **StoreKit 2** is the current Swift-native, async/await API, and its `SubscriptionStoreView` can render a full native paywall UI with minimal custom code — directly relevant to vibe-coding reliability, since less custom subscription code means fewer places for an AI agent to introduce bugs.

---

## 4. Verified Quran Content & Licensing Facts

This is the single most important research finding for this project, so it gets its own full document (05). Summary of the load-bearing facts, each independently verified:

- **Tanzil.net Arabic Quran text** is distributed under a Creative Commons Attribution 3.0 license permitting copying and distribution, but explicitly prohibits altering the text, and requires source attribution linked back to tanzil.net. This is commercially usable **for the Arabic text itself**, with attribution.
- **Tanzil's translation corpus is a different license: non-commercial only.** Multiple independent packagings of the Tanzil translation data confirm the translations are *"for non-commercial purposes only"* and require the translator/publisher's explicit permission for anything else. **You cannot use Tanzil's bundled translations in a paid/subscription app without separately clearing rights with each translator/publisher.**
- **Quran Foundation (the nonprofit behind Quran.com) explicitly permits commercial and freemium use of its API content** — Arabic text, translations, tafsir, audio — provided the content is displayed only as part of the app's end-user experience and is not resold, sublicensed, or redistributed as raw data. This is the most important single finding in this research: it gives you a legitimately licensed path to commercial use of premium-feeling, peer-reviewed content.
- Critically, ordinary caching of Quran Foundation content is capped at one week unless you use their purpose-built Content Sync APIs, which are explicitly designed for offline mirrors and require a re-sync at least every 7 days. **This is your offline-first architecture's legal backbone** — build around Content Sync, not ad-hoc caching.
- **KFGQPC (King Fahd Quran Printing Complex) fonts** — the standard Uthmani typeface most apps use — are free to embed/distribute in an app, but cannot be sold, modified, altered, reverse engineered, or have their source code extracted. Fine for direct embedding; not fine for repackaging as a font product.
- **The "13-line Mushaf" is not a single standardized government edition** the way the King Fahd Complex's 15-line Madinah Mushaf is. It's a *layout convention*, historically typeset by multiple independent publishers (Taj Company Karachi, Waterval Islamic Institute, Jamiatul Ulama South Africa, and others) in Indo-Pak/Persian Naskh script. There is no single universal rights-holder — which is good news (no one publisher can claim the whole genre) and bad news (you can't just point to "the" official 13-line license).
- **Tarteel AI's Quranic Universal Library (QUL)** hosts a structured, line-by-line **"Indopak 13 Lines – Taj Company" layout dataset** — page/line/word-indexed data designed exactly for this rendering problem, alongside compatible IndoPak scripts and fonts. This is the most directly useful dataset found for your specific format. However, a real developer asked Tarteel/QUL's own team, in a public GitHub issue, for clarity on commercial licensing for a paid Islamic app — and did not receive a published blanket answer. **Treat QUL as your primary technical resource, but get written commercial confirmation before shipping**, and lean on your own freshly-typeset pagination (see document 05) as a legal hedge.
- **Recitation audio licensing is the murkiest area.** Community-documented licenses for everyayah.com/versebyversequran.com audio are **CC BY-NC (non-commercial)**; QuranicAudio.com publishes no clear license at all. **The safe commercial path is Quran Foundation's audio API**, which is covered by the same commercial-use permission described above, rather than scraping community MP3 mirrors.

---

## 5. Verified Privacy & Regulatory Facts

- **Religious belief/practice is GDPR "special category data"** under Article 9 — it requires both a standard Article 6 lawful basis and a separate Article 9(2) condition (most realistically, explicit consent) before any processing is lawful, and mishandling it sits at the top of GDPR's fine scale. A Quran app's reading history, bookmarks, and notes are, by their nature, data revealing religious practice **the moment they're tied to an identifiable person on a server you control.**
- This is a strong architectural argument for **local-first storage and, if you add sync, Apple's CloudKit private database** rather than a custom backend — because CloudKit private-database data is end-to-end scoped to the user's own iCloud account and never becomes visible to your servers, meaningfully changing your GDPR controller/processor exposure.
- **Privacy-conscious analytics/crash reporting is a mature, off-the-shelf choice today**, not a compromise: TelemetryDeck (anonymous, Swift-native, no ATT prompt needed) plus Sentry (device/stack-trace only, on-device symbolication) is a documented, real-world pattern specifically chosen by privacy-conscious indie iOS teams over Firebase/Crashlytics, which pulls in Google's broader data-collection surface and a longer App Store privacy label.

---

## 6. Pricing Benchmarks (verified, for calibration only)

| App | Model |
|---|---|
| Muslim Pro | $12.99/mo or $34.99/yr premium (ad-supported free tier) |
| Tarteel | ~$12.99/mo premium; $156/yr family plan (5 users) |
| Quran.com, Ayat | Free, no premium tier at all (nonprofit-funded) |

**Recommendation (not a verified fact — a judgment call, detailed in document 02):** price meaningfully below the "AI/everything app" tier. A focused reading app with real free-tier value should land around $2.99–$4.99/month or $19.99–$29.99/year, with a modest lifetime option, reflecting that your core content (Arabic Mushaf + one translation) should remain free, and premium monetizes convenience (more translations/reciters, offline packs, advanced study tools) — not the Quran itself.

---

## 7. Items That Need a Named Human Professional (not just more research)

Flagging explicitly, as requested:

1. **An intellectual-property/licensing attorney**, before launch, to: (a) review and countersign the Quran Foundation developer terms against your specific commercial subscription model, (b) get written commercial clearance from Tarteel/QUL for the 13-line layout dataset, (c) clear rights for any specific modern translation you want beyond public-domain options (Yusuf Ali, Pickthall), (d) confirm your approach to the 13-line *layout itself* doesn't infringe any specific publisher's typeset compilation.
2. **A qualified Islamic scholar / Quran-sciences reviewer** (ideally with tajweed/qira'at credentials), on an ongoing basis, to sign off on: text accuracy against your chosen source, translation selection and any editorial framing, tafsir selection, and the sajdah/juz/hizb/manzil metadata before every release that touches content.
3. **A privacy/data-protection counsel**, if and when you take on EU users at scale, to formalize the Article 9 lawful-basis documentation and decide whether a DPIA is warranted (likely only if you add server-side accounts/sync beyond CloudKit).
4. **An App Store submission specialist / experienced iOS shipping developer** (could be you, once you've shipped a few TestFlight builds) to review the final build against the guideline citations above before the first submission — first-time religious-content apps draw extra scrutiny under §1.1.5.

---

*Continue to `02-product-spec-and-roadmap.md` for the full feature specification and V1–V2 scope.*
