// HealthKitManager.swift
// Handles HealthKit integration: reading weight, steps, and workouts.
// Uses callback-based authorization (more reliable than async throws form on device).
// Gracefully degrades if permissions are denied or HealthKit is unavailable.

import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    @Published var isAvailable: Bool = false
    @Published var weightPermissionGranted: Bool = false
    @Published var stepsPermissionGranted: Bool = false
    @Published var workoutsPermissionGranted: Bool = false
    @Published var lastSyncDate: Date?
    @Published var latestWeightLb: Double?
    @Published var todaySteps: Int?

    // MARK: - HK Types
    private var weightType: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .bodyMass) }
    private var stepsType: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .stepCount) }
    private var workoutType: HKObjectType { HKObjectType.workoutType() }

    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Authorization
    // Uses callback form wrapped in withCheckedContinuation — more reliable on device
    // than the async throws overload which can fail silently when called from @MainActor.
    func requestAuthorization(writeWeight: Bool = false) async -> Bool {
        guard isAvailable else {
            print("[HealthKitManager] HealthKit not available on this device.")
            return false
        }

        var readTypes = Set<HKObjectType>()
        var writeTypes = Set<HKSampleType>()

        if let wt = weightType {
            readTypes.insert(wt)
            if writeWeight { writeTypes.insert(wt) }
        }
        if let st = stepsType { readTypes.insert(st) }
        readTypes.insert(workoutType)

        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error = error {
                    print("[HealthKitManager] Auth error: \(error.localizedDescription)")
                }
                continuation.resume(returning: success)
            }
        }

        if granted {
            // HealthKit does NOT expose read-authorization status for privacy reasons.
            // authorizationStatus(for:) only reflects write (sharing) permission and
            // returns .notDetermined for read-only requests. After the user completes
            // the auth dialog successfully, mark all permissions granted and persist
            // via UserDefaults so the status survives app restarts.
            weightPermissionGranted = true
            stepsPermissionGranted = true
            workoutsPermissionGranted = true
            UserDefaults.standard.set(true, forKey: "hk.authorized")
        }
        return granted
    }

    // MARK: - Check Permissions
    func checkPermissions() async {
        guard isAvailable else { return }
        // Read auth status is not queryable in HealthKit (privacy by design).
        // Check the UserDefaults flag set after a successful requestAuthorization call.
        if UserDefaults.standard.bool(forKey: "hk.authorized") {
            weightPermissionGranted = true
            stepsPermissionGranted = true
            workoutsPermissionGranted = true
        }
    }

    // MARK: - Read Latest Body Weight
    func fetchLatestWeight() async -> Double? {
        guard isAvailable, let type = weightType else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                guard error == nil,
                      let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: .pound()))
            }
            store.execute(query)
        }
    }

    // MARK: - Read Weight History (last N days)
    func fetchWeightHistory(days: Int = 30) async -> [(date: Date, weightLb: Double)] {
        guard isAvailable, let type = weightType else { return [] }

        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                guard error == nil, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = samples.map { (date: $0.endDate, weightLb: $0.quantity.doubleValue(for: .pound())) }
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    // MARK: - Write Weight
    func writeWeight(weightLb: Double, date: Date = .now) async -> Bool {
        guard isAvailable, let type = weightType else { return false }
        let quantity = HKQuantity(unit: .pound(), doubleValue: weightLb)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        return await withCheckedContinuation { continuation in
            store.save(sample) { success, error in
                if let error = error { print("[HealthKitManager] Write error: \(error)") }
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Read Today's Steps
    func fetchTodaySteps() async -> Int? {
        guard isAvailable, let type = stepsType else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                guard error == nil, let sum = stats?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }
            store.execute(query)
        }
    }

    // MARK: - Read Recent Workouts
    func fetchRecentWorkouts(days: Int = 7) async -> [WorkoutEntry] {
        guard isAvailable else { return [] }
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                guard error == nil, let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                let entries = workouts.map { w -> WorkoutEntry in
                    WorkoutEntry(
                        date: w.endDate,
                        type: HealthKitManager.mapWorkoutType(w.workoutActivityType),
                        durationMinutes: Int(w.duration / 60),
                        source: "HealthKit"
                    )
                }
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    // MARK: - Sync (called on app open)
    func sync() async {
        guard isAvailable else { return }
        latestWeightLb = await fetchLatestWeight()
        todaySteps = await fetchTodaySteps()
        lastSyncDate = .now
    }

    // MARK: - Map HK workout type
    nonisolated private static func mapWorkoutType(_ t: HKWorkoutActivityType) -> WorkoutType {
        switch t {
        case .basketball: return .basketball
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: return .lifting
        case .running, .cycling, .elliptical, .rowing: return .cardio
        case .walking: return .walk
        case .highIntensityIntervalTraining: return .hiit
        default: return .other
        }
    }
}
