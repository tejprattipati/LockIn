// WorkoutEntry.swift
// Log of a workout session.

import Foundation
import SwiftData

@Model
final class WorkoutEntry {
    var id: UUID
    var date: Date
    var type: WorkoutType
    var durationMinutes: Int
    var notes: String?
    var source: String   // "manual" or "HealthKit"

    init(
        id: UUID = UUID(),
        date: Date = .now,
        type: WorkoutType = .other,
        durationMinutes: Int = 0,
        notes: String? = nil,
        source: String = "manual"
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.source = source
    }
}
