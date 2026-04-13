// MyNetDiaryManager.swift
// Handles all MyNetDiary integration attempts, in priority order:
// 1. Deep link (mynetdiary:// URL scheme) — if available
// 2. Universal link fallback
// 3. App Store URL to open MND if not installed
// 4. Manual prompt with exact instructions
//
// NOTE: MyNetDiary's official URL schemes are not publicly documented.
// The scheme "mynetdiary://" has been reported by users but is not guaranteed
// to work or to remain stable across MND app updates. All calls are best-effort.
// The fallback manual prompt is always available and is the most reliable path.

import Foundation
import UIKit

enum MNDAction {
    case openApp
    case logFood
    case logWeight
    case logDiary
    case viewDashboard
}

struct MNDIntegrationResult {
    let success: Bool
    let method: String
    let fallbackInstructions: String?
}

@MainActor
final class MyNetDiaryManager: ObservableObject {
    static let shared = MyNetDiaryManager()

    // Known deep link schemes (best-effort, not officially documented)
    private let knownSchemes: [String] = [
        "mynetdiary://",
        "mynetdiary://diary",
        "mynetdiary://food"
    ]

    // App Store link for MyNetDiary
    private let appStoreURL = URL(string: "https://apps.apple.com/us/app/mynetdiary-calorie-counter/id287529757")!

    @Published var lastOpenedAt: Date?
    @Published var isInstalled: Bool = false
    @Published var customDeepLink: String = ""

    // MARK: - Check if MND is installed
    func checkInstalled() {
        guard let url = URL(string: "mynetdiary://") else {
            isInstalled = false
            return
        }
        isInstalled = UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Main Action Handler
    /// Attempts to open MyNetDiary for a specific action.
    /// Returns a result indicating which method worked and fallback instructions.
    @discardableResult
    func open(_ action: MNDAction, customLink: String? = nil) async -> MNDIntegrationResult {
        // 1. Try user-configured custom deep link first
        if let custom = customLink ?? (customDeepLink.isEmpty ? nil : customDeepLink),
           let url = URL(string: custom),
           await tryOpen(url: url) {
            lastOpenedAt = .now
            return MNDIntegrationResult(success: true, method: "Custom deep link: \(custom)", fallbackInstructions: nil)
        }

        // 2. Try known MND URL schemes
        for scheme in deepLinksFor(action: action) {
            if let url = URL(string: scheme), await tryOpen(url: url) {
                lastOpenedAt = .now
                return MNDIntegrationResult(success: true, method: "Deep link: \(scheme)", fallbackInstructions: nil)
            }
        }

        // 3. Try generic app open
        if let url = URL(string: "mynetdiary://"), await tryOpen(url: url) {
            lastOpenedAt = .now
            return MNDIntegrationResult(success: true, method: "Generic app open", fallbackInstructions: nil)
        }

        // 4. Manual fallback
        return MNDIntegrationResult(
            success: false,
            method: "Manual fallback",
            fallbackInstructions: fallbackInstructions(for: action)
        )
    }

    // MARK: - Open App Store (if not installed)
    func openAppStore() {
        UIApplication.shared.open(appStoreURL)
    }

    // MARK: - Private Helpers
    private func tryOpen(url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else { return false }
        return await UIApplication.shared.open(url)
    }

    private func deepLinksFor(action: MNDAction) -> [String] {
        // These are best-effort. No official documentation confirms these routes.
        switch action {
        case .openApp:       return ["mynetdiary://diary", "mynetdiary://"]
        case .logFood:       return ["mynetdiary://food/add", "mynetdiary://diary"]
        case .logWeight:     return ["mynetdiary://weight", "mynetdiary://progress"]
        case .logDiary:      return ["mynetdiary://diary"]
        case .viewDashboard: return ["mynetdiary://"]
        }
    }

    private func fallbackInstructions(for action: MNDAction) -> String {
        switch action {
        case .openApp:
            return "Open MyNetDiary manually from your home screen."
        case .logFood:
            return "Open MyNetDiary → tap the + button → Food → log your meal."
        case .logWeight:
            return "Open MyNetDiary → tap Progress → Body Weight → add today's weight."
        case .logDiary:
            return "Open MyNetDiary → tap Diary → review and confirm today's entries."
        case .viewDashboard:
            return "Open MyNetDiary → tap Dashboard to see today's summary."
        }
    }
}

// MARK: - Manual Prompt View Model
struct MNDPromptData: Identifiable {
    let id = UUID()
    let title: String
    let instructions: String
    let actionTitle: String
    let onAction: () -> Void
}
