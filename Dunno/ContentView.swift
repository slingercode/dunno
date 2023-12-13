//
//  ContentView.swift
//  Dunno
//
//  Created by Edgar Noel Espino Córdova on 12/12/23.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var permissionGranted = false

    var body: some View {
        VStack {
            if permissionGranted == false {
                Text("Please authorize the application")
            } else {
                if let workout = healthKitManager.workout {
                    Text("Start Date \(workout.startDate)")
                } else {
                    Text("No workout")
                }
            }
        }
        .padding()
        .task {
            if !HKHealthStore.isHealthDataAvailable() {
                return
            }
            
            guard await healthKitManager.requestAuthorization() == true else {
                return
            }
            
            permissionGranted = true;
            
            await healthKitManager.getInitialData()
        }
    }
}

#Preview {
    ContentView()
}
