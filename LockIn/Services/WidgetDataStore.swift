// WidgetDataStore.swift
// Writes today's task + nutrition data to the shared App Group UserDefaults
// so the home-screen widget can read it without SwiftData access.
// Call sync() whenever the daily log changes.

import Foundation
import WidgetKit

enum WidgetDataStore {

    static let suiteName = "group.com.personal.LockIn"

    /// Write current state and trigger a widget timeline reload.
    static func sync(log: DailyLog?, goal: GoalProfile?, dayNumber: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Incomplete checklist item names
        let incompleteTasks: [String] = (log?.checklistItems ?? [])
            .filter { !$0.isCompleted }
            .map { $0.type.rawValue }

        defaults.set(incompleteTasks,              forKey: "incompleteTasks")
        defaults.set(log?.actualCalories ?? 0,     forKey: "caloriesToday")
        defaults.set(log?.actualProtein  ?? 0,     forKey: "proteinToday")
        defaults.set(goal?.dailyCalorieTarget ?? 1900, forKey: "caloriesTarget")
        defaults.set(goal?.dailyProteinTarget ?? 145,  forKey: "proteinTarget")
        defaults.set(dayNumber,                    forKey: "dayNumber")

        WidgetCenter.shared.reloadAllTimelines()
    }
}
