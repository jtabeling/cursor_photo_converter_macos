//
//  Photo_ConverterApp.swift
//  Photo Converter
//
//  Created by jerry tabeling on 4/21/25.
//

import SwiftUI
import SwiftData

@main
struct Photo_ConverterApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Initialize logger at app launch to capture all activity
        Logger.shared.log("=== Photo Converter App Launched ===", level: .info)
        Logger.shared.log("App version: 1.0", level: .info)
        Logger.shared.log("macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)", level: .info)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
