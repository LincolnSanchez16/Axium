//
//  AxiomApp.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI
import CoreData

@main
struct AxiomApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
