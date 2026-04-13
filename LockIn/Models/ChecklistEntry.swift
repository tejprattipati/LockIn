// ChecklistEntry.swift
// A single checklist item for a day. Linked to DailyLog.

import Foundation
import SwiftData

@Model
final class ChecklistEntry {
    var id: UUID
    var category: ComplianceCategory
    var isCompleted: Bool
    var completedAt: Date?
    var dailyLog: DailyLog?

    init(
        id: UUID = UUID(),
        category: ComplianceCategory,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        dailyLog: DailyLog? = nil
    ) {
        self.id = id
        self.category = category
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.dailyLog = dailyLog
    }

    func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? .now : nil
    }

    var displayLabel: String { category.rawValue }
    var icon: String { category.icon }
    var weight: Double { category.weight }
}
