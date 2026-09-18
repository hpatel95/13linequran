---
name: swiftui-expert
description: >-
  Expert guidelines for writing, reviewing, and optimizing modern SwiftUI code for iOS 17+ and Swift 6.
  Use when writing SwiftUI views, managing @Observable state and data flow, optimizing view invalidation
  boundaries, debugging animation hitches, handling image downsampling, or refactoring legacy state patterns.
---

# SwiftUI Expert Skill
*Adapted from Antoine van der Lee (avdlee/swiftui-agent-skill)*

## 1. Operating Rules & Core Principles

- **View Invalidation Boundaries**: Treat each `View` struct as an invalidation boundary. Give it only the data it reads, and keep frequently changing dependencies close to the smallest affected subtree.
- **Modern Observation**: Use Apple's `@Observable` macro exclusively for view models. Do not use legacy `ObservableObject`, `@Published`, or `ObservedObject` in iOS 17+.
- **Pure SwiftUI First**: Prefer native declarative SwiftUI APIs over UIKit bridging (`UIViewRepresentable`) unless bridging is strictly required for legacy or low-level APIs.
- **Strict Concurrency**: All models, services, and view state must compile under Swift 6 Strict Concurrency Checking (`-strict-concurrency=complete`) with zero warnings. Mark shared data types as `Sendable` and isolate state mutations to `@MainActor` or custom `actor` domains.
- **View Composition**: Keep `var body: some View` clean and concise. Extract logical chunks into small private computed views or separate subview structs to maintain optimal SwiftUI diffing performance.
- **Image Optimization**: When displaying high-resolution images (such as page tiles), implement proper downsampling rather than loading full-scale uncompressed bitmaps into memory.

---

## 2. State & Data Flow Checklist

| Property Wrapper / Macro | Scope | Best For |
| :--- | :--- | :--- |
| `@State` | View-local | Value types (booleans, numbers, simple selections) owned exclusively by the view. |
| `@Binding` | Child view | Two-way read/write link to state owned by an ancestor. |
| `@Observable` class | Domain / Feature | Complex business logic, services, view models shared across views. |
| `@Environment` | Hierarchy-wide | System values (e.g. `\colorScheme`, `\dismiss`, `\locale`) or injected dependencies. |

---

## 3. High-Performance List & Canvas Guidelines

1. **Stable Identifiers**: Always ensure collections iterated via `ForEach` or `List` have truly unique and stable `id` properties. Never use unstable indices (`\.self` on primitive arrays where order shifts).
2. **Heavy Computations Outside Body**: Never perform filtering, sorting, or database queries directly inside `var body: some View`. Perform them in the `@Observable` model and publish memoized results.
3. **Windowed Memory**: For long scrollable content (such as 848 Mushaf pages), implement windowed caching so only pages $N-1, N, N+1$ remain in active memory.
4. **Tile Downsampling**: Load images sized to the exact physical display point dimensions $\times$ scale factor to prevent memory bloat and frame drops during fast paging.

---

## 4. Modern SwiftUI API Reference (iOS 17+)

- Navigation: `NavigationStack(path:)` with typed `.navigationDestination(for: Destination.self)`
- Sheets & Detents: `.sheet(isPresented:) { ... }` with `.presentationDetents([.fraction(0.35), .medium, .large])` and `.presentationDragIndicator(.visible)`
- Visual Backgrounds: `.background(.ultraThinMaterial)` and `.backgroundStyle()`
- Animations: Prefer explicit `withAnimation(.spring(...))` tied directly to state changes, or `.animation(_:value:)` with explicit value triggers. Never use parameterless `.animation()`.
