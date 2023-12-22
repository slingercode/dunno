//
//  HealthKitManager.swift
//  Dunno
//
//  Created by Edgar Noel Espino Córdova on 12/12/23.
//

import HealthKit
import MapKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var workout: HKWorkout? = nil
    @Published var locations: [CLLocation] = []

    func requestAuthorization() async -> Bool {
        let read: Set = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: read)

            return true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")

            return false
        }
    }

    private func executeWorkoutsQueryAsync() async throws -> [HKSample] {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .walking)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { (query, results, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }

            healthStore.execute(query)
        }
    }

    private func executeWorkoutQueryAsync(for workout: HKWorkout) async throws -> HKWorkoutRoute {
        let workoutType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: workoutType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { (query, results, deletedObjects, anchor, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.first as! HKWorkoutRoute as HKWorkoutRoute)
                }
            }

            healthStore.execute(query)
        }
    }

    private func executeWorkoutRouteQueryAsync(for workoutRoute: HKWorkoutRoute) async throws -> [CLLocation] {
        var locations: [CLLocation] = []

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: workoutRoute) { (query, results, done, error) in
                if let error = error {
                    continuation.resume(throwing: error)

                    return
                }

                guard let workoutLocations = results else {
                    continuation.resume(throwing: "*** Invalid State: This can only fail if there was an error. ***" as! Error)

                    return
                }

                workoutLocations.forEach { location in
                    locations.append(location)
                }

                if done {
                    continuation.resume(returning: locations)
                }
            }

            healthStore.execute(query)
        }
    }

    private func getWorkoutData() async -> HKWorkout? {
        do {
            let results = try await executeWorkoutsQueryAsync()

            guard let workouts = results as? [HKWorkout] else {
                print("HealthKit query error: Invalid data type")

                return nil
            }

            return workouts.first
        } catch {
            print("HealthKit query error: \(error.localizedDescription)")

            return nil
        }
    }

    private func getWorkoutRoute(for workout: HKWorkout) async -> [CLLocation] {
        do {
            let wourkoutRoute = try await executeWorkoutQueryAsync(for: workout)
            let locations = try await executeWorkoutRouteQueryAsync(for: wourkoutRoute)
            
            return locations
        } catch {
            print("HealthKit query error: \(error.localizedDescription)")
            
            return []
        }
    }
    
    func getInitialData() async {
        guard let workout = await getWorkoutData() else {
            return
        }

        let locations = await getWorkoutRoute(for: workout)

        DispatchQueue.main.async {
            self.workout = workout
            self.locations = locations
        }
    }
}
