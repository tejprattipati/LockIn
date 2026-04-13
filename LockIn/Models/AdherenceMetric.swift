// AdherenceMetric.swift
// Precomputed daily and weekly adherence metrics for fast display in charts.

import Foundation
import SwiftData

@Model
final class AdherenceMetric {
    var id: UUID
    var date: Date          // start of the day this covers
    var complianceScore: Double     // 0–100
    var calorieAdherence: Double?   // 0–100 (nil if not logged)
    var proteinAdherence: Double?
    var noRestaurantFood: Bool
    var noDessert: Bool
    var weighedIn: Bool
    var hitProtein: Bool
    var underCalories: Bool
    var loggedAllMeals: Bool
    var loggedInMND: Bool
    var noUnplannedNightEating: Bool
    var workoutCompleted: Bool
    var resistedLateNightOrder: Bool?   // nil = no trigger

    init(
        id: UUID = UUID(),
        date: Date = .now,
        complianceScore: Double = 0,
        calorieAdherence: Double? = nil,
        proteinAdherence: Double? = nil,
        noRestaurantFood: Bool = false,
        noDessert: Bool = false,
        weighedIn: Bool = false,
        hitProtein: Bool = false,
        underCalories: Bool = false,
        loggedAllMeals: Bool = false,
        loggedInMND: Bool = false,
        noUnplannedNightEating: Bool = false,
        workoutCompleted: Bool = false,
        resistedLateNightOrder: Bool? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.complianceScore = complianceScore
        self.calorieAdherence = calorieAdherence
        self.proteinAdherence = proteinAdherence
        self.noRestaurantFood = noRestaurantFood
        self.noDessert = noDessert
        self.weighedIn = weighedIn
        self.hitProtein = hitProtein
        self.underCalories = underCalories
        self.loggedAllMeals = loggedAllMeals
        self.loggedInMND = loggedInMND
        self.noUnplannedNightEating = noUnplannedNightEating
        self.workoutCompleted = workoutCompleted
        self.resistedLateNightOrder = resistedLateNightOrder
    }

    static func from(log: DailyLog) -> AdherenceMetric {
        let score = ComplianceCalculator.score(for: log)

        let calorieAdh: Double? = {
            guard let actual = log.actualCalories, log.calorieTarget > 0 else { return nil }
            let ratio = Double(actual) / Double(log.calorieTarget)
            return max(0, min(100, (1.0 - max(0, ratio - 1.0)) * 100))
        }()

        let proteinAdh: Double? = {
            guard let actual = log.actualProtein, log.proteinTarget > 0 else { return nil }
            return min(100, Double(actual) / Double(log.proteinTarget) * 100)
        }()

        let meal1Done = log.checklist(for: .loggedMeal1)?.isCompleted ?? false
        let meal2Done = log.checklist(for: .loggedMeal2)?.isCompleted ?? false
        let nightDone = log.checklist(for: .loggedNightMeal)?.isCompleted ?? false
        let loggedAll = meal1Done && meal2Done && nightDone

        return AdherenceMetric(
            date: log.date,
            complianceScore: score,
            calorieAdherence: calorieAdh,
            proteinAdherence: proteinAdh,
            noRestaurantFood: !log.hadRestaurantFood,
            noDessert: !log.hadDessert,
            weighedIn: log.checklist(for: .morningWeighIn)?.isCompleted ?? false,
            hitProtein: log.checklist(for: .hitProteinTarget)?.isCompleted ?? false,
            underCalories: log.checklist(for: .underCalorieTarget)?.isCompleted ?? false,
            loggedAllMeals: loggedAll,
            loggedInMND: log.loggedInMyNetDiary,
            noUnplannedNightEating: !log.hadUnplannedNightEating,
            workoutCompleted: log.checklist(for: .workoutCompleted)?.isCompleted ?? false,
            resistedLateNightOrder: log.resistedLateNightOrder
        )
    }
}

// MARK: - Compliance Calculator (static helper)
enum ComplianceCalculator {
    static func score(for log: DailyLog) -> Double {
        var earned = 0.0
        var total = 0.0

        for item in log.checklistItems {
            total += item.weight
            if item.isCompleted { earned += item.weight }
        }

        // Penalty for explicit failures
        if log.hadRestaurantFood { earned -= 20 }
        if log.hadDessert        { earned -= 15 }
        if log.hadUnplannedNightEating { earned -= 10 }

        guard total > 0 else { return 0 }
        return max(0, min(100, (earned / total) * 100))
    }
}
