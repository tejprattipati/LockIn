// LockInApp.swift
// App entry point. Configures SwiftData container, seeds defaults,
// registers notification categories, and handles deep-link / intent handoffs.

import SwiftUI
import SwiftData
import UserNotifications

@main
struct LockInApp: App {

    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared

    // SwiftData model container — all models declared here
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            GoalProfile.self,
            DailyLog.self,
            MealEvent.self,
            ChecklistEntry.self,
            MealTemplate.self,
            WeightEntry.self,
            WorkoutEntry.self,
            ReminderRule.self,
            AdherenceMetric.self,
            TDEEAdjustmentState.self,
            ExternalIntegrationStatus.self,
            ProgressPhoto.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("[LockIn] Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(LockInApp.sharedModelContainer)
                .environmentObject(notificationManager)
                .environmentObject(healthKitManager)
                .preferredColorScheme(.dark)
                .task {
                    await startupSequence()
                }
        }
    }

    // MARK: - Startup Sequence
    private func startupSequence() async {
        // 1. Register notification categories
        notificationManager.registerCategories()

        // 2. Request authorization (shows dialog on first run, no-op thereafter)
        let granted = await notificationManager.requestAuthorization()

        // 3. Seed default data (no-op if already seeded)
        let context = LockInApp.sharedModelContainer.mainContext
        DataSeeder.seedIfNeeded(modelContext: context)

        // 4. Reschedule notifications — skip smart reminders if action already done today
        if granted {
            let rules = (try? context.fetch(FetchDescriptor<ReminderRule>())) ?? []
            let today = Calendar.current.startOfDay(for: .now)
            let todayPred = #Predicate<DailyLog> { $0.date == today }
            let todayLog = (try? context.fetch(FetchDescriptor<DailyLog>(predicate: todayPred)))?.first
            let isWeighedIn = todayLog?.isWeighedIn ?? false
            let isFoodLogged = todayLog?.actualCalories != nil
            await notificationManager.scheduleAll(from: rules, isWeighedIn: isWeighedIn, isFoodLogged: isFoodLogged)
        }

        // 5. Sync HealthKit if permitted
        await healthKitManager.checkPermissions()
        if healthKitManager.weightPermissionGranted {
            await healthKitManager.sync()
        }

        // 6. Handle any pending App Intent handoffs
        await handlePendingIntents(context: context)
    }

    // MARK: - App Intent Handoff
    private func handlePendingIntents(context: ModelContext) async {
        let defaults = UserDefaults.standard

        // Pending weight entry from Siri
        if let pendingWeight = defaults.value(forKey: "pendingWeightEntry") as? Double,
           let pendingDate = defaults.value(forKey: "pendingWeightEntryDate") as? Date,
           Calendar.current.isDateInToday(pendingDate) {
            let entry = WeightEntry(date: pendingDate, weightLb: pendingWeight, source: .manual)
            context.insert(entry)
            try? context.save()
            defaults.removeObject(forKey: "pendingWeightEntry")
            defaults.removeObject(forKey: "pendingWeightEntryDate")
        }

        // Pending weigh-in mark from Siri
        if defaults.bool(forKey: "pendingMarkWeighIn") {
            let today = Calendar.current.startOfDay(for: .now)
            let pred = #Predicate<DailyLog> { $0.date == today }
            if let log = try? context.fetch(FetchDescriptor<DailyLog>(predicate: pred)).first {
                log.checklist(for: .morningWeighIn)?.isCompleted = true
                log.checklist(for: .morningWeighIn)?.completedAt = .now
                try? context.save()
            }
            defaults.removeObject(forKey: "pendingMarkWeighIn")
        }
    }
}
