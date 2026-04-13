// GoalProfile.swift
// Singleton model storing the user's cut goal and daily nutrition targets.

import Foundation
import SwiftData

@Model
final class GoalProfile {
    var id: UUID
    var targetWeight: Double           // 147 lb
    var targetBodyFatPercent: Double   // 12%
    var goalDate: Date                 // August 8, 2026
    var intermediateDate: Date?        // May 17, 2026 — visible lean check-in

    // Daily nutrition defaults
    var dailyCalorieTarget: Int        // 1900
    var dailyProteinTarget: Int        // 145 g

    // Motivational / anti-failure content
    var motivationStatement: String
    var penaltyText: String
    var whyICantFailStatements: [String]
    var redFlagFoods: [String]
    var allowedLateNightOptions: [String]

    // Rate expectations
    var expectedWeeklyLossPounds: Double  // 1.4

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        targetWeight: Double = 147.0,
        targetBodyFatPercent: Double = 12.0,
        goalDate: Date = GoalProfile.defaultGoalDate,
        intermediateDate: Date? = GoalProfile.defaultIntermediateDate,
        dailyCalorieTarget: Int = 1900,
        dailyProteinTarget: Int = 145,
        motivationStatement: String = "147 lb, 12% body fat. August 8, 2026. No excuses.",
        penaltyText: String = "Every late-night order is a step away from the physique you actually want.",
        whyICantFailStatements: [String] = GoalProfile.defaultWhyStatements,
        redFlagFoods: [String] = GoalProfile.defaultRedFlagFoods,
        allowedLateNightOptions: [String] = GoalProfile.defaultLateNightOptions,
        expectedWeeklyLossPounds: Double = 1.4,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.targetWeight = targetWeight
        self.targetBodyFatPercent = targetBodyFatPercent
        self.goalDate = goalDate
        self.intermediateDate = intermediateDate
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyProteinTarget = dailyProteinTarget
        self.motivationStatement = motivationStatement
        self.penaltyText = penaltyText
        self.whyICantFailStatements = whyICantFailStatements
        self.redFlagFoods = redFlagFoods
        self.allowedLateNightOptions = allowedLateNightOptions
        self.expectedWeeklyLossPounds = expectedWeeklyLossPounds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Static Defaults
    static var defaultGoalDate: Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 8
        return Calendar.current.date(from: comps) ?? Date()
    }

    static var defaultIntermediateDate: Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 17
        return Calendar.current.date(from: comps) ?? Date()
    }

    static var defaultWhyStatements: [String] {
        [
            "I want to look noticeably leaner by May 17.",
            "Every night I resist is a real, measurable win.",
            "The plan only works if I follow it consistently.",
            "Late-night ordering is my main failure mode. I will not do it.",
            "I've set a specific weight and date. I will get there."
        ]
    }

    static var defaultRedFlagFoods: [String] {
        ["Pizza", "Chipotle late night", "DoorDash anything", "Ice cream", "Cookies",
         "Chips", "Fast food", "Late-night burgers", "Brownies", "Cake"]
    }

    static var defaultLateNightOptions: [String] {
        ["Cottage cheese (1 cup)", "Greek yogurt plain", "Protein shake (water)",
         "Hard-boiled eggs (2)", "Turkey slices", "Low-cal string cheese",
         "Baby carrots + hummus (small)"]
    }

    // MARK: - Computed
    var daysUntilGoal: Int {
        Calendar.current.dateComponents([.day], from: .now, to: goalDate).day ?? 0
    }

    var weeksUntilGoal: Double {
        Double(daysUntilGoal) / 7.0
    }

    var daysUntilIntermediate: Int? {
        guard let d = intermediateDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: d).day
    }
}
