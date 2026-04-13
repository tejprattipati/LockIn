// CalculationEngine.swift
// Conservative BMR/TDEE/LBM math + adaptive TDEE correction.
// All formulas err on the side of underestimating maintenance to prevent
// the user from overestimating how much they can eat.

import Foundation
import SwiftData

// MARK: - Body Composition Result
struct BodyCompositionResult {
    let weightLb: Double
    let heightInches: Double
    let bodyFatPercent: Double
    let leanBodyMassLb: Double
    let fatMassLb: Double
    let leanBodyMassKg: Double
    let bmrKcal: Double             // using Katch-McArdle if LBM available
    let bmrMethod: String
    let tdeeKcal: Double            // conservative TDEE
    let activityMultiplier: Double
    let currentDeficit: Double      // kcal/day below TDEE
    let targetCalories: Int
    let expectedWeeklyLossLb: Double
    let weeksToGoal: Double
    let projectedGoalDate: Date
    let explanationLines: [String]
}

// MARK: - Projection Result
struct GoalProjection {
    let currentWeight: Double
    let targetWeight: Double
    let poundsToLose: Double
    let weeklyLossRate: Double
    let weeksRequired: Double
    let projectedDate: Date
    let daysRemaining: Int
    let isOnTrack: Bool            // based on current 7-day avg trend
    let dailyDeficitRequired: Int  // to meet deadline
}

// MARK: - Calculation Engine
enum CalculationEngine {

    // MARK: - Unit Helpers
    static func lbToKg(_ lb: Double) -> Double { lb * 0.453592 }
    static func kgToLb(_ kg: Double) -> Double { kg * 2.20462 }
    static func inchesToCm(_ inches: Double) -> Double { inches * 2.54 }

    // MARK: - Lean Body Mass
    /// Returns LBM in pounds given total weight and body fat %.
    static func leanBodyMass(weightLb: Double, bodyFatPercent: Double) -> Double {
        weightLb * (1.0 - bodyFatPercent / 100.0)
    }

    // MARK: - BMR: Katch-McArdle (preferred — uses LBM)
    /// Returns BMR in kcal/day. Most accurate when body fat % is known.
    /// Formula: BMR = 370 + (21.6 × LBM in kg)
    static func bmrKatchMcArdle(leanBodyMassLb: Double) -> Double {
        let lbmKg = lbToKg(leanBodyMassLb)
        return 370.0 + (21.6 * lbmKg)
    }

    // MARK: - BMR: Mifflin-St Jeor (fallback — no body fat needed)
    /// Returns BMR in kcal/day for males.
    /// Formula: (10 × weight_kg) + (6.25 × height_cm) − (5 × age) + 5
    static func bmrMifflinStJeor(weightLb: Double, heightInches: Double, ageYears: Int) -> Double {
        let weightKg = lbToKg(weightLb)
        let heightCm = inchesToCm(heightInches)
        return (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * Double(ageYears)) + 5.0
    }

    // MARK: - Conservative TDEE
    /// Applies a conservative activity multiplier to BMR.
    /// We intentionally use slightly lower multipliers than standard tables.
    static func tdee(bmr: Double, activityMultiplier: Double) -> Double {
        // Apply an additional 5% conservative haircut on top of the user-selected multiplier.
        let conservativeHaircut = 0.95
        return bmr * activityMultiplier * conservativeHaircut
    }

    // MARK: - Main Compute Function
    static func compute(
        weightLb: Double,
        heightInches: Double,
        bodyFatPercent: Double,
        activityLevel: ActivityLevel,
        targetCalories: Int
    ) -> BodyCompositionResult {
        let lbm = leanBodyMass(weightLb: weightLb, bodyFatPercent: bodyFatPercent)
        let fatMass = weightLb - lbm
        let lbmKg = lbToKg(lbm)

        let bmr = bmrKatchMcArdle(leanBodyMassLb: lbm)
        let method = "Katch-McArdle (LBM = \(String(format: "%.1f", lbm)) lb)"
        let multiplier = activityLevel.multiplier
        let tdeeVal = tdee(bmr: bmr, activityMultiplier: multiplier)
        let deficit = tdeeVal - Double(targetCalories)
        let weeklyLoss = (deficit * 7.0) / 3500.0  // 3500 kcal ≈ 1 lb fat

        let poundsToGoal: Double = weightLb - 147.0
        let weeksNeeded = poundsToGoal / max(0.1, weeklyLoss)
        let projectedDate = Calendar.current.date(byAdding: .day, value: Int(weeksNeeded * 7), to: .now) ?? .now

        let explanation = buildExplanation(
            weightLb: weightLb,
            heightInches: heightInches,
            bodyFatPercent: bodyFatPercent,
            lbm: lbm,
            fatMass: fatMass,
            lbmKg: lbmKg,
            bmr: bmr,
            method: method,
            multiplier: multiplier,
            tdee: tdeeVal,
            targetCalories: targetCalories,
            deficit: deficit,
            weeklyLoss: weeklyLoss
        )

        return BodyCompositionResult(
            weightLb: weightLb,
            heightInches: heightInches,
            bodyFatPercent: bodyFatPercent,
            leanBodyMassLb: lbm,
            fatMassLb: fatMass,
            leanBodyMassKg: lbmKg,
            bmrKcal: bmr,
            bmrMethod: method,
            tdeeKcal: tdeeVal,
            activityMultiplier: multiplier,
            currentDeficit: deficit,
            targetCalories: targetCalories,
            expectedWeeklyLossLb: weeklyLoss,
            weeksToGoal: weeksNeeded,
            projectedGoalDate: projectedDate,
            explanationLines: explanation
        )
    }

    // MARK: - Adaptive TDEE Correction
    /// Compares expected vs. actual 7-day average weight change.
    /// Returns a conservative correction in kcal/day.
    ///
    /// Logic:
    /// - If actual loss is significantly less than expected → real TDEE is lower than estimated.
    ///   We tighten the estimate (lower TDEE by a fraction of the inferred error).
    /// - If actual loss is significantly more than expected → real TDEE is higher.
    ///   We loosen the estimate (raise TDEE cautiously, max 50 kcal/day per evaluation).
    /// - We use a dampening factor to avoid reacting to noise.
    /// - Minimum 10 days of data required before any adjustment.
    static func adaptiveCorrection(
        state: TDEEAdjustmentState,
        weightEntries: [WeightEntry],
        targetCalories: Int,
        minDaysRequired: Int = 10,
        dampingFactor: Double = 0.4,
        maxCorrectionPerCycle: Double = 75.0
    ) -> (newTDEE: Double, checkpoint: WeeklyCheckpoint?, direction: AdaptiveDirection, explanation: String) {

        // Need enough data to compute 7-day averages
        guard weightEntries.count >= minDaysRequired else {
            return (
                state.currentAdjustedTDEE,
                nil,
                .insufficient,
                "Need at least \(minDaysRequired) weigh-ins before adaptive correction activates. Currently have \(weightEntries.count)."
            )
        }

        let sorted = weightEntries.sorted { $0.date < $1.date }

        // Build 7-day rolling averages
        guard let avgStart = sevenDayAverage(from: sorted, endingAt: sorted.first!.date, offset: 7),
              let avgEnd = sevenDayAverage(from: sorted, endingAt: sorted.last!.date, offset: 0) else {
            return (state.currentAdjustedTDEE, nil, .insufficient, "Insufficient spread of weigh-ins for 7-day averages.")
        }

        let daySpan = Calendar.current.dateComponents([.day], from: sorted.first!.date, to: sorted.last!.date).day ?? 1
        let weekSpan = Double(daySpan) / 7.0

        let actualLoss = avgStart - avgEnd  // positive = lost weight
        let expectedLossTotal = state.rollingExpectedWeightLoss * weekSpan

        let discrepancy = actualLoss - expectedLossTotal  // negative = losing slower than expected

        // Infer TDEE error.
        // If we expected to lose X lb but only lost Y lb, the caloric surplus equivalent is:
        // error_kcal = (X - Y) * 3500 / days = energy we overestimated maintenance by
        let errorKcalPerDay = (discrepancy * 3500.0) / Double(daySpan)

        // Apply damping and cap
        var rawCorrection = errorKcalPerDay * dampingFactor
        rawCorrection = max(-maxCorrectionPerCycle, min(maxCorrectionPerCycle, rawCorrection))

        // Only apply if meaningful (>15 kcal/day change warranted)
        let threshold = 15.0
        let appliedCorrection: Double
        let direction: AdaptiveDirection

        if abs(rawCorrection) < threshold {
            appliedCorrection = 0
            direction = .onTrack
        } else if rawCorrection < 0 {
            // Losing slower than expected → real TDEE is lower → tighten (lower) estimate
            appliedCorrection = rawCorrection
            direction = .tighten
        } else {
            // Losing faster than expected → real TDEE is higher → loosen estimate
            // Be extra conservative loosening (half the correction)
            appliedCorrection = rawCorrection * 0.5
            direction = .loosen
        }

        let newTDEE = state.currentAdjustedTDEE + appliedCorrection

        let checkpoint = WeeklyCheckpoint(
            weekStartDate: sorted.first!.date,
            sevenDayAvgStart: avgStart,
            sevenDayAvgEnd: avgEnd,
            actualLossPounds: actualLoss,
            expectedLossPounds: expectedLossTotal,
            deficitAssumption: newTDEE - Double(targetCalories),
            correctionApplied: appliedCorrection,
            notes: direction == .onTrack ? "No correction needed." : "\(direction.rawValue): applied \(String(format: "%+.0f", appliedCorrection)) kcal/day."
        )

        let explanation = buildAdaptiveExplanation(
            avgStart: avgStart,
            avgEnd: avgEnd,
            actualLoss: actualLoss,
            expectedLoss: expectedLossTotal,
            weekSpan: weekSpan,
            errorKcalPerDay: errorKcalPerDay,
            rawCorrection: rawCorrection,
            appliedCorrection: appliedCorrection,
            direction: direction,
            newTDEE: newTDEE
        )

        return (newTDEE, checkpoint, direction, explanation)
    }

    // MARK: - 7-Day Average Helper
    static func sevenDayAverage(from entries: [WeightEntry], endingAt date: Date, offset: Int) -> Double? {
        let endDate = Calendar.current.date(byAdding: .day, value: offset, to: date) ?? date
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: endDate)!
        let window = entries.filter { $0.date >= startDate && $0.date <= endDate }
        guard !window.isEmpty else { return nil }
        return window.map { $0.weightLb }.reduce(0, +) / Double(window.count)
    }

    static func currentSevenDayAverage(from entries: [WeightEntry]) -> Double? {
        let sorted = entries.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(7))
        guard !recent.isEmpty else { return nil }
        return recent.map { $0.weightLb }.reduce(0, +) / Double(recent.count)
    }

    // MARK: - Goal Projection
    static func goalProjection(
        currentWeight: Double,
        targetWeight: Double,
        goalDate: Date,
        weeklyLossRate: Double,
        sevenDayAvg: Double?
    ) -> GoalProjection {
        let poundsToLose = currentWeight - targetWeight
        let weeksRequired = poundsToLose / max(0.01, weeklyLossRate)
        let projectedDate = Calendar.current.date(byAdding: .day, value: Int(weeksRequired * 7), to: .now) ?? .now
        let daysRemaining = Calendar.current.dateComponents([.day], from: .now, to: goalDate).day ?? 0

        // On track if projected date is on or before goal date
        let isOnTrack = projectedDate <= goalDate

        // Required deficit to hit goal date exactly
        let daysLeft = max(1, daysRemaining)
        let requiredWeeklyLoss = (poundsToLose / Double(daysLeft)) * 7.0
        let requiredDailyDeficit = Int(requiredWeeklyLoss * 3500.0 / 7.0)

        return GoalProjection(
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            poundsToLose: poundsToLose,
            weeklyLossRate: weeklyLossRate,
            weeksRequired: weeksRequired,
            projectedDate: projectedDate,
            daysRemaining: daysRemaining,
            isOnTrack: isOnTrack,
            dailyDeficitRequired: requiredDailyDeficit
        )
    }

    // MARK: - Tonight Risk Level
    static func nightRiskLevel(
        currentHour: Int,
        actualCaloriesToday: Int?,
        proteinHit: Bool,
        nightMealPlanned: Bool,
        hadPreviousIntervention: Bool
    ) -> NightRiskLevel {
        var riskScore = 0

        // Time-based risk
        if currentHour >= 22 { riskScore += 3 }
        else if currentHour >= 20 { riskScore += 2 }
        else if currentHour >= 18 { riskScore += 1 }

        // Calorie status
        if let cal = actualCaloriesToday {
            if cal < 800 { riskScore += 3 }  // underate badly, very hungry tonight
            else if cal < 1200 { riskScore += 2 }
            else if cal < 1600 { riskScore += 1 }
        } else {
            riskScore += 2  // didn't log = unknown, assume risk
        }

        // Protein status
        if !proteinHit { riskScore += 2 }

        // Night meal
        if !nightMealPlanned { riskScore += 2 }

        // Prior intervention today
        if hadPreviousIntervention { riskScore += 1 }

        switch riskScore {
        case 0...2: return .low
        case 3...4: return .moderate
        case 5...7: return .high
        default:    return .critical
        }
    }

    // MARK: - Private: Explanation builders
    private static func buildExplanation(
        weightLb: Double, heightInches: Double, bodyFatPercent: Double,
        lbm: Double, fatMass: Double, lbmKg: Double,
        bmr: Double, method: String, multiplier: Double, tdee: Double,
        targetCalories: Int, deficit: Double, weeklyLoss: Double
    ) -> [String] {
        [
            "Weight: \(String(format: "%.1f", weightLb)) lb",
            "Body Fat: \(String(format: "%.1f", bodyFatPercent))%",
            "Lean Body Mass: \(String(format: "%.1f", lbm)) lb (\(String(format: "%.1f", lbmKg)) kg)",
            "Fat Mass: \(String(format: "%.1f", fatMass)) lb",
            "BMR: \(String(format: "%.0f", bmr)) kcal/day — \(method)",
            "Activity Multiplier: ×\(String(format: "%.2f", multiplier)) (with 5% conservative haircut applied)",
            "Conservative TDEE: \(String(format: "%.0f", tdee)) kcal/day",
            "Target Calories: \(targetCalories) kcal/day",
            "Daily Deficit: \(String(format: "%.0f", deficit)) kcal/day",
            "Expected Weekly Loss: \(String(format: "%.2f", weeklyLoss)) lb/week",
            "Note: TDEE is intentionally underestimated. The adaptive engine will refine this over time."
        ]
    }

    private static func buildAdaptiveExplanation(
        avgStart: Double, avgEnd: Double, actualLoss: Double, expectedLoss: Double,
        weekSpan: Double, errorKcalPerDay: Double, rawCorrection: Double,
        appliedCorrection: Double, direction: AdaptiveDirection, newTDEE: Double
    ) -> String {
        """
        Adaptive TDEE Evaluation (\(String(format: "%.1f", weekSpan)) weeks of data):
        • 7-day avg at start: \(String(format: "%.1f", avgStart)) lb
        • 7-day avg at end: \(String(format: "%.1f", avgEnd)) lb
        • Actual loss: \(String(format: "%.2f", actualLoss)) lb
        • Expected loss: \(String(format: "%.2f", expectedLoss)) lb
        • Discrepancy: \(String(format: "%+.2f", actualLoss - expectedLoss)) lb
        • Implied TDEE error: \(String(format: "%+.0f", errorKcalPerDay)) kcal/day
        • Dampened correction: \(String(format: "%+.0f", rawCorrection)) kcal/day
        • Applied correction: \(String(format: "%+.0f", appliedCorrection)) kcal/day (40% damping, max ±75)
        • Direction: \(direction.rawValue)
        • New TDEE estimate: \(String(format: "%.0f", newTDEE)) kcal/day
        """
    }
}
