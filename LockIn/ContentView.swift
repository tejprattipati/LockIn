// ContentView.swift
// Root tab container. Five tabs: Today, Plan, Progress, Intervene, Settings.
// Handles deep-link navigation from notification actions and App Intents.

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .today
    @State private var showAntiBingeOnLaunch = false
    @State private var showNightPlanOnLaunch = false

    enum AppTab: Int {
        case today     = 0
        case plan      = 1
        case progress  = 2
        case intervene = 3
        case settings  = 4
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "target")
                }
                .tag(AppTab.today)

            PlanEditorView()
                .tabItem {
                    Label("Plan", systemImage: "list.bullet.clipboard")
                }
                .tag(AppTab.plan)

            CutProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.progress)

            InterveneView()
                .tabItem {
                    Label("Intervene", systemImage: "shield.slash.fill")
                }
                .tag(AppTab.intervene)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(LockInTheme.Colors.accent)
        .background(LockInTheme.Colors.background.ignoresSafeArea())
        .onAppear {
            checkPendingHandoffs()
            setupTabBarAppearance()
            setupNavigationBarAppearance()
        }
        // Handle notification-triggered deep links
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lockin.openAntiBinge"))) { _ in
            selectedTab = .intervene
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lockin.openNightPlan"))) { _ in
            selectedTab = .intervene
        }
    }

    // MARK: - Check Pending Intents
    private func checkPendingHandoffs() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: "pendingAntiBingeFlow") {
            selectedTab = .intervene
            showAntiBingeOnLaunch = true
            defaults.removeObject(forKey: "pendingAntiBingeFlow")
        }

        if defaults.bool(forKey: "pendingShowNightPlan") {
            selectedTab = .intervene
            showNightPlanOnLaunch = true
            defaults.removeObject(forKey: "pendingShowNightPlan")
        }
    }

    // MARK: - Tab Bar Appearance
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(LockInTheme.Colors.surface)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(LockInTheme.Colors.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(LockInTheme.Colors.accent)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(LockInTheme.Colors.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(LockInTheme.Colors.textTertiary)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Navigation Bar Appearance
    private func setupNavigationBarAppearance() {
        let navBg = UIColor(LockInTheme.Colors.background)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = navBg
        appearance.shadowColor = UIColor(LockInTheme.Colors.border)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(LockInTheme.Colors.textPrimary)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(LockInTheme.Colors.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(LockInTheme.Colors.accent)
    }
}

// MARK: - Notification Response Handler
// Attach this as UNUserNotificationCenterDelegate in the app scene or via a helper.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier

        switch actionId {
        case NotificationManager.Action.startIntervene.rawValue:
            NotificationCenter.default.post(name: Notification.Name("lockin.openAntiBinge"), object: nil)

        case NotificationManager.Action.showNightPlan.rawValue:
            NotificationCenter.default.post(name: Notification.Name("lockin.openNightPlan"), object: nil)

        case NotificationManager.Action.markWeighInDone.rawValue:
            UserDefaults.standard.set(true, forKey: "pendingMarkWeighIn")

        case NotificationManager.Action.openMND.rawValue:
            Task { await MyNetDiaryManager.shared.open(.openApp) }

        default:
            break
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self, GoalProfile.self, DailyLog.self,
            MealEvent.self, ChecklistEntry.self, MealTemplate.self,
            WeightEntry.self, WorkoutEntry.self, ReminderRule.self,
            AdherenceMetric.self, TDEEAdjustmentState.self,
            ExternalIntegrationStatus.self, ProgressPhoto.self
        ], inMemory: true)
}
