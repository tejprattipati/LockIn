// UserProfile.swift
// Singleton model representing the user's physical stats.
// Only one record should ever exist in the store.

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var heightInches: Double       // 73.5 for 6'1.5"
    var currentWeight: Double      // pounds, updated whenever they log
    var estimatedBodyFatPercent: Double  // 0–100, e.g. 25.5
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
        self.activityLevel = activityLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
