# LockIn — Personal Cut Discipline System

A single-user iOS app built in SwiftUI, designed specifically to enforce a fat-loss
cut plan by targeting the exact failure points: late-night ordering, dessert binges,
inconsistent logging, and failure to pre-plan the night meal.

**This is not a public app. It is a personal operating system for a specific cut.**

---

## Goal

- Current: ~170 lb, ~25–26% BF
- Target: 147 lb, 12% BF
- Deadline: August 8, 2026
- Intermediate check-in: May 17, 2026
- Required pace: ~1.4 lb/week

---

## Features

| Feature | Description |
|---------|-------------|
| Today Command Center | Calories, protein, weight, streak, risk level, checklist |
| Daily Checklist | Timestamped completion of 12 compliance items |
| Meal Plan System | Pre-defined slots: Meal 1, Meal 2, Night Meal, Emergency Snack |
| **Intervene Tab** | Full crisis flow — anti-order intervention with 15-min timer |
| Anti-Binge Flow | 8-step sequence: question, progress, damage comparison, replacement, timer, decision |
| Messed Up Flow | Damage-control protocol — prevents spiral, logs failure honestly |
| Adaptive TDEE Engine | Katch-McArdle BMR + conservative TDEE + weekly adaptive correction |
| Weight + Compliance Charts | 30-day trends, streaks, category breakdown |
| Notifications | 8 configurable daily reminders with actionable responses |
| HealthKit Integration | Read weight, steps, workouts from Apple Health |
| MyNetDiary Integration | Best-effort deep link + honest fallback instructions |
| App Intents / Siri | "Start anti-order flow", "Mark weigh-in done", "Show tonight's plan" |

---

## Quick Setup (Using XcodeGen — Recommended)

### Prerequisites

- macOS 13+ with Xcode 15+
- iPhone running iOS 17+
- Apple Developer account (free account works for personal use / device install)
- XcodeGen (optional but recommended)

### Option A: XcodeGen (fastest)

```bash
# 1. Install XcodeGen
brew install xcodegen

# 2. Clone / navigate to the repo root
cd /path/to/LockIn

# 3. Generate the Xcode project
xcodegen generate

# 4. Open the generated project
open LockIn.xcodeproj
```

Then skip to **Configure Signing** below.

---

### Option B: Manual Xcode Setup

1. Open **Xcode → File → New → Project**
2. Choose **App** under iOS
3. Name it **LockIn**, Bundle ID: `com.personal.LockIn`
4. Language: **Swift**, Interface: **SwiftUI**, Storage: **SwiftData**
5. Click **Next** and save inside this repository folder

6. **Delete** the auto-generated `ContentView.swift` and `LockInApp.swift`

7. **Add the source files** — drag the entire `LockIn/` folder into the Xcode project navigator:
   - `Models/` — all `.swift` files
   - `Services/` — all `.swift` files
   - `Views/` — all folders and `.swift` files
   - `AppIntents/` — `LockInIntents.swift`
   - `LockInApp.swift`
   - `ContentView.swift`
   - `Info.plist`

8. When prompted, ensure **"Copy items if needed"** is **unchecked** (files are already in place).

---

### Configure Signing

1. Select the **LockIn** project in the navigator
2. Under **Signing & Capabilities**, set **Team** to your Apple ID
3. Bundle ID: `com.personal.LockIn` (change if needed)
4. Xcode will auto-manage provisioning

---

### Enable Capabilities

In **Signing & Capabilities**, add:

| Capability | Required for |
|-----------|--------------|
| **HealthKit** | Reading weight, steps, workouts from Apple Health |
| **Push Notifications** | Local notification support (needed even for local notifications) |
| **Siri** | App Intents / Siri shortcuts |

To add: click **"+ Capability"** → search and add each one.

The `LockIn.entitlements` file already contains the HealthKit entitlement. Xcode will sync it automatically when you add the capability.

---

### Build & Run

1. Plug in your iPhone via USB (or use wireless developer mode)
2. Select your iPhone as the build target in Xcode
3. Press **⌘R** to build and run
4. On first launch, the app will:
   - Seed your default profile (170 lb, 6'1.5", 25.5% BF)
   - Create default meal templates
   - Set up notification rules (not yet scheduled until you grant permission)

---

## First-Time Configuration

After launch, go through this order:

1. **Settings → Edit Profile** — confirm your current weight and body fat %
2. **Settings → Notifications → Request Permission** — grant notification access
3. **Plan → Edit Targets** — confirm calorie and protein targets
4. **Plan → Meal Templates** — edit the default night meal to match what you actually eat
5. **Settings → Apple Health → Request Access** — optional but useful
6. **Today → Weigh In** — log your first weight

---

## Daily Usage Workflow

### Every morning:
- Open app → tap scale icon → weigh in
- Check Today tab for the day's targets

### During the day:
- Log calories and protein from MyNetDiary using **Today → Update Calories/Protein**
- Tick off checklist items as you complete them

### Before night (by 7pm):
- Check that your **Night Meal** is set in the Plan tab
- The app will send a pre-plan reminder at 7pm

### If you get hungry late at night:
- Open the **Intervene** tab
- Tap **"I'm about to order food"**
- Complete the full 8-step flow before making any decision

---

## Notification Schedule (Defaults)

| Time | Notification |
|------|-------------|
| 7:00 AM | Weigh-In reminder |
| 9:00 AM | Log Meal 1 |
| 1:00 PM | Log Meal 2 |
| 7:00 PM | Pre-plan tonight's night meal |
| 8:00 PM | Log in MyNetDiary |
| 9:00 PM | Anti-order warning (high-risk window) |
| 11:00 PM | Bedtime wrap-up |
| 5:00 PM | Workout reminder |

Edit these in **Settings → Edit Reminder Schedule**.

---

## TDEE & Calorie Engine

### How it works

The app uses **Katch-McArdle** BMR (requires known body fat %):

```
LBM (lb) = weight × (1 - BF%)
BMR = 370 + (21.6 × LBM in kg)
Conservative TDEE = BMR × activity_multiplier × 0.95
Daily Deficit = TDEE - target_calories
Expected loss = (deficit × 7) / 3500 lb/week
```

The 5% haircut (`× 0.95`) is intentional. The app deliberately underestimates maintenance.

### Adaptive Correction

After 10+ weigh-ins, the engine evaluates weekly:

1. Compares expected vs. actual 7-day average weight change
2. Infers real maintenance from the discrepancy
3. Applies a dampened correction (40% of inferred error, max ±75 kcal/day per cycle)
4. Updates the TDEE estimate conservatively

View this in **Progress → TDEE Engine**.

---

## MyNetDiary Integration

The app attempts to open MyNetDiary in this order:

1. `mynetdiary://` deep link (undocumented, user-reported — best-effort)
2. Configurable custom link (Settings → MND Integration)
3. Fallback: displays exact manual instructions

**No API calls are made. No credentials are stored. There is no official MyNetDiary API.**

If the deep link fails, the app shows step-by-step instructions like:
> "Open MyNetDiary → tap + → Food → log your meal"

---

## Siri Shortcuts

After granting Siri permission, these phrases work:

- _"Start anti-order flow in LockIn"_
- _"I'm about to order food in LockIn"_
- _"Mark weigh-in done in LockIn"_
- _"Show tonight's plan in LockIn"_
- _"Open MyNetDiary from LockIn"_

Set up via **Settings app → Siri & Search → LockIn**.

---

## iOS Limitations

| Limitation | Reality | LockIn's approach |
|------------|---------|-------------------|
| Can't force-open other apps | iOS sandboxing | Deep links + manual fallback |
| Can't background monitor | iOS doesn't allow arbitrary background execution | All notifications are local and scheduled |
| MyNetDiary URL scheme | Not officially documented | Best-effort attempt, honest fallback |
| HealthKit automatic sync | Requires user permission | Syncs on app open if permitted |
| Notification banners | Shown only if user granted permission | Setup flow asks early |
| App Intents | iOS 16+ only | Graceful: app works fine without Siri |

---

## File Structure

```
LockIn/
├── project.yml                    ← XcodeGen config
├── README.md
└── LockIn/
    ├── LockInApp.swift            ← Entry point, SwiftData container, startup
    ├── ContentView.swift          ← Tab container, notification routing
    ├── Info.plist                 ← HealthKit + MND URL scheme declarations
    ├── LockIn.entitlements        ← HealthKit entitlement
    ├── Assets.xcassets/
    ├── Models/
    │   ├── Enums.swift            ← All shared enum types
    │   ├── UserProfile.swift      ← Physical stats (singleton)
    │   ├── GoalProfile.swift      ← Cut goals, targets, motivation (singleton)
    │   ├── DailyLog.swift         ← One per day — central daily record
    │   ├── ChecklistEntry.swift   ← Individual checklist item
    │   ├── MealTemplate.swift     ← Default meal slot templates
    │   ├── MealEvent.swift        ← Actual meal for a given day
    │   ├── WeightEntry.swift      ← Body weight measurement
    │   ├── WorkoutEntry.swift     ← Workout log
    │   ├── ReminderRule.swift     ← Notification configuration
    │   ├── AdherenceMetric.swift  ← Precomputed daily compliance
    │   ├── TDEEAdjustmentState.swift ← Adaptive TDEE engine state
    │   └── ExternalIntegrationStatus.swift ← HealthKit/MND status
    ├── Services/
    │   ├── CalculationEngine.swift ← BMR, TDEE, adaptive correction, projections
    │   ├── NotificationManager.swift ← Schedule and manage local notifications
    │   ├── HealthKitManager.swift ← Read/write Apple Health data
    │   ├── MyNetDiaryManager.swift ← Deep link + manual fallback
    │   └── DataSeeder.swift       ← First-launch defaults + preview data
    ├── Views/
    │   ├── Shared/
    │   │   └── LockInTheme.swift  ← Colors, typography, reusable components
    │   ├── Today/
    │   │   ├── TodayView.swift    ← Main dashboard
    │   │   └── DailyChecklistView.swift ← Full checklist
    │   ├── Intervene/
    │   │   ├── InterveneView.swift ← Crisis tab
    │   │   ├── AntiBingeFlowView.swift ← 8-step intervention
    │   │   └── MessedUpFlowView.swift  ← Damage control
    │   ├── Plan/
    │   │   ├── PlanEditorView.swift ← Targets, templates, motivation
    │   │   └── MealTemplateEditorView.swift ← Edit single template
    │   ├── Progress/
    │   │   └── ProgressView.swift ← Weight chart, compliance, body comp, TDEE
    │   └── Settings/
    │       └── SettingsView.swift ← Profile, notifications, integrations
    └── AppIntents/
        └── LockInIntents.swift    ← Siri shortcuts
```

---

## Troubleshooting

**Build fails: "Module not found"**
- Ensure HealthKit and UserNotifications capabilities are added in Xcode

**Notifications not appearing**
- Go to Settings → Notifications → LockIn → enable alerts and sounds

**MyNetDiary deep link doesn't work**
- This is expected. The URL scheme is undocumented. Use the manual fallback instructions shown in the app.

**Weight not syncing from HealthKit**
- Go to Settings → Apple Health → Request Access, then tap Sync Now

**App won't install on device: "Untrusted Developer"**
- Go to iPhone Settings → General → VPN & Device Management → your email → Trust

**Charts framework missing**
- Requires iOS 16+. Xcode should include it automatically for iOS 17 targets.

---

## Extending the App

This is a personal app, so no abstraction layers were added speculatively.
If you want to extend it:

- **Add a workout log screen**: create views reading `WorkoutEntry`, populate from HealthKit
- **Daily plan override**: add a `dayOverrideTemplates` relationship to `DailyLog`
- **Lock-screen widget**: create a WidgetKit extension using the same SwiftData container
- **Calorie auto-import**: there is no public API for MyNetDiary; this is not possible without jailbreak or screen scraping

---

## Important Notes on Assumptions

- **Conservative by design**: TDEE uses a 5% haircut. The adaptive engine moves slowly.
- **No smartwatch calories**: the engine ignores active calorie estimates because they inflate.
- **MyNetDiary is your source of truth**: LockIn tracks whether you logged, but the actual calorie math lives in MND.
- **The intervention flow is high-friction intentionally**: the 15-minute timer and explicit fail-logging are designed to be uncomfortable.

---

*Built for personal use. Not intended for distribution.*
