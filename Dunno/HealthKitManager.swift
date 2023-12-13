//
//  HealthKitManager.swift
//  Dunno
//
//  Created by Edgar Noel Espino Córdova on 12/12/23.
//

import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var workout: HKWorkout? = nil

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

    private func executeQueryAsync(
        sampleType: HKSampleType,
        predicate: NSPredicate,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
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

    private func getWorkoutData() async -> HKWorkout? {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .walking)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        
        do {
            let results = try await executeQueryAsync(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            )
            
            guard let samples = results as? [HKWorkout] else {
                print("HealthKit query error: Invalid data type")

                return nil
            }

            return samples.first
        } catch {
            print("HealthKit query error: \(error.localizedDescription)")

            return nil
        }
    }


    
    func getInitialData() async {
        guard let workout = await getWorkoutData() else {
            return
        }

        DispatchQueue.main.async {
            self.workout = workout
        }
    }
}
