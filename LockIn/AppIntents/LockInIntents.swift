// LockInIntents.swift
// App Intents for Siri shortcuts and lock-screen actions.
// iOS 16+ required for App Intents.

import AppIntents
import SwiftUI
import SwiftData

// MARK: - App Shortcut Provider
struct LockInShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAntiBingeFlowIntent(),
            phrases: [
                "Start anti-order flow in \(.applicationName)",
                "I'm about to order food in \(.applicationName)",
                "Stop me from ordering in \(.applicationName)"
            ],
            shortTitle: "Stop the Order",
            systemImageName: "xmark.shield.fill"
        )

        AppShortcut(
            intent: MarkWeighInDoneIntent(),
            phrases: [
                "Mark weigh-in done in \(.applicationName)",
                "I weighed in with \(.applicationName)"
            ],
            shortTitle: "Mark Weigh-In",
            systemImageName: "scalemass"
        )

        AppShortcut(
            intent: OpenTonightsPlanIntent(),
            phrases: [
                "Show tonight's plan in \(.applicationName)",
                "What's my night meal in \(.applicationName)"
            ],
            shortTitle: "Tonight's Plan",
            systemImageName: "moon.fill"
        )

        AppShortcut(
            intent: OpenMyNetDiaryIntent(),
            phrases: [
                "Open MyNetDiary from \(.applicationName)",
                "Log my food with \(.applicationName)"
            ],
            shortTitle: "Open MyNetDiary",
            systemImageName: "checkmark.icloud"
        )
    }
}

// MARK: - Intent: Open Anti-Binge Flow
struct OpenAntiBingeFlowIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Anti-Order Flow"
    static var description = IntentDescription("Launches the intervention flow to prevent late-night ordering.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Set a notification in UserDefaults that ContentView will read on next launch
        UserDefaults.standard.set(true, forKey: "pendingAntiBingeFlow")
        return .result()
    }
}

// MARK: - Intent: Mark Weigh-In Done
struct MarkWeighInDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Morning Weigh-In Done"
    static var description = IntentDescription("Marks today's morning weigh-in as complete in LockIn.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: "pendingMarkWeighIn")
        return .result(dialog: "Weigh-in marked. Open LockIn to log your weight.")
    }
}

// MARK: - Intent: Show Tonight's Plan
struct OpenTonightsPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Tonight's Meal Plan"
    static var description = IntentDescription("Opens LockIn and shows tonight's planned meal.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingShowNightPlan")
        return .result()
    }
}

// MARK: - Intent: Open MyNetDiary
struct OpenMyNetDiaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Open MyNetDiary"
    static var description = IntentDescription("Attempts to open MyNetDiary via deep link.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MyNetDiaryManager.shared
        let result = await manager.open(.openApp)
        if result.success {
            return .result(dialog: "Opening MyNetDiary.")
        } else {
            let instructions = result.fallbackInstructions ?? "Open MyNetDiary manually."
            return .result(dialog: "\(instructions)")
        }
    }
}

// MARK: - Intent: Log Weight with Value
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Weight in LockIn"
    static var description = IntentDescription("Logs a body weight entry into LockIn.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Weight (pounds)")
    var weightLb: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(weightLb, forKey: "pendingWeightEntry")
        UserDefaults.standard.set(Date(), forKey: "pendingWeightEntryDate")
        return .result(dialog: "Weight of \(String(format: "%.1f", weightLb)) lb queued. Open LockIn to confirm.")
    }
}
