// MealTemplate.swift
// Default and named meal templates for each slot.
// One set of templates is "active default"; individual days can override.

import Foundation
import SwiftData

@Model
final class MealTemplate {
    var id: UUID
    var name: String
    var slot: MealSlot
    var suggestedFoods: [String]
    var calorieTarget: Int
    var proteinTarget: Int   // grams
    var carbTarget: Int
    var fatTarget: Int
    var notes: String
    var isActiveDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        slot: MealSlot,
        suggestedFoods: [String] = [],
        calorieTarget: Int = 0,
        proteinTarget: Int = 0,
        carbTarget: Int = 0,
        fatTarget: Int = 0,
        notes: String = "",
        isActiveDefault: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.suggestedFoods = suggestedFoods
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbTarget = carbTarget
        self.fatTarget = fatTarget
        self.notes = notes
        self.isActiveDefault = isActiveDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Factory defaults
    static func defaultTemplates() -> [MealTemplate] {
        [
            MealTemplate(
                name: "Meal 1 — Morning",
                slot: .meal1,
                suggestedFoods: [
                    "Eggs (3–4 whole)",
                    "Oatmeal (1/2 cup dry)",
                    "Greek yogurt (plain, 1 cup)",
                    "Banana or apple"
                ],
                calorieTarget: 550,
                proteinTarget: 40,
                notes: "Eat within 1 hour of waking. Prioritize protein."
            ),
            MealTemplate(
                name: "Meal 2 — Afternoon",
                slot: .meal2,
                suggestedFoods: [
                    "Chicken breast (6–7 oz)",
                    "Rice (3/4 cup cooked) or sweet potato",
                    "Vegetables (broccoli/salad)",
                    "Olive oil (1 tsp)"
                ],
                calorieTarget: 650,
                proteinTarget: 55,
                notes: "This is your biggest meal. Eat before 4pm ideally."
            ),
            MealTemplate(
                name: "Planned Night Meal",
                slot: .nightMeal,
                suggestedFoods: [
                    "Cottage cheese (1.5 cups)",
                    "Protein shake in water",
                    "Turkey or tuna (4 oz)",
                    "Cucumber / low-cal veggies"
                ],
                calorieTarget: 500,
                proteinTarget: 45,
                notes: "Pre-plan this before 7pm. Non-negotiable. Prevents late ordering."
            ),
            MealTemplate(
                name: "Emergency Snack",
                slot: .emergencySnack,
                suggestedFoods: [
                    "String cheese (1–2)",
                    "Hard-boiled eggs (2)",
                    "Greek yogurt (plain, small)",
                    "Protein bar (under 200 kcal)"
                ],
                calorieTarget: 150,
                proteinTarget: 15,
                notes: "Use only if still hungry after night meal. One item only."
            )
        ]
    }
}
