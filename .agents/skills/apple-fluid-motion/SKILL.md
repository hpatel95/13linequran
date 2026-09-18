---
name: apple-fluid-motion
description: >-
  Apple's principles for fluid interfaces, gesture-driven interactions, and physical spring animations.
  Use when building or refining gestures (pinch, swipe, drag), bottom sheet physics, interactive ayah highlights,
  custom spring curves, 120Hz ProMotion paging responsiveness, or interruptible transitions.
---

# Apple Fluid Motion & Interaction Skill
*Adapted from Emil Kowalski (emilkowal.ski / apple-design)*

## 1. Core Philosophy: The Living Interface

An interface feels alive and physical when it follows these fundamental rules:
1. **Response (Kill Input Latency)**: Provide visual feedback on pointer-down / touch-down instantly. Never wait for touch-up or gesture completion to show pressed feedback.
2. **Direct Manipulation**: Touch and content move together 1:1. When dragging or scrubbing, the element stays anchored exactly where the finger touched it.
3. **Interruptibility**: The single most critical principle. Any running animation must be interruptible and redirectable at any instant without waiting for it to finish.
4. **Behavior Over Fixed Timing**: Use physics-based springs instead of fixed duration ease-in/ease-out curves for anything a user can touch or flick.

---

## 2. Apple's Spring Parameter Reference for SwiftUI

Apple frames springs around two human-intuitive parameters:
* **Response**: The duration of one natural oscillation in seconds (how snappy the motion feels).
* **Damping Ratio**:
  * `1.0` = **Critically Damped**: Smooth settle, zero bounce or overshoot. Use for default UI transitions (menus, view swaps).
  * `0.75 ... 0.85` = **Gentle Bounce**: Small natural overshoot. Use ONLY when a user flick or gesture carried momentum into the transition.

### Concrete SwiftUI Spring Values

```swift
// 1. Repositioning & Normal Movement (PiP, Floating HUDs, Mode Toggles)
.spring(response: 0.4, dampingFraction: 1.0)

// 2. Bottom Sheet Slide-Up & Drag Responding
.spring(response: 0.32, dampingFraction: 0.82)

// 3. Button Press Downscale (Immediate tactile feedback)
.spring(response: 0.2, dampingFraction: 1.0)

// 4. Subtle Ayah Selection Pulse
.spring(response: 0.28, dampingFraction: 0.88)
```

---

## 3. Gestures & Momentum Rules

### A. Velocity Handoff
When a user lifts their finger off a drag (e.g. dismissing a sheet or turning a page):
* Never snap to a target with a fixed animation that discards the release speed.
* Project the landing endpoint using release velocity.
* Pass the initial velocity into the settling spring so there is zero visible seam between the user's touch and the settling animation.

### B. Rubber-Banding at Scroll Boundaries
When dragging beyond the first or last page (Page 1 or Page 848):
* Implement exponential resistance (rubber-banding).
* Offset decreases as drag distance increases:
  $$\Delta x_{\text{display}} = \Delta x_{\text{touch}} \times 0.55$$
* On release, snap back using a critically damped spring (`dampingFraction: 1.0`).

### C. Touch Target Scale & Haptics
* Tappable elements must scale slightly (`scaleEffect(0.97)`) on press.
* Pair key state completions (bookmark saved, ayah tapped) with subtle system haptics (`UIImpactFeedbackGenerator(style: .light)` or `.medium`).
