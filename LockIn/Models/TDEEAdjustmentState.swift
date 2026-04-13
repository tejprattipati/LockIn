// TDEEAdjustmentState.swift
// Tracks the adaptive TDEE correction engine state.
// Updated weekly based on actual vs. expected weight loss.

import Foundation
import SwiftData

@Model
final class TDEEAdjustmentState {
    var id: UUID

    // Core estimates (set by CalculationEngine on first run)
    var initialEstimatedTDEE: Double        // kcal/day at start
    var currentAdjustedTDEE: Double         // current best estimate
    var cumulativeAdjustment: Double        // how much we've shifted (+ or -)

    // Weekly tracking
    var weeklyCheckpoints: [WeeklyCheckpoint]  // stored as Codable
    var lastEvaluationDate: Date?

    // Trend analysis
    var rollingExpectedWeightLoss: Double    // lb/week from math
    var rollingActualWeightLoss: Double?     // lb/week from data (nil if <2 weigh-ins)
    var correctionDirection: AdaptiveDirection
    var correctionMagnitudeKcal: Double      // most recent correction applied

    // For display
    var explanationText: String

    var updatedAt: Date

    init(
        id: UUID = UUID(),
        initialEstimatedTDEE: Double = 2200,
        currentAdjustedTDEE: Double = 2200,
        cumulativeAdjustment: Double = 0,
        weeklyCheckpoints: [WeeklyCheckpoint] = [],
        lastEvaluationDate: Date? = nil,
        rollingExpectedWeightLoss: Double = 1.4,
        rollingActualWeightLoss: Double? = nil,
        correctionDirection: AdaptiveDirection = .insufficient,
        correctionMagnitudeKcal: Double = 0,
        explanationText: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.initialEstimatedTDEE = initialEstimatedTDEE
        self.currentAdjustedTDEE = currentAdjustedTDEE
        self.cumulativeAdjustment = cumulativeAdjustment
        self.weeklyCheckpoints = weeklyCheckpoints
        self.lastEvaluationDate = lastEvaluationDate
        self.rollingExpectedWeightLoss = rollingExpectedWeightLoss
        self.rollingActualWeightLoss = rollingActualWeightLoss
        self.correctionDirection = correctionDirection
        self.correctionMagnitudeKcal = correctionMagnitudeKcal
        self.explanationText = explanationText
        self.updatedAt = updatedAt
    }
}

// MARK: - Weekly Checkpoint (Codable value type stored as array)
struct WeeklyCheckpoint: Codable, Identifiable {
    var id: UUID = UUID()
    var weekStartDate: Date
    var sevenDayAvgStart: Double   // 7-day avg weight at start of window
    var sevenDayAvgEnd: Double     // 7-day avg weight at end of window
    var actualLossPounds: Double   // positive = lost weight
    var expectedLossPounds: Double
    var deficitAssumption: Double  // kcal/day deficit used
    var correctionApplied: Double  // kcal/day adjustment made
    var notes: String

    var discrepancy: Double { actualLossPounds - expectedLossPounds }

    var performanceLabel: String {
        if discrepancy > 0.2 { return "Faster than expected" }
        if discrepancy < -0.2 { return "Slower than expected" }
        return "On track"
    }
}
