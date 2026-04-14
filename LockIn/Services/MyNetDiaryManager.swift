// MyNetDiaryManager.swift
// Opens MyNetDiary via URL scheme deep link.
// If the deep link fails (scheme unsupported / app not installed),
// falls back to opening the App Store page — so something always happens.
//
// NOTE: mynetdiary:// is user-reported, not officially documented by MND.
// All deep links are best-effort. The App Store fallback is the guaranteed floor.

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

    // MND App Store URL — always openable, guaranteed fallback
    private let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id287529757")!
    // Web fallback if App Store scheme unavailable
    private let appStoreWebURL = URL(string: "https://apps.apple.com/us/app/mynetdiary-calorie-counter/id287529757")!

    @Published var lastOpenedAt: Date?

    // MARK: - Main Open Function
    /// Tries MND deep links in order. If all fail, opens App Store so
    /// the user can at least tap "Open" from there.
    @discardableResult
    func open(_ action: MNDAction) async -> MNDIntegrationResult {
        let schemes = deepLinksFor(action)

        for scheme in schemes {
            guard let url = URL(string: scheme) else { continue }
            let opened = await openURL(url)
            if opened {
                lastOpenedAt = .now
                return MNDIntegrationResult(success: true, method: scheme, fallbackInstructions: nil)
            }
        }

        // Deep links all failed — open App Store as a guaranteed fallback.
        // On the device this opens the MND App Store page; user can tap "Open"
        // to launch MND if installed, or download it.
        let storeOpened = await openURL(appStoreURL)
        if !storeOpened {
            // Last resort: web URL
            await openURL(appStoreWebURL)
        }

        return MNDIntegrationResult(
            success: false,
            method: "App Store fallback",
            fallbackInstructions: fallbackInstructions(for: action)
        )
    }

    // MARK: - Private: Open URL using completion handler form (correct async wrapping)
    @discardableResult
    private func openURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - URL schemes per action
    private func deepLinksFor(_ action: MNDAction) -> [String] {
        // mynetdiary:// is user-reported but not officially documented.
        // Tried in order — first match wins.
        switch action {
        case .openApp:
            return ["mynetdiary://", "mynetdiary://diary"]
        case .logFood:
            return ["mynetdiary://diary", "mynetdiary://"]
        case .logWeight:
            return ["mynetdiary://diary", "mynetdiary://"]
        case .logDiary:
            return ["mynetdiary://diary", "mynetdiary://"]
        case .viewDashboard:
            return ["mynetdiary://", "mynetdiary://diary"]
        }
    }

    // MARK: - Fallback instructions (shown only if deep link AND App Store both fail)
    private func fallbackInstructions(for action: MNDAction) -> String {
        switch action {
        case .openApp:       return "Open MyNetDiary from your home screen."
        case .logFood:       return "Open MyNetDiary → tap + → Food → log your meal."
        case .logWeight:     return "Open MyNetDiary → Progress → Body Weight → log today's weight."
        case .logDiary:      return "Open MyNetDiary → Diary → review today's entries."
        case .viewDashboard: return "Open MyNetDiary → Dashboard."
        }
    }
}
