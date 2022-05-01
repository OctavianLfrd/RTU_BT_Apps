//
//  SwiftConcurrencyContactsApp.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 26/04/2022.
//

import SwiftUI

@main
struct SwiftConcurrencyContactsApp: App {
    
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
