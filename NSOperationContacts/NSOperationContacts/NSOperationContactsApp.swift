//
//  NSOperationContactsApp.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import SwiftUI

@main
struct NSOperationContactsApp: App {
    
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
