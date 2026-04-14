// MealEvent.swift
// A meal as it actually occurred (or was planned) for a given day.
// Linked to a DailyLog; can be pre-filled from a MealTemplate.

import Foundation
import SwiftData

@Model
final class MealEvent {
    var id: UUID
    var slot: MealSlot
    var name: String
    var foods: [String]
    var estimatedCalories: Int
    var estimatedProtein: Int
    var estimatedCarbs: Int
    var estimatedFat: Int
    var plannedCalories: Int
    var plannedProtein: Int
    var completedAt: Date?
    var loggedInMND: Bool          // confirmed logged in MyNetDiary
    var notes: String

    // Relationship back to daily log
    var dailyLog: DailyLog?

    init(
        id: UUID = UUID(),
        slot: MealSlot,
        name: String,
        foods: [String] = [],
        estimatedCalories: Int = 0,
        estimatedProtein: Int = 0,
        estimatedCarbs: Int = 0,
        estimatedFat: Int = 0,
        plannedCalories: Int = 0,
        plannedProtein: Int = 0,
        completedAt: Date? = nil,
        loggedInMND: Bool = false,
        notes: String = "",
        dailyLog: DailyLog? = nil
    ) {
        self.id = id
        self.slot = slot
        self.name = name
        self.foods = foods
        self.estimatedCalories = estimatedCalories
        self.estimatedProtein = estimatedProtein
        self.estimatedCarbs = estimatedCarbs
        self.estimatedFat = estimatedFat
        self.plannedCalories = plannedCalories
        self.plannedProtein = plannedProtein
        self.completedAt = completedAt
        self.loggedInMND = loggedInMND
        self.notes = notes
        self.dailyLog = dailyLog
    }

    var isCompleted: Bool { completedAt != nil }

    static func from(template: MealTemplate) -> MealEvent {
        MealEvent(
            slot: template.slot,
            name: template.name,
            foods: template.suggestedFoods,
            estimatedCalories: template.calorieTarget,
            estimatedProtein: template.proteinTarget,
            estimatedCarbs: template.carbTarget,
            estimatedFat: template.fatTarget,
            plannedCalories: template.calorieTarget,
            plannedProtein: template.proteinTarget,
            notes: template.notes
        )
    }
}
