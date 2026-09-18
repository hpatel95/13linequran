# Building an iOS App Without a Mac — Strategy Guide

## The Short Answer

**Not a hard blocker.** You can absolutely build, test, and ship a native Swift/SwiftUI app to the App Store without ever owning a Mac. Thousands of indie devs do it. But you need to choose the right workflow, because it genuinely affects how you'll work day to day — especially during the most iteration-heavy phases of this project.

---

## The Actual Constraint (Being Precise)

Xcode only runs on macOS, and Apple requires Xcode's toolchain for two specific things that **nothing else can substitute for**:

1. **Compiling and running the app in the iOS Simulator**
2. **Code-signing and archiving the final build for TestFlight or the App Store**

This is true regardless of framework — Flutter and React Native apps also require Xcode and macOS for the final iOS build and signing step. They just let you write the *code* on other platforms until that point. Since this app has no Android target, switching frameworks to "avoid needing a Mac" wouldn't actually save anything — you'd hit the exact same wall either way. **This confirms native Swift/SwiftUI is still the right call (ADR-001); this is a workflow problem to solve, not a reason to reconsider the stack.**

**What does NOT need a Mac:** Writing the actual Swift/SwiftUI source code. It's plain text — Antigravity, Claude Code, Cursor, VS Code — anything can read, write, and reason about `.swift` files on Windows all day. The Mac requirement is specifically about *compiling, previewing, and shipping*, not about *writing*.

---

## What Exactly Requires macOS? (Task Breakdown)

| Task | Needs macOS? | Can do on Windows? |
| :--- | :--- | :--- |
| Writing Swift source files | ❌ No | ✅ Yes — any text editor / AI agent |
| Creating the Xcode project (`.xcodeproj`) | ✅ Yes | ❌ No |
| Adding SPM dependencies (GRDB.swift) | ✅ Yes | ❌ No |
| Compiling the app | ✅ Yes | ❌ No |
| Running iOS Simulator | ✅ Yes | ❌ No |
| SwiftUI Previews (live canvas) | ✅ Yes | ❌ No |
| Testing on a real iPhone (via USB) | ✅ Yes | ❌ No (but TestFlight works) |
| Archiving & uploading to App Store Connect | ✅ Yes | ❌ No |
| Building the SQLite database | ❌ No | ✅ Yes — Python/sqlite3 |
| Processing page tile images | ❌ No | ✅ Yes — ImageMagick/Pillow |
| Writing documentation & planning | ❌ No | ✅ Yes |

**Bottom line**: ~60% of our project work (code authoring, database building, image processing, content pipeline) can be done right here on your Windows machine. The other ~40% (compile, test, ship) needs a Mac somewhere.

---

## All Options Evaluated

### Option A: Buy a Mac Mini (⭐ Best Long-Term ROI)

| Device | Approx. Price | Performance |
| :--- | :--- | :--- |
| Mac Mini M2 (refurbished/clearance) | ~$350–499 | Excellent for Xcode |
| Mac Mini M4 (clearance) | ~$499–599 | Excellent |
| Mac Mini M6 (current) | ~$899 | Overkill-good |

**Pros:**
- Full local Xcode, Simulator, and instant SwiftUI Previews — the fastest possible iteration loop
- One-time cost you keep for every future update and future iOS projects
- Zero latency, zero dependency on internet quality
- Pays for itself within 3–4 months vs. cloud rental

**Cons:**
- Upfront capital cost

> **💡 Tip**: It sits on your desk next to your Windows PC. You can remote-desktop into it from Windows using free tools (Apple Screen Sharing, Screens app). You don't even need a separate monitor — just remote in.

---

### Option B: Cloud Mac Rental (⭐ Best If You Don't Want Upfront Cost)

Rent a full macOS desktop in the cloud. You access it via Remote Desktop (VNC/RDP) from your Windows PC, and it has Xcode, Simulator, everything.

| Provider | Pricing | Hardware | Admin Access | Best For |
| :--- | :--- | :--- | :--- | :--- |
| **MacRent** | ~$15/day, ~$119/month | M4 Mac Mini | ✅ Full | Indie devs, project sprints |
| **MacinCloud** (Dedicated) | ~$125/month | M2/M4 Mac Mini | ✅ Full | Longer-term dev |
| **MacinCloud** (Pay-as-you-go) | ~$1/hour, ~$30/month prepaid | Shared Mac | ❌ Managed | Occasional builds |
| **MyRemoteMac** | ~$100–150/month | M-series | ✅ Full | Full-time dev |
| **MacStadium** | Quote-based (enterprise) | M-series fleet | ✅ Full | Teams, CI/CD fleets |
| **AWS EC2 Mac** | ~$650+/month (24h min lease) | M-series | ✅ Full | Already-on-AWS teams |

> **💡 Best strategy for your budget**: Use a dedicated cloud Mac only during active development sprints. You don't need it running 24/7. Rent monthly when you're coding Phases 1–11, cancel when you're in planning/content-prep mode.

**How it works in practice:**
1. You write Swift code on Windows (using Antigravity / VS Code / any editor)
2. You push code to a Git repository (GitHub)
3. You remote-desktop into your cloud Mac
4. You open Xcode, pull the code, compile, test in Simulator
5. When satisfied, archive and upload to App Store Connect

> **⚠️ Honest trade-off**: Remote-desktop latency makes tight, pixel-level iteration noticeably more frustrating than local. For general SwiftUI work it's fine, but for Phase 4–5 (the Arabic Mushaf renderer — pixel-level bounding box alignment), you will feel the lag. A local Mac is significantly smoother for that specific phase.

---

### Option C: CI/CD Build Service Only (Cheapest, but least interactive)

You never touch a Mac at all. You push code to GitHub, and a cloud service compiles it for you automatically.

| Service | Free Tier | Paid Rate | What It Does |
| :--- | :--- | :--- | :--- |
| **Codemagic** | 500 free build-minutes/month (M2) | ~$0.095/min after | Compiles, signs, deploys to TestFlight |
| **GitHub Actions** (macOS runner) | 2,000 min/month (free for public repos) | ~$0.08/min for private | Same, but more DIY config |
| **Xcode Cloud** | 25 compute-hours/month free (bundled with $99 Developer Program) | Extra hours billed | Apple's own CI, tightly integrated |

> **⚠️ The catch**: CI/CD services only compile and test. You **cannot** interactively use Xcode, run the Simulator live, or debug visually. You write code blind on Windows, push, wait for the build result, read logs if it fails, fix, push again. This is painful for UI development — you'd only see your UI after a build-and-upload cycle, installed on your own iPhone via TestFlight.

**Verdict**: CI/CD alone is viable for experienced iOS devs who can write SwiftUI from memory. For a vibe-coding workflow where you need visual feedback and Simulator testing, it's too slow and frustrating as your *only* Mac access. However, it's **excellent as a complement** to Option A or B — use it for automated testing and App Store submission.

---

### Option D: Swift Playgrounds on iPad

If you have an iPad, you can code a real SwiftUI app and submit it directly to App Store Connect, without a Mac.

**Verdict**: Ideal for small, simple projects. Too limited for an ambitious app like this — no GRDB SPM dependency support, limited debugging, no Simulator device matrix testing. Not recommended for this project.

---

### Option E: Hackintosh / macOS VM on Non-Apple Hardware

Running macOS on non-Apple hardware (VMware, VirtualBox, or bare metal).

**Verdict**: Against Apple's EULA, flagged as unreliable by multiple sources, and a legal risk for a project intended for commercial App Store submission. **Not recommended.** Don't risk your $99/year developer account and your app's future over saving a few hundred dollars on hardware.

---

### Option F: React Native / Expo (Framework Switch to Avoid Mac?)

Some guides suggest switching to React Native + Expo to develop and test on Windows using the Expo Go app on your physical iPhone, then cloud-build for App Store submission via EAS Build. This lets you test UI on your real phone without a Simulator.

**Why we are NOT doing this for this project:**
1. **ADR-001 stands**: We chose native Swift/SwiftUI for specific, well-documented technical reasons — direct AVFoundation control for lock-screen audio, StoreKit 2 native views, RTL layout fidelity, and zero bridge overhead during 120Hz Mushaf paging.
2. **The Mushaf renderer is the core product**: The hybrid tile engine (AVIF tiles + SQLite bounding boxes + SwiftUI coordinate overlays) requires pixel-precise control over image rendering, gesture hit-testing, and GPU tinting. React Native's bridge adds indirection exactly where we need maximum precision.
3. **AI code generation for Swift is strong enough**: Current LLMs generate excellent Swift/SwiftUI. The TypeScript advantage is real but marginal for this project's scope.
4. **You still need a Mac anyway**: Even with Expo/React Native, the final build and App Store submission still require Xcode on macOS. The framework switch doesn't eliminate the constraint — it only delays hitting it.

> **📝 Note**: If this were a standard CRUD/social/SaaS mobile app, Expo/React Native would be a strong choice. For a pixel-precise Arabic calligraphy renderer with background audio and native subscriptions, native Swift is the right call.

---

## The Critical Iteration Concern: Phase 4–5

The single riskiest, most iteration-heavy part of this entire build is **Phase 4–5** (the Arabic Mushaf renderer and ayah bounding box overlay system). This is the part that needs constant "does this pixel-level spacing look right?" checking:

- Are the bounding boxes aligned exactly over each ayah?
- Does the golden highlight tint render correctly over the calligraphy?
- Does the coordinate mapping hold across iPhone SE → iPhone 16 Pro Max?
- Does the tap gesture resolve to the correct ayah in every edge case?

**This is where having low-latency macOS access matters most.** During Phase 4–5, you need the fastest possible compile → preview → adjust loop. A cloud Mac works but is noticeably slower than local. Budget accordingly: if you're going to splurge on a Mac Mini or upgrade to a dedicated cloud Mac plan for any single period, do it during Phase 4–5.

---

## 🏆 Recommended Hybrid Workflow

### Phase 0 (Now → Content Prep): 100% Windows — Free
Everything we need to do is doable on Windows:
- Build `quran_content.sqlite` with Python
- Process 849 page tile images
- Write all Swift source code as `.swift` files
- Design the database schema
- Draft all models, services, and views

### Phase 1–11 (Active Dev): Cloud Mac (~$120/month) OR Mac Mini + Windows

```
┌─────────────────────┐         ┌───────────────────────┐
│   YOUR WINDOWS PC   │         │  MAC (Cloud or Local) │
│                     │  git    │                       │
│  Write Swift code   │───push──►  Pull in Xcode       │
│  with AI agents     │         │  Compile & test       │
│  (Antigravity)      │◄──fix───│  Run Simulator        │
│                     │         │  Debug & iterate      │
│  Build SQLite DB    │         │  Archive & upload     │
│  Process images     │         │                       │
└─────────────────────┘         └───────────────────────┘
```

**Daily workflow:**
1. On Windows: AI agent writes/edits Swift files → push to GitHub
2. On Mac (local or remote): Open Xcode → pull → build → test in Simulator
3. If build fails: read errors → back to Windows → AI fixes → push → repeat
4. If build succeeds: test the feature visually → move to next task

### Phase 12 (Submission): Mac + Xcode Cloud
- Archive and upload via Xcode on your Mac (local or cloud)
- Set up **Xcode Cloud** (free 25 hours/month with Developer Program) for automated archive → TestFlight → App Store submission pipeline
- **Pre-submission audit**: Scan the compiled `.ipa` with [Appflight](https://appflight.co/) to catch App Store rejection risks, missing required reason APIs, or guideline non-compliance before Apple reviewers inspect it
- This removes manual signing/upload from your critical path entirely and prevents unnecessary rejection cycles

---

## Cost Estimates

### Path A: Cloud Mac Rental (~4 months active dev)

| Item | Cost | When |
| :--- | :--- | :--- |
| Apple Developer Program | $99/year | Before Phase 12 |
| Cloud Mac rental (~4 months) | ~$480 | Phases 1–12 |
| **Total to ship V1** | **~$579** | |

### Path B: Buy Mac Mini (one-time)

| Item | Cost | When |
| :--- | :--- | :--- |
| Apple Developer Program | $99/year | Before Phase 12 |
| Mac Mini M2 refurbished | ~$400 (one-time) | Before Phase 1 |
| **Total to ship V1** | **~$499** | |
| Future updates / V1.1 / V2 | $0 additional hardware | Ongoing |

> **💡 Cost reduction tips (either path):**
> - Use MacinCloud pay-as-you-go ($1/hour) during early phases when builds are quick
> - Switch to dedicated monthly only when doing heavy UI work (Phases 3–5, 10)
> - Use Codemagic free tier (500 min/month) or Xcode Cloud (25 hrs/month free) for automated CI testing
> - Delay the $99 Developer Program fee until you're actually ready for TestFlight (Phase 11–12)

---

## What Changes in Our Architecture?

**Nothing architecturally changes.** The app is still 100% native Swift/SwiftUI. The only practical adjustments:

1. **STACK.md** — Add note that development uses a Git-based workflow with macOS compilation (cloud or local)
2. **VIBE_CODING_GUIDELINES.md** — Workflow becomes: write on Windows → push to Git → compile on Mac
3. **TODO.md** — Add tasks: "Initialize Git repository" and "Set up Mac access (cloud or local)"

---

## Immediate Action Plan

Before spending any money on a Mac, **maximize what we can do for free on Windows right now**:

1. ✅ Initialize a Git repository for the project
2. ✅ Build the Phase 0 content pipeline (SQLite database, page tiles)
3. ✅ Write all Swift source files for Phase 1 (Design System, App shell)
4. ✅ Only acquire Mac access when we have code ready to compile

This way, when you first open Xcode (local or cloud), you'll have a full Phase 1 codebase ready to build — not starting from scratch.

---

## Résumé (FR)

Ce n'est pas bloquant — mais il y a une réalité Apple à connaître : **Xcode (le build final iOS et la soumission App Store) ne tourne que sur macOS**. En revanche, tout le reste du développement (écriture du code Swift, base SQLite, traitement d'images) peut se faire sur Windows.

**Recommandation** : Commencer tout le travail faisable sur Windows maintenant (Phase 0, écriture du code), puis acquérir un accès Mac (cloud ~$120/mois ou Mac Mini ~$400 one-shot) quand le code est prêt à compiler. Coût total estimé pour publier V1 : **~$500–580**.
