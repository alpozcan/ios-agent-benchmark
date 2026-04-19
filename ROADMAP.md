# ROADMAP

The current benchmark is **Tier 1**: foundation iOS engineering. It tests protocol-driven DI, programmatic CoreData, Swift 6 strict concurrency, a mid-sized service layer, and basic navigation. Modern frontier coding agents can pass Tier 1.

To keep the benchmark useful as agents get better, each future tier layers in harder engineering decisions. Each tier is a standalone PRD that can be run on its own or composed on top of a lower tier.

The harness itself does not change across tiers. Each tier only adds a new `PRD.md` and implementation prompt.

---

## Tier 1 — Foundation (current)

**File:** `PRD.md`, `prompts/implementation.md`

Tests:
- Protocol-driven dependency injection without third-party frameworks
- 14-entity programmatic CoreData model with relationships
- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- 150+ services across Platform / Infrastructure / Feature / UI / Helpers
- 300+ DI registrations across 9 extension files
- 11 UI screens, 50 seeded topics, basic tab navigation
- Build discipline (no force-unwraps, Sendable correctness)

**Target output:** ~130-220 Swift files, ~10-14K lines.

**Measured:** wall-clock time, cycles used, convergence shape, self-repair ratio, cold-launch time, code-quality flags.

---

## Tier 2 — Gesture and Interaction Density

**File:** `prd-tier2.md` (to be added)

Forces the agent to make non-trivial UX decisions, not just wire views to state.

Features:
- Drag-and-drop between screens with `NSItemProvider`, `.draggable`, `.dropDestination`, hit-testing previews, reorder within lists, cross-screen drops into collections
- Pull-to-refresh with a custom gesture recognizer and rubber-band physics (no `.refreshable`)
- Swipe actions with tiered thresholds — short swipe reveals actions, long swipe commits (Mail pattern)
- Pinch-to-zoom content canvas with `MagnifyGesture` and `@GestureState` coordination
- Long-press context menus with custom previews and multi-select mode
- Keyboard avoidance and focus management with `@FocusState` across an 8-field form with interdependent validation
- Matched geometry effect transitions between list and detail, preserving aspect ratios
- Hero animations on navigation push with shared element transitions

**New measurements:** gesture handler correctness (via UI tests), state transition coverage, animation timing.

---

## Tier 3 — Real-Time and State Complexity

**File:** `prd-tier3.md` (to be added)

Forces the agent to reason about concurrency invariants, not just annotate actors.

Features:
- Live collaborative editing with a minimal CRDT text sync implementation
- Real-time presence indicators — cursor positions, typing states, read receipts — over WebSocket
- Optimistic updates with rollback on server rejection
- Offline queue with conflict resolution; mutations queued while offline, replayed with merge strategies on reconnect
- Undo / redo with command pattern across the whole app, including cross-screen actions
- Background sync with `BGAppRefreshTask` and `BGProcessingTask`, proper state restoration on relaunch
- Push notification handling with deep linking into specific topics

**New measurements:** race conditions found by Thread Sanitizer, `async let` vs `TaskGroup` usage, mutation ordering correctness.

---

## Tier 4 — Platform Integrations

**File:** `prd-tier4.md` (to be added)

Forces the agent to handle multi-target Tuist, entitlements, app groups, and URL routing across extensions.

Features:
- Widget target with `WidgetKit`, three sizes with distinct layouts, deep linking into specific topics
- App Intents and Siri Shortcuts — "Show today's notes", "Add a topic called X"
- Live Activity on Dynamic Island — reading session progress with countdown
- Share Extension accepting URLs, text, and images from Safari and Notes
- iCloud CloudKit sync with `CKContainer`, public and private databases, subscription-based remote change notifications
- Handoff and Continuity — start reading on iPhone, resume on iPad
- Universal Links and deep linking across a 12-screen hierarchy with type-safe URL routing

**New measurements:** extension compile success, entitlement correctness, shared-app-group access, widget bundle size.

---

## Tier 5 — Multimedia and On-Device Intelligence

**File:** `prd-tier5.md` (to be added)

Forces the agent to handle resource management, frame pipelines, and memory pressure.

Features:
- Camera capture with a custom `AVCaptureSession` pipeline (not `UIImagePickerController`), with zoom, exposure, format selection, and HDR toggle
- Video recording and trimming with `AVAssetExportSession` and a scrubber UI
- Audio transcription via `SFSpeechRecognizer` with a live waveform visualization
- PencilKit drawing canvas with layers, undo, pressure sensitivity, and vector export
- `PhotosPicker` with batch selection and memory-aware asynchronous thumbnail loading
- Core ML inference — topic classifier and keyword extractor via `VNCoreMLRequest`
- Apple Foundation Models for on-device LLM summarization of long topics
- Vision framework — text recognition from captured receipts and screenshots, structured as metadata

**New measurements:** memory high-water mark under load, frame drops during capture, Core ML warmup latency, Foundation Models context usage.

---

## Tier 6 — Commerce and Identity

**File:** `prd-tier6.md` (to be added)

Forces the agent to handle server-side validation, receipt parsing, and entitlement gating.

Features:
- StoreKit 2 subscriptions with monthly and annual tiers, introductory offers, family sharing, and receipt validation against the App Store Server API
- Sign in with Apple with server-side token refresh and account deletion flow (Apple App Review requirement)
- Paywall A/B testing via feature flags with deterministic bucketing
- Promo code redemption flow including server-side validation
- Restore purchases flow with proper UI feedback

**New measurements:** receipt refresh correctness, entitlement gate coverage, sign-in error-path handling.

---

## Tier 7 — Accessibility and Localization at Production Scale

**File:** `prd-tier7.md` (to be added)

Forces the agent to think beyond the golden path.

Features:
- Full VoiceOver support with `accessibilityLabel`, `accessibilityHint`, custom rotor actions, correct heading order, and `.accessibilityElement(children: .combine)` usage
- Dynamic Type across all 12 sizes including custom layouts for XXL accessibility sizes
- Localization for 8 languages including RTL (Arabic, Hebrew) with proper `.environment(\.layoutDirection)` handling
- Plural rules with `AttributedString` and `String.LocalizationValue`
- Regional formatting for dates, currencies, numbers via `FormatStyle`
- Reduce Motion, Reduce Transparency, Smart Invert, and High Contrast respect throughout

**New measurements:** `xcrun accessibilityaudit` pass rate, localization key coverage, RTL layout correctness via snapshot tests.

---

## Tier 8 — CI/CD and Test Infrastructure

**File:** `prd-tier8.md` (to be added)

Meta-layer: tests whether the agent can produce shippable engineering, not just running code.

Features:
- Swift Testing `@Suite` and `@Test` with parameterized tests, tags, and parallel execution
- Snapshot tests with `swift-snapshot-testing` for key screens
- XCUITest UI tests covering the top 5 user flows
- Build schemes for Debug, Staging, Release with separate Info.plist and app icons
- Tuist cache warming and `tuist cache` integration
- GitHub Actions workflow that runs generate + build + test + snapshot diff on every PR
- Fastlane integration for TestFlight beta deploys
- Danger-Swift for PR review automation

**New measurements:** CI pipeline green on first push, test coverage percentage, snapshot test stability.

---

## Recommended sequencing

For benchmarking frontier models as they improve:

1. **Start with Tier 2** once Tier 1 is saturated. It stays in a single target, needs no entitlements, and forces real UX reasoning.
2. **Pair Tier 3 with Tier 2** — gestures that mutate shared state exercise both axes simultaneously.
3. **Tiers 4-6** each require a weekend of PRD work and produce much larger projects (30K+ lines). Run these only when the agent can handle Tier 2+3 cleanly.
4. **Tiers 7-8** should layer on top of any tier as additional engineering-quality requirements, not as standalone runs. A Tier-3-plus-Tier-8 PRD exercises both real-time correctness and shippable CI at once.

Each tier should keep the same harness contract so historical results remain comparable. Only the `PRD.md` and `prompts/implementation.md` change between tiers.

---

## Contributing a tier

A new tier PRD should include:

1. **Feature list** — what the agent must build, with concrete acceptance criteria
2. **File-structure contract** — directory layout the agent must follow
3. **Measurement additions** — what the harness should record beyond Tier 1 metrics
4. **Known pitfalls** — common failure modes, spelled out so the PRD is self-contained

Open a PR with `PRD-tier-N.md`, `prompts/implementation-tier-N.md`, and any script additions needed for new measurements.
