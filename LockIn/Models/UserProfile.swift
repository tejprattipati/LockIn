// UserProfile.swift
// Singleton model representing the user's physical stats.
// Only one record should ever exist in the store.
//
// Body fat tracking:
//   leanBodyMassLb is the stored anchor — set when the user manually enters a BF%.
//   estimatedBodyFatPercent is derived from (currentWeight - lbm) / currentWeight
//   after every weigh-in, so fat mass (not %) is what actually changes over time.

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var heightInches: Double       // 73.5 for 6'1.5"
    var currentWeight: Double      // pounds, updated whenever they log
    var estimatedBodyFatPercent: Double  // derived: (weight - lbm) / weight * 100
    var leanBodyMassLb: Double     // anchor — held constant between manual BF% updates
    var activityLevel: ActivityLevel
    var createdAt: Date
    var updatedAt: Date

    // Derived — cached for display, recomputed by CalculationEngine
    var cachedLBM: Double?
    var cachedFatMass: Double?
    var cachedBMR: Double?
    var cachedTDEE: Double?

    init(
        id: UUID = UUID(),
        heightInches: Double = 73.5,
        currentWeight: Double = 170.0,
        estimatedBodyFatPercent: Double = 25.5,
        activityLevel: ActivityLevel = .sedentary,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.heightInches = heightInches
        self.currentWeight = currentWeight
        self.estimatedBodyFatPercent = estimatedBodyFatPercent
        // Anchor LBM from initial weight + BF%
        self.leanBodyMassLb = currentWeight * (1.0 - estimatedBodyFatPercent / 100.0)
        self.activityLevel = activityLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Derived fat mass (always accurate)
    var fatMassLb: Double { max(0, currentWeight - leanBodyMassLb) }

    // MARK: - Re-anchor LBM when user manually sets a new BF%
    // Call this from ProfileEditorSheet when saving a manual BF% override.
    func setBodyFatPercent(_ bf: Double, atWeight weight: Double) {
        estimatedBodyFatPercent = bf
        leanBodyMassLb = weight * (1.0 - bf / 100.0)
        updatedAt = .now
    }

    // MARK: - Update BF% after a weigh-in (holds LBM constant, fat mass changes)
    func updateWeightKeepingLBM(_ newWeight: Double) {
        // Bootstrap LBM if it's zero (existing records before this field was added)
        if leanBodyMassLb <= 0 {
            leanBodyMassLb = currentWeight * (1.0 - estimatedBodyFatPercent / 100.0)
        }
        currentWeight = newWeight
        estimatedBodyFatPercent = max(3, min(60, (newWeight - leanBodyMassLb) / newWeight * 100.0))
        updatedAt = .now
    }

    // MARK: - Convenience
    var heightFeetInches: String {
        let feet = Int(heightInches) / 12
        let inches = Int(heightInches) % 12
        let fraction = heightInches - Double(Int(heightInches))
        if fraction > 0.4 {
            return "\(feet)'\(inches).5\""
        }
        return "\(feet)'\(inches)\""
    }
}
