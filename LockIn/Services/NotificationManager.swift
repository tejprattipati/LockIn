// NotificationManager.swift
// Schedules and manages all local notifications.
// Tone is direct and disciplined — no cheerful wellness fluff.

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Notification Category / Action Identifiers
    enum Category: String {
        case weighIn      = "WEIGH_IN"
        case mealLogging  = "MEAL_LOGGING"
        case nightWarning = "NIGHT_WARNING"
        case wrapUp       = "WRAP_UP"
        case antiOrder    = "ANTI_ORDER"
    }

    enum Action: String {
        case markWeighInDone   = "MARK_WEIGH_IN"
        case openApp           = "OPEN_APP"
        case openMND           = "OPEN_MND"
        case startIntervene    = "START_INTERVENE"
        case showNightPlan     = "SHOW_NIGHT_PLAN"
        case markMealLogged    = "MARK_MEAL_LOGGED"
    }

    // MARK: - Request Authorization
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
            await checkStatus()
            return granted
        } catch {
            print("[NotificationManager] Auth error: \(error)")
            return false
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Register Categories
    func registerCategories() {
        let center = UNUserNotificationCenter.current()

        // Weigh-in category
        let markWeighIn = UNNotificationAction(
            identifier: Action.markWeighInDone.rawValue,
            title: "Mark Weigh-In Done",
            options: [.foreground]
        )
        let openApp = UNNotificationAction(
            identifier: Action.openApp.rawValue,
            title: "Open LockIn",
            options: [.foreground]
        )
        let weighInCategory = UNNotificationCategory(
            identifier: Category.weighIn.rawValue,
            actions: [markWeighIn, openApp],
            intentIdentifiers: [],
            options: []
        )

        // Night warning category
        let startIntervene = UNNotificationAction(
            identifier: Action.startIntervene.rawValue,
            title: "Start Anti-Order Flow",
            options: [.foreground]
        )
        let showPlan = UNNotificationAction(
            identifier: Action.showNightPlan.rawValue,
            title: "Show Tonight's Plan",
            options: [.foreground]
        )
        let nightCategory = UNNotificationCategory(
            identifier: Category.nightWarning.rawValue,
            actions: [startIntervene, showPlan, openApp],
            intentIdentifiers: [],
            options: []
        )

        // Meal logging category
        let markMealLogged = UNNotificationAction(
            identifier: Action.markMealLogged.rawValue,
            title: "Mark as Logged",
            options: [.foreground]
        )
        let openMND = UNNotificationAction(
            identifier: Action.openMND.rawValue,
            title: "Open MyNetDiary",
            options: [.foreground]
        )
        let mealCategory = UNNotificationCategory(
            identifier: Category.mealLogging.rawValue,
            actions: [markMealLogged, openMND, openApp],
            intentIdentifiers: [],
            options: []
        )

        // Wrap-up category
        let wrapUpCategory = UNNotificationCategory(
            identifier: Category.wrapUp.rawValue,
            actions: [openApp],
            intentIdentifiers: [],
            options: []
        )

        // Anti-order category
        let antiOrderCategory = UNNotificationCategory(
            identifier: Category.antiOrder.rawValue,
            actions: [startIntervene, openApp],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            weighInCategory, nightCategory, mealCategory, wrapUpCategory, antiOrderCategory
        ])
    }

    // MARK: - Schedule All from Rules
    func scheduleAll(from rules: [ReminderRule]) async {
        let center = UNUserNotificationCenter.current()
        // Remove old scheduled notifications
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        for rule in rules where rule.isEnabled {
            await schedule(rule: rule)
        }
    }

    func schedule(rule: ReminderRule) async {
        let center = UNUserNotificationCenter.current()
        let content = notificationContent(for: rule)

        var comps = DateComponents()
        comps.hour = rule.hour
        comps.minute = rule.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "lockin.reminder.\(rule.type.rawValue)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("[NotificationManager] Failed to schedule \(rule.type): \(error)")
        }
    }

    // MARK: - Ad-Hoc Notifications

    /// Fires an immediate "you're about to fail" alert.
    func fireAntiOrderAlert() async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "STOP."
        content.body = "You're in the failure window. Open LockIn before you order anything."
        content.sound = .default
        content.categoryIdentifier = Category.antiOrder.rawValue

        let request = UNNotificationRequest(
            identifier: "lockin.antiorder.immediate.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }

    /// Schedule a follow-up in N minutes during the intervene timer flow.
    func scheduleInterveneFollowUp(inMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "15 Minutes Passed."
        content.body = "Timer is up. Do you still want to order? Open LockIn and answer honestly."
        content.sound = .default
        content.categoryIdentifier = Category.antiOrder.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(inMinutes * 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: "lockin.intervene.followup",
            content: content,
            trigger: trigger
        )
        // Cancel any existing
        center.removePendingNotificationRequests(withIdentifiers: ["lockin.intervene.followup"])
        try? await center.add(request)
    }

    func cancelInterveneFollowUp() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["lockin.intervene.followup"])
    }

    // MARK: - Remove All
    func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Content Factory
    private func notificationContent(for rule: ReminderRule) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = rule.customTitle ?? defaultTitle(for: rule.type)
        content.body = rule.customBody ?? defaultBody(for: rule.type)
        content.sound = .default
        content.categoryIdentifier = categoryId(for: rule.type)
        return content
    }

    private func defaultTitle(for type: ReminderType) -> String {
        switch type {
        case .morningWeighIn:    return "Weigh In. Now."
        case .meal1:             return "Log Meal 1"
        case .meal2:             return "Log Meal 2"
        case .prePlanNightMeal:  return "Plan Your Night Meal"
        case .nightAntiOrder:    return "Don't Order. You Have a Plan."
        case .bedtimeWrapUp:     return "Day Wrap-Up"
        case .loggingReminder:   return "Log in MyNetDiary"
        case .workoutReminder:   return "Workout Window"
        }
    }

    private func defaultBody(for type: ReminderType) -> String {
        switch type {
        case .morningWeighIn:
            return "Step on the scale before eating or drinking anything. Log it."
        case .meal1:
            return "You haven't logged Meal 1 yet. Eat now. Log it in MyNetDiary."
        case .meal2:
            return "Log Meal 2 in MyNetDiary before the afternoon slips away."
        case .prePlanNightMeal:
            return "Pre-plan your night meal RIGHT NOW. It prevents the late-night spiral."
        case .nightAntiOrder:
            return "This is your high-risk window. Your night meal is already planned. Eat that."
        case .bedtimeWrapUp:
            return "Close out today. Log anything unlogged. Mark your checklist complete."
        case .loggingReminder:
            return "Open MyNetDiary and confirm today's calories and protein are logged."
        case .workoutReminder:
            return "Get your workout in. Even 30 minutes counts."
        }
    }

    private func categoryId(for type: ReminderType) -> String {
        switch type {
        case .morningWeighIn:    return Category.weighIn.rawValue
        case .meal1, .meal2:     return Category.mealLogging.rawValue
        case .prePlanNightMeal:  return Category.nightWarning.rawValue
        case .nightAntiOrder:    return Category.antiOrder.rawValue
        case .bedtimeWrapUp:     return Category.wrapUp.rawValue
        case .loggingReminder:   return Category.mealLogging.rawValue
        case .workoutReminder:   return Category.wrapUp.rawValue
        }
    }
}
