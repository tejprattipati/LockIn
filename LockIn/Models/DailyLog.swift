// DailyLog.swift
// The main daily record: one per calendar day.
// Holds checklist, meal events, and computed compliance.

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date             // normalized to midnight (start of day)
    var calorieTarget: Int
    var proteinTarget: Int

    // Actual logged values (pulled from MND manually or entered)
    var actualCalories: Int?
    var actualProtein: Int?

    // Late-night failure flags
    var hadRestaurantFood: Bool
    var hadDessert: Bool
    var hadUnplannedNightEating: Bool
    var usedEmergencySnack: Bool
    var emergencySnackCount: Int

    // App integrations
    var loggedInMyNetDiary: Bool

    // Intervention tracking
    var interveneSessionCount: Int
    var lastInterveneAt: Date?
    var resistedLateNightOrder: Bool?  // nil = not triggered, true/false = outcome

    // Notes
    var notes: String

    // Computed compliance (cached)
    var complianceScore: Double

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \MealEvent.dailyLog)
    var mealEvents: [MealEvent]

    @Relationship(deleteRule: .cascade, inverse: \ChecklistEntry.dailyLog)
    var checklistItems: [ChecklistEntry]

    init(
        id: UUID = UUID(),
        date: Date = .now,
        calorieTarget: Int = 1900,
        proteinTarget: Int = 145,
        actualCalories: Int? = nil,
        actualProtein: Int? = nil,
        hadRestaurantFood: Bool = false,
        hadDessert: Bool = false,
        hadUnplannedNightEating: Bool = false,
        usedEmergencySnack: Bool = false,
        emergencySnackCount: Int = 0,
        loggedInMyNetDiary: Bool = false,
        interveneSessionCount: Int = 0,
        lastInterveneAt: Date? = nil,
        resistedLateNightOrder: Bool? = nil,
        notes: String = "",
        complianceScore: Double = 0,
        mealEvents: [MealEvent] = [],
        checklistItems: [ChecklistEntry] = []
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.actualCalories = actualCalories
        self.actualProtein = actualProtein
        self.hadRestaurantFood = hadRestaurantFood
        self.hadDessert = hadDessert
        self.hadUnplannedNightEating = hadUnplannedNightEating
        self.usedEmergencySnack = usedEmergencySnack
        self.emergencySnackCount = emergencySnackCount
        self.loggedInMyNetDiary = loggedInMyNetDiary
        self.interveneSessionCount = interveneSessionCount
        self.lastInterveneAt = lastInterveneAt
        self.resistedLateNightOrder = resistedLateNightOrder
        self.notes = notes
        self.complianceScore = complianceScore
        self.mealEvents = mealEvents
        self.checklistItems = checklistItems
    }

    // MARK: - Convenience

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var meal1: MealEvent? {
        mealEvents.first { $0.slot == .meal1 }
    }

    var meal2: MealEvent? {
        mealEvents.first { $0.slot == .meal2 }
    }

    var nightMeal: MealEvent? {
        mealEvents.first { $0.slot == .nightMeal }
    }

    var emergencySnack: MealEvent? {
        mealEvents.first { $0.slot == .emergencySnack }
    }

    func checklist(for category: ComplianceCategory) -> ChecklistEntry? {
        checklistItems.first { $0.category == category }
    }

    var isWeighedIn: Bool {
        checklist(for: .morningWeighIn)?.isCompleted ?? false
    }

    /// Populate checklist from all categories if not yet created.
    func ensureChecklistItems() {
        let existing = Set(checklistItems.map { $0.category })
        for cat in ComplianceCategory.allCases where !existing.contains(cat) {
            let entry = ChecklistEntry(category: cat, dailyLog: self)
            checklistItems.append(entry)
        }
    }

    /// Populate meal events from templates.
    func ensureMealEvents(from templates: [MealTemplate]) {
        let existingSlots = Set(mealEvents.map { $0.slot })
        for template in templates where template.isActiveDefault && !existingSlots.contains(template.slot) {
            let event = MealEvent.from(template: template)
            event.dailyLog = self
            mealEvents.append(event)
        }
    }
}
