// ReminderRule.swift
// Stores user-configured notification schedule.

import Foundation
import SwiftData

@Model
final class ReminderRule {
    var id: UUID
    var type: ReminderType
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var customTitle: String?
    var customBody: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: ReminderType,
        isEnabled: Bool = true,
        hour: Int? = nil,
        minute: Int = 0,
        customTitle: String? = nil,
        customBody: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.hour = hour ?? type.defaultHour
        self.minute = minute
        self.customTitle = customTitle
        self.customBody = customBody
        self.updatedAt = updatedAt
    }

    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(ampm)"
    }

    static func defaults() -> [ReminderRule] {
        ReminderType.allCases.map { ReminderRule(type: $0) }
    }
}
