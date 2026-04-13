// Enums.swift
// LockIn — shared enum types used across models, services, and views.

import Foundation

// MARK: - Activity Level
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary      = "Sedentary (desk/student, minimal movement)"
    case lightlyActive  = "Lightly Active (1–2 days light exercise)"
    case moderatelyActive = "Moderately Active (3–5 days)"
    case veryActive     = "Very Active (6–7 days hard training)"
    case extraActive    = "Extra Active (physical job + daily training)"

    var id: String { rawValue }

    /// Conservative multipliers — intentionally lower than standard tables.
    var multiplier: Double {
        switch self {
        case .sedentary:        return 1.35
        case .lightlyActive:   return 1.45
        case .moderatelyActive: return 1.55
        case .veryActive:      return 1.65
        case .extraActive:     return 1.75
        }
    }

    var shortLabel: String {
        switch self {
        case .sedentary:        return "Sedentary"
        case .lightlyActive:   return "Lightly Active"
        case .moderatelyActive: return "Mod. Active"
        case .veryActive:      return "Very Active"
        case .extraActive:     return "Extra Active"
        }
    }
}

// MARK: - Meal Slot
enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case meal1         = "Meal 1"
    case meal2         = "Meal 2"
    case nightMeal     = "Planned Night Meal"
    case emergencySnack = "Emergency Snack"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .meal1:          return "sunrise"
        case .meal2:          return "sun.max"
        case .nightMeal:      return "moon"
        case .emergencySnack: return "shield"
        }
    }

    var sortOrder: Int {
        switch self {
        case .meal1:          return 0
        case .meal2:          return 1
        case .nightMeal:      return 2
        case .emergencySnack: return 3
        }
    }
}

// MARK: - Weight Source
enum WeightSource: String, Codable, CaseIterable {
    case manual    = "Manual"
    case healthKit = "Apple Health"
}

// MARK: - Compliance Category
enum ComplianceCategory: String, Codable, CaseIterable {
    case noRestaurantFood   = "No Restaurant Food"
    case noDessert          = "No Dessert"
    case loggedNightMeal    = "Logged Night Meal"
    case underCalorieTarget = "Under Calorie Target"
    case hitProteinTarget   = "Hit Protein Target"
    case morningWeighIn     = "Morning Weigh-In"
    case loggedMeal1        = "Logged Meal 1"
    case loggedMeal2        = "Logged Meal 2"
    case loggedInMND        = "Logged in MyNetDiary"
    case noUnplannedEating  = "No Unplanned Night Eating"
    case workoutCompleted   = "Workout Completed"
    case stepsGoalMet       = "Steps Goal Met"

    /// Weight used in compliance score calculation (higher = more important).
    var weight: Double {
        switch self {
        case .noRestaurantFood:   return 20
        case .noDessert:          return 15
        case .loggedNightMeal:    return 15
        case .underCalorieTarget: return 15
        case .hitProteinTarget:   return 10
        case .morningWeighIn:     return 10
        case .loggedMeal1:        return 5
        case .loggedMeal2:        return 5
        case .loggedInMND:        return 5
        case .noUnplannedEating:  return 10
        case .workoutCompleted:   return 5
        case .stepsGoalMet:       return 5
        }
    }

    var icon: String {
        switch self {
        case .noRestaurantFood:   return "xmark.seal.fill"
        case .noDessert:          return "xmark.circle"
        case .loggedNightMeal:    return "moon.fill"
        case .underCalorieTarget: return "flame"
        case .hitProteinTarget:   return "bolt.fill"
        case .morningWeighIn:     return "scalemass"
        case .loggedMeal1:        return "1.circle"
        case .loggedMeal2:        return "2.circle"
        case .loggedInMND:        return "checkmark.icloud"
        case .noUnplannedEating:  return "moon.zzz"
        case .workoutCompleted:   return "figure.run"
        case .stepsGoalMet:       return "figure.walk"
        }
    }
}

// MARK: - Workout Type
enum WorkoutType: String, Codable, CaseIterable {
    case basketball  = "Basketball"
    case lifting     = "Weight Training"
    case cardio      = "Cardio"
    case walk        = "Walk"
    case hiit        = "HIIT"
    case other       = "Other"

    var icon: String {
        switch self {
        case .basketball: return "basketball"
        case .lifting:    return "dumbbell"
        case .cardio:     return "figure.run"
        case .walk:       return "figure.walk"
        case .hiit:       return "bolt.heart"
        case .other:      return "sportscourt"
        }
    }
}

// MARK: - Reminder Type
enum ReminderType: String, Codable, CaseIterable {
    case morningWeighIn      = "Morning Weigh-In"
    case meal1               = "Log Meal 1"
    case meal2               = "Log Meal 2"
    case prePlanNightMeal    = "Plan Tonight's Meal"
    case nightAntiOrder      = "Anti-Order Warning"
    case bedtimeWrapUp       = "Bedtime Wrap-Up"
    case loggingReminder     = "Log in MyNetDiary"
    case workoutReminder     = "Workout Reminder"

    var defaultHour: Int {
        switch self {
        case .morningWeighIn:    return 7
        case .meal1:             return 9
        case .meal2:             return 13
        case .prePlanNightMeal:  return 19
        case .nightAntiOrder:    return 21
        case .bedtimeWrapUp:     return 23
        case .loggingReminder:   return 20
        case .workoutReminder:   return 17
        }
    }

    var defaultMinute: Int { return 0 }
}

// MARK: - Tonight Risk Level
enum NightRiskLevel: String {
    case low      = "LOW"
    case moderate = "MODERATE"
    case high     = "HIGH"
    case critical = "CRITICAL"

    var color: String {
        switch self {
        case .low:      return "green"
        case .moderate: return "yellow"
        case .high:     return "orange"
        case .critical: return "red"
        }
    }

    var message: String {
        switch self {
        case .low:
            return "You're on track. Stay disciplined through the night."
        case .moderate:
            return "Night risk elevated. Pre-plan your night meal now."
        case .high:
            return "High risk window. Avoid ordering. Stick to your plan."
        case .critical:
            return "CRITICAL: You are about to blow your cut. Open Intervene NOW."
        }
    }
}

// MARK: - Intervene Flow Step
enum InterveneStep: Int, CaseIterable {
    case askAboutNightMeal    = 0
    case askAboutProtein      = 1
    case askAboutMNDLogging   = 2
    case showProgress         = 3
    case showDamageComparison = 4
    case showReplacementFlow  = 5
    case timer                = 6
    case finalDecision        = 7
    case outcome              = 8
}

// MARK: - Adaptive Correction Direction
enum AdaptiveDirection: String, Codable {
    case tighten   = "Tightening (losing slower than expected)"
    case loosen    = "Loosening (losing faster than expected)"
    case onTrack   = "On Track"
    case insufficient = "Insufficient Data"
}
