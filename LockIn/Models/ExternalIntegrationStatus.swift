// ExternalIntegrationStatus.swift
// Tracks state of external integrations (MyNetDiary, HealthKit).

import Foundation
import SwiftData

@Model
final class ExternalIntegrationStatus {
    var id: UUID

    // HealthKit
    var healthKitEnabled: Bool
    var healthKitWeightPermission: Bool
    var healthKitStepsPermission: Bool
    var healthKitWorkoutsPermission: Bool
    var lastHealthKitSync: Date?

    // MyNetDiary
    var mndDeepLinkEnabled: Bool
    var mndConfiguredDeepLink: String?  // user-supplied if different from default
    var lastMNDOpenedAt: Date?

    var updatedAt: Date

    init(
        id: UUID = UUID(),
        healthKitEnabled: Bool = false,
        healthKitWeightPermission: Bool = false,
        healthKitStepsPermission: Bool = false,
        healthKitWorkoutsPermission: Bool = false,
        lastHealthKitSync: Date? = nil,
        mndDeepLinkEnabled: Bool = true,
        mndConfiguredDeepLink: String? = nil,
        lastMNDOpenedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.healthKitEnabled = healthKitEnabled
        self.healthKitWeightPermission = healthKitWeightPermission
        self.healthKitStepsPermission = healthKitStepsPermission
        self.healthKitWorkoutsPermission = healthKitWorkoutsPermission
        self.lastHealthKitSync = lastHealthKitSync
        self.mndDeepLinkEnabled = mndDeepLinkEnabled
        self.mndConfiguredDeepLink = mndConfiguredDeepLink
        self.lastMNDOpenedAt = lastMNDOpenedAt
        self.updatedAt = updatedAt
    }
}
