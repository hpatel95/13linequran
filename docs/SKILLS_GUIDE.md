# Agent Skills Guide & Activation Matrix

This document defines the specialized agent skills installed in the project (`.agents/skills/`), what each skill governs, and the exact roadmap phases during which each skill must be activated.

---

## 1. Overview of Installed Skills

```
.agents/skills/
├── swiftui-expert/         // Antoine van der Lee (avdlee/swiftui-agent-skill)
│   └── SKILL.md            // Swift 6 concurrency, @Observable state, performance, memory
├── apple-fluid-motion/     // Emil Kowalski (emilkowal.ski / apple-design)
│   └── SKILL.md            // WWDC fluid motion, spring physics, gestures, interruptibility
└── mobile-ios-design/      // Seth Hobson (wshobson/agents - mobile-ios-design)
    └── SKILL.md            // Apple HIG, navigation hierarchy, 44pt touch targets, Dynamic Type
```

| Skill Name | Primary Source | Primary Scope | When to Activate |
| :--- | :--- | :--- | :--- |
| **`swiftui-expert`** | Antoine van der Lee | Swift 6 strict concurrency, `@Observable` view models, view invalidation boundaries, memory downsampling, and eliminating UI hitches. | **Every phase involving Swift code** (Phases 1–11). |
| **`apple-fluid-motion`** | Emil Kowalski | Fluid spring parameters (`damping`/`response`), direct 1:1 finger tracking, interruptible gesture transitions, velocity handoff, and rubber-banding. | **Phases 3, 4, 5** (Reader canvas, zoom, bottom sheet physics, floating player). |
| **`mobile-ios-design`** | Seth Hobson (wshobson) | Apple Human Interface Guidelines (HIG), `NavigationStack` pathing, sheet presentation detents, SF Symbols, and Dynamic Type scaling. | **Phases 1, 4, 6, 9, 10** (Navigation, sheets, design system, accessibility). |

---

## 2. Phase-by-Phase Skill Activation Matrix

To guarantee maximum engineering quality and avoid architectural drift or "vibe-coding regressions", consult this matrix before beginning work on any phase:

```
┌───────────────────────────────────────────────┬──────────────────────┬────────────────────────┐
│ Roadmap Milestone                             │ Required Skills      │ Key Guardrail Focus    │
├───────────────────────────────────────────────┼──────────────────────┼────────────────────────┤
│ Phase 0: Content & Data Pipeline              │ (Data pipeline / DB) │ SHA-256 text integrity │
│ Phase 1: Scaffolding & Design System          │ mobile-ios-design    │ 44pt touch targets,    │
│                                               │ swiftui-expert       │ Sendable color tokens  │
│ Phase 2: Content Engine & GRDB Models         │ swiftui-expert       │ Thread-safe queues,    │
│                                               │                      │ Sendable domain models │
│ Phase 3: 13-Line Canvas & 120Hz Paging        │ apple-fluid-motion   │ 1:1 touch tracking,    │
│                                               │ swiftui-expert       │ 3-page windowed memory │
│ Phase 4: Ayah Highlights & Bottom Sheet       │ apple-fluid-motion   │ Sheet detents physics, │
│                                               │ mobile-ios-design    │ 22% gold highlight box │
│ Phase 5: Audio Recitation & Mini-Player       │ swiftui-expert       │ AVQueuePlayer actor,   │
│                                               │ apple-fluid-motion   │ Floating player spring │
│ Phase 6: Index Navigation & FTS5 Search       │ mobile-ios-design    │ NavigationStack paths, │
│                                               │ swiftui-expert       │ <15ms debounced FTS5   │
│ Phase 7: Bookmarks & Last-Read History        │ swiftui-expert       │ WAL mode SQLite actor  │
│ Phase 8: Offline Download Manager             │ swiftui-expert       │ Background URLSession  │
│ Phase 9: StoreKit 2 Supporter Subscriptions   │ mobile-ios-design    │ HIG-compliant paywall, │
│                                               │ swiftui-expert       │ Transaction.updates    │
│ Phase 10: Settings, Onboarding & A11y         │ mobile-ios-design    │ Dynamic Type, VoiceOver│
│ Phase 11: End-to-End QA & Trace Profiling     │ swiftui-expert       │ Time Profiler traces,  │
│                                               │ Appflight pre-audit  │ Zero animation hitches │
│ Phase 12: App Store Submission                │ Appflight pre-audit  │ Clean Guideline report │
└───────────────────────────────────────────────┴──────────────────────┴────────────────────────┘
```

---

## 3. How to Activate Skills in Prompts

When starting any phase or issuing instructions to an AI coding agent, explicitly declare the skills in the prompt's `Context & Reference Documents` header (as standardized in [`docs/VIBE_CODING_GUIDELINES.md`](VIBE_CODING_GUIDELINES.md)):

```markdown
Role: Senior iOS Architect / Motion Specialist
Phase: Phase 4: Ayah Bounding Box Overlays & Translation Bottom Sheet
Active Skills to Follow:
- `.agents/skills/apple-fluid-motion/SKILL.md` (for sheet drag physics & spring parameters)
- `.agents/skills/mobile-ios-design/SKILL.md` (for presentation detents & 44pt touch targets)
- `.agents/skills/swiftui-expert/SKILL.md` (for @Observable invalidation boundaries)

Task: [Feature description]
...
```

---

## 4. Skill Invariant Rules (Quick Summary)

1. **Never use legacy `@ObservedObject` or `@Published`**: Use `@Observable` exclusively (`swiftui-expert`).
2. **Never hardcode animation durations on touchable items**: Use `.spring(response:dampingFraction:)` (`apple-fluid-motion`).
3. **Never place interactive buttons smaller than 44pt**: Use `.frame(minWidth: 44, minHeight: 44)` (`mobile-ios-design`).
4. **Always downsample 1600x2400 page tiles**: Load tiles scaled to the physical screen points $\times$ display scale to prevent GPU memory spikes (`swiftui-expert`).
