//
//  GCDContactsApp.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import SwiftUI

@main
struct GCDContactsApp: App {
    
    init() {
        MetricObserver.shared.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
