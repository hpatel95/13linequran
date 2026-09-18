---
name: mobile-ios-design
description: >-
  Apple Human Interface Guidelines (HIG) and native iOS design patterns.
  Use when structuring iOS view layouts, designing navigation hierarchies, implementing SF Symbols,
  configuring Dynamic Type, designing Dark Mode adaptations, or ensuring WCAG touch target and contrast compliance.
---

# Mobile iOS Design & HIG Skill
*Adapted from Seth Hobson (wshobson/agents - mobile-ios-design)*

## 1. Apple Human Interface Guidelines (HIG) Foundations

Every iOS view must embody Apple's 3 core design tenets:
1. **Clarity**: Text is legible at every size, icons are precise and meaningful, adornments are subtle and purposeful.
2. **Deference**: The interface recedes completely; UI chrome exists solely to elevate and frame the primary content (the Quranic scripture).
3. **Depth**: Realistic visual layers, translucent materials (`.ultraThinMaterial`), and spatial hierarchy convey relationships between components.

---

## 2. iOS Touch Targets & Spacing Standards

- **Minimum Touch Target**: Every interactive element must have an active hit region of at least **$44 \times 44$ pt** (Apple standard), even if the visual icon is smaller (e.g. 20pt).
- **Safe Area Respect**: Never place essential interactive controls within the top Dynamic Island notch area (top 59pt) or behind the Home Indicator bar (bottom 34pt).
- **Standard Margins**: Use standard 16pt–20pt horizontal screen padding for content cards and text gutters.
- **Corner Radii**: Standardize corner curves to match iOS system chassis:
  - Small pills / badges: 4pt–8pt
  - Cards and list rows: 12pt–16pt
  - Modal bottom sheets: 24pt–32pt with continuous squircle curvature (`.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))`).

---

## 3. Native iOS Navigation Architecture

- **Primary Shell**: Use `NavigationStack` with typed destination enums conforming to `Hashable`.
- **Modals vs Push**:
  - Use **Push navigation** when browsing deeper into a hierarchical catalog (e.g. Index Hub → Surah Detail).
  - Use **Modal Sheets** for self-contained transient contexts (e.g. Ayah Translation sheet, Audio options, Settings).
- **Bottom Sheets**: Always support native iOS presentation detents:
  ```swift
  .presentationDetents([.fraction(0.38), .medium, .large])
  .presentationDragIndicator(.visible)
  ```

---

## 4. Typography, SF Symbols & Accessibility

1. **Dynamic Type Support**: Always use system text styles (`.font(.headline)`, `.font(.subheadline)`, etc.) or `.scaledFont()` for custom fonts so that users with accessibility font scaling don't get truncated text.
2. **SF Symbols Best Practices**:
   - Use official Apple SF Symbols for standard actions (e.g. `play.fill`, `bookmark`, `doc.on.doc` for copy, `square.and.arrow.up` for share).
   - Apply hierarchical and palette symbol rendering:
     ```swift
     Image(systemName: "bookmark.fill")
         .symbolRenderingMode(.hierarchical)
         .foregroundStyle(AppColors.saddleAmber)
     ```
3. **VoiceOver Accessibility**:
   - Every icon button must have a clear `.accessibilityLabel("...")`.
   - Complex layouts (such as an ayah number badge + title + page count) should be grouped:
     ```swift
     .accessibilityElement(children: .combine)
     ```
