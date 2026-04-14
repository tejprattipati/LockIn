// HealthKitManager.swift
// Handles HealthKit integration: reading weight, steps, and workouts.
// Writes weight back only if user explicitly enables it.
// Gracefully degrades if permissions are denied.

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

    // MARK: - Types we read
    private var weightType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }
    private var stepsType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }
    private var workoutType: HKObjectType {
        HKObjectType.workoutType()
    }

    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Authorization
    func requestAuthorization(writeWeight: Bool = false) async -> Bool {
        guard isAvailable else { return false }

        var readTypes = Set<HKObjectType>()
        var writeTypes = Set<HKSampleType>()

        if let wt = weightType {
            readTypes.insert(wt)
            if writeWeight { writeTypes.insert(wt) }
        }
        if let st = stepsType { readTypes.insert(st) }
        readTypes.insert(workoutType)

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            await checkPermissions()
            return true
        } catch {
            print("[HealthKitManager] Authorization error: \(error)")
            return false
        }
    }

    func checkPermissions() async {
        guard isAvailable else { return }
        if let wt = weightType {
            weightPermissionGranted = store.authorizationStatus(for: wt) == .sharingAuthorized
        }
        if let st = stepsType {
            stepsPermissionGranted = store.authorizationStatus(for: st) == .sharingAuthorized
        }
        // Workout read permission is harder to check; assume if auth was run
    }

    // MARK: - Read Most Recent Body Weight
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
                let lb = sample.quantity.doubleValue(for: HKUnit.pound())
                continuation.resume(returning: lb)
            }
            store.execute(query)
        }
    }

    // MARK: - Read Recent Weight Entries (last N days)
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

    // MARK: - Write Weight (only if user opted in)
    func writeWeight(weightLb: Double, date: Date = .now) async -> Bool {
        guard isAvailable, let type = weightType else { return false }

        let quantity = HKQuantity(unit: .pound(), doubleValue: weightLb)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

        do {
            try await store.save(sample)
            return true
        } catch {
            print("[HealthKitManager] Write weight error: \(error)")
            return false
        }
    }

    // MARK: - Read Today's Steps
    func fetchTodaySteps() async -> Int? {
        guard isAvailable, let type = stepsType else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                guard error == nil, let sum = stats?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
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
                    let type = HealthKitManager.mapWorkoutType(w.workoutActivityType)
                    let duration = Int(w.duration / 60)
                    return WorkoutEntry(date: w.endDate, type: type, durationMinutes: duration, source: "HealthKit")
                }
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    // MARK: - Full Sync
    func sync() async {
        guard isAvailable else { return }
        latestWeightLb = await fetchLatestWeight()
        todaySteps = await fetchTodaySteps()
        lastSyncDate = .now
    }

    // MARK: - Map HKWorkoutActivityType to WorkoutType
    nonisolated private static func mapWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutType {
        switch hkType {
        case .basketball:   return .basketball
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .lifting
        case .running, .cycling, .elliptical, .rowing:
            return .cardio
        case .walking:      return .walk
        case .highIntensityIntervalTraining: return .hiit
        default:            return .other
        }
    }
}
