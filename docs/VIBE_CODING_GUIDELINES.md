# AI Vibe-Coding Operational Protocol & Guidelines

This document establishes the operational rules, prompt protocols, and architectural guardrails for building the 13-Line Quran application using AI coding agents (such as Antigravity, Claude Code, Cursor, or similar tools).

---

## 1. Core Philosophy: Disciplined Incrementalism

"Vibe-coding" is not blindly asking an AI to "build me a Quran app." Large, ambiguous prompts inevitably trigger:
* Context window degradation and loss of architectural coherence.
* Accidental rewrites and deletion of working code.
* Hallucinated API signatures and deprecated frameworks.
* The catastrophic risk of an AI agent programmatically altering sacred Arabic text or diacritics.

**The Golden Rule**: Build the application in **small, self-contained, test-verified modules**. One phase, one feature, one verification cycle at a time.

---

## 2. The 8 Inviolable Rules for AI Coding Agents

### Rule 1: Never Programmatically Modify Quranic Arabic Text
The Arabic text in `quran_content.sqlite` is sacred and immutable.
* **Prohibited**: Never write scripts or AI functions that "clean up," "strip," "normalize," or format the Arabic text in the database.
* **Allowed**: Diacritic stripping is permitted **only in temporary in-memory search tokens** for fuzzy matching in search queries, never on the stored canonical text.

### Rule 2: Inspect Before Editing
An AI agent must **always inspect existing files and models** before proposing changes. It must never guess file names, import paths, or model properties.

### Rule 3: Strict File Boundaries
Every prompt must specify:
1. **Files to Create**: New files the agent is authorized to generate.
2. **Files to Modify**: Existing files the agent is allowed to edit.
3. **Files Strictly Forbidden from Modification**: Existing working files that the agent must not touch.

### Rule 4: No Premature Refactoring
The AI agent must never refactor unrelated files "for cleanliness" while implementing a feature. Unprompted refactoring is the leading cause of regressions in AI-generated codebases.

### Rule 5: Pure Native Apple Frameworks Only
Do not import third-party libraries (e.g., CocoaPods, npm, external UI components) unless explicitly specified in `docs/STACK.md` (only `GRDB.swift` is approved).

### Rule 6: Zero Compiler Warnings under Strict Concurrency
All code must compile under **Swift 6 Strict Concurrency Checking** (`-strict-concurrency=complete`) with **zero warnings and zero errors**. All shared services must be proper `actor` instances or conform to `Sendable`.

### Rule 7: Mandatory Verification After Every Change
Every prompt execution must conclude with an active verification step:
* Running unit tests (`swift test` or Xcode Test scheme).
* Checking build logs for compiler warnings.
* Verifying preview canvas rendering.

### Rule 8: Update Documentation on Completion
When a milestone task is completed, the agent must update `docs/TODO.md` by checking off the relevant item before ending the turn.

---

## 3. The 5-Step Agent Execution Workflow

```
┌────────────────────────────────────────────────────────┐
│  1. INSPECT   → Read target files & check existing APIs│
├────────────────────────────────────────────────────────┤
│  2. PROPOSE   → Outline exact file changes & methods   │
├────────────────────────────────────────────────────────┤
│  3. EXECUTE   → Make single-file, surgical code edits  │
├────────────────────────────────────────────────────────┤
│  4. VERIFY    → Compile project & run unit tests       │
├────────────────────────────────────────────────────────┤
│  5. COMMIT    → Check off docs/TODO.md & commit to git │
└────────────────────────────────────────────────────────┘
```

---

## 4. Standard Prompt Template

When instructing an AI coding agent to implement any phase or feature, use this exact prompt structure:

```markdown
Role: [e.g., Senior iOS Architect / AVFoundation Specialist / SwiftUI Engineer]
Phase: [e.g., Phase 5: Audio Playback Engine]
Task: [Concise summary of the feature to build]

Context & Reference Documents:
- Review `docs/STACK.md` for technology stack and architectural patterns.
- Review `docs/DECISIONS.md` for relevant architectural decisions.
- Existing codebase has completed through Phase [N-1].

Authorized Files to Create:
- `Domain/Audio/AudioPlaybackService.swift`
- `Domain/Audio/NowPlayingManager.swift`
- `Features/Reader/MiniPlayerView.swift`

Authorized Files to Modify:
- `Features/Reader/MushafPageView.swift` (to attach playback observer only)

STRICTLY FORBIDDEN from Touching:
- `Domain/Database/QuranDatabaseService.swift`
- `Domain/Models/QuranModels.swift`
- `DesignSystem/*`

Technical Requirements:
1. [Requirement 1]
2. [Requirement 2]
3. [Requirement 3]

Constraints & Architectural Rules:
- Swift 6 Sendable compliance.
- No third-party audio packages; use AVFoundation native APIs.
- Background audio session category `.playback`.

Acceptance Criteria & Verification:
1. Code compiles with zero warnings.
2. Unit tests in `Tests/AudioPlaybackTests.swift` pass 100%.
3. Update `docs/TODO.md` upon successful verification.
```

---

## 5. Guardrails for Sacred Quran Content

To ensure the sacred text remains 100% accurate throughout the life of the project:

1. **Golden Master Fixture**: A baseline text file containing the SHA-256 hash of the verified Arabic corpus is committed to version control at `Resources/Database/quran_content.sqlite.sha256`.
2. **Pre-Build Verification Script**: An automated script runs before every Xcode build:
   ```bash
   shasum -a 256 -c Resources/Database/quran_content.sqlite.sha256
   ```
   If the hash does not match identically, the build immediately aborts with an error.
3. **Automated Ayah Count Assertion**: Unit tests in `QuranIntegrityTests.swift` assert the exact canonical verse counts for all 114 Surahs before any TestFlight or App Store archive can be generated.

---

## 6. Error Recovery Protocol (When AI Hallucinates or Breaks Code)

If an AI coding agent produces broken code, introduces compiler errors, or hallucinates an API:

1. **Do Not Layer Fixes on Broken Code**:
   * Stop immediately.
   * Revert the working tree to the last clean git commit (`git checkout .` or `git reset --hard HEAD`).
2. **Diagnose the Failure**:
   * Identify why the agent hallucinated (was the prompt too broad? was context missing? was an unauthorized file touched?).
3. **Re-Prompt with Narrower Scope**:
   * Break the failing task into two smaller sub-tasks.
   * Provide the exact Swift API signature or Apple documentation link directly in the prompt.
4. **Re-Verify**:
   * Compile and run unit tests to confirm stability before proceeding to the next feature.

---

## 7. Pre-Submission Rejection Audit (AI Code Safety Gate)

AI-assisted ("vibe-coded") iOS applications are particularly susceptible to subtle App Store rejection triggers—such as unreferenced background capabilities, hallucinated entitlements, incomplete StoreKit disclosure terms, or missing Apple Privacy Manifest declarations (`PrivacyInfo.xcprivacy`).

Before submitting any release build to App Store Review:
1. **Archive the `.ipa`** (via Xcode Cloud or local build).
2. **Scan Binary with [Appflight](https://appflight.co/)**:
   * Run the compiled `.ipa` through Appflight's static audit engine.
   * Address all flagged Apple Review Guideline risks (Guidelines 2.1, 2.3, 3.1.2, 5.1.1, 5.1.2) before opening App Store Connect review.
3. **Record Findings**: Document clean audit pass in release checklist before setting build live.
