// DataSeeder.swift
// Seeds default data on first launch and provides sample data for previews.

import Foundation
import SwiftData

enum DataSeeder {

    // MARK: - First-Launch Setup
    /// Call this on app launch. Inserts defaults only if no data exists.
    static func seedIfNeeded(modelContext: ModelContext) {
        seedUserProfile(in: modelContext)
        seedGoalProfile(in: modelContext)
        seedMealTemplates(in: modelContext)
        seedReminderRules(in: modelContext)
        seedTDEEState(in: modelContext)
        seedIntegrationStatus(in: modelContext)
        ensureTodayLog(in: modelContext)
    }

    // MARK: - UserProfile
    static func seedUserProfile(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }
        let profile = UserProfile(
            heightInches: 73.5,
            currentWeight: 170.0,
            estimatedBodyFatPercent: 25.5,
            activityLevel: .sedentary
        )
        context.insert(profile)
        try? context.save()
    }

    // MARK: - GoalProfile
    static func seedGoalProfile(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<GoalProfile>())) ?? []
        guard existing.isEmpty else { return }
        let goal = GoalProfile()
        context.insert(goal)
        try? context.save()
    }

    // MARK: - Meal Templates
    static func seedMealTemplates(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MealTemplate>())) ?? []
        guard existing.isEmpty else { return }
        for template in MealTemplate.defaultTemplates() {
            context.insert(template)
        }
        try? context.save()
    }

    // MARK: - Reminder Rules
    static func seedReminderRules(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ReminderRule>())) ?? []
        guard existing.isEmpty else { return }
        for rule in ReminderRule.defaults() {
            context.insert(rule)
        }
        try? context.save()
    }

    // MARK: - TDEE State
    static func seedTDEEState(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<TDEEAdjustmentState>())) ?? []
        guard existing.isEmpty else { return }

        // Compute initial estimate from default profile values
        let lbm = CalculationEngine.leanBodyMass(weightLb: 170.0, bodyFatPercent: 25.5)
        let bmr = CalculationEngine.bmrKatchMcArdle(leanBodyMassLb: lbm)
        let tdee = CalculationEngine.tdee(bmr: bmr, activityMultiplier: ActivityLevel.sedentary.multiplier)

        let state = TDEEAdjustmentState(
            initialEstimatedTDEE: tdee,
            currentAdjustedTDEE: tdee,
            rollingExpectedWeightLoss: 1.4,
            explanationText: "Initial estimate based on 170 lb, 25.5% BF, sedentary activity."
        )
        context.insert(state)
        try? context.save()
    }

    // MARK: - Integration Status
    static func seedIntegrationStatus(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ExternalIntegrationStatus>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(ExternalIntegrationStatus())
        try? context.save()
    }

    // MARK: - Ensure Today's Log Exists
    @discardableResult
    static func ensureTodayLog(in context: ModelContext) -> DailyLog {
        let today = Calendar.current.startOfDay(for: .now)
        let pred = #Predicate<DailyLog> { $0.date == today }
        let existing = (try? context.fetch(FetchDescriptor<DailyLog>(predicate: pred))) ?? []
        if let log = existing.first { return log }

        // Pull targets from GoalProfile
        let goals = (try? context.fetch(FetchDescriptor<GoalProfile>())) ?? []
        let calorieTarget = goals.first?.dailyCalorieTarget ?? 1900
        let proteinTarget = goals.first?.dailyProteinTarget ?? 145

        let log = DailyLog(date: today, calorieTarget: calorieTarget, proteinTarget: proteinTarget)
        context.insert(log)

        // Add checklist items
        log.ensureChecklistItems()

        // Add meal events from default templates
        let templates = (try? context.fetch(FetchDescriptor<MealTemplate>())) ?? []
        log.ensureMealEvents(from: templates)

        try? context.save()
        return log
    }

    // MARK: - Preview / Sample Data
    static func sampleWeightEntries() -> [WeightEntry] {
        let today = Date()
        return (0..<28).map { i in
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let weight = 170.0 - (Double(i) * 0.09) + Double.random(in: -0.5...0.5)
            return WeightEntry(date: date, weightLb: weight.rounded(toPlaces: 1), bodyFatPercent: 25.5 - (Double(i) * 0.05))
        }.reversed()
    }

    static func sampleAdherenceMetrics() -> [AdherenceMetric] {
        let scores: [Double] = [85, 72, 90, 60, 78, 95, 88, 70, 85, 92, 65, 80, 75, 90, 88]
        let today = Date()
        return scores.enumerated().map { (i, score) in
            let date = Calendar.current.date(byAdding: .day, value: -(scores.count - 1 - i), to: today)!
            return AdherenceMetric(
                date: date,
                complianceScore: score,
                noRestaurantFood: score > 70,
                noDessert: score > 65,
                weighedIn: score > 60,
                hitProtein: score > 75,
                underCalories: score > 70,
                loggedAllMeals: score > 80,
                loggedInMND: score > 75,
                noUnplannedNightEating: score > 65
            )
        }
    }

    static func sampleDailyLog() -> DailyLog {
        let log = DailyLog(
            date: .now,
            calorieTarget: 1900,
            proteinTarget: 145,
            actualCalories: 1740,
            actualProtein: 138,
            hadRestaurantFood: false,
            hadDessert: false,
            loggedInMyNetDiary: true,
            complianceScore: 87.0
        )
        log.ensureChecklistItems()
        // Mark a few done
        log.checklist(for: .morningWeighIn)?.isCompleted = true
        log.checklist(for: .loggedMeal1)?.isCompleted = true
        log.checklist(for: .noRestaurantFood)?.isCompleted = true
        return log
    }

    static func sampleUserProfile() -> UserProfile {
        UserProfile(
            heightInches: 73.5,
            currentWeight: 170.0,
            estimatedBodyFatPercent: 25.5,
            activityLevel: .sedentary
        )
    }

    static func sampleGoalProfile() -> GoalProfile {
        GoalProfile()
    }
}

// MARK: - Double Helper
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
