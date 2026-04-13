// WeightEntry.swift
// Individual body weight measurement with optional body fat.

import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightLb: Double
    var bodyFatPercent: Double?   // optional manual or estimated
    var source: WeightSource
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        weightLb: Double,
        bodyFatPercent: Double? = nil,
        source: WeightSource = .manual,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.weightLb = weightLb
        self.bodyFatPercent = bodyFatPercent
        self.source = source
        self.notes = notes
    }

    var leanBodyMass: Double? {
        guard let bf = bodyFatPercent else { return nil }
        return weightLb * (1.0 - bf / 100.0)
    }

    var fatMass: Double? {
        guard let bf = bodyFatPercent else { return nil }
        return weightLb * (bf / 100.0)
    }
}
