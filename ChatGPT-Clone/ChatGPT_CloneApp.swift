//
//  ChatGPT_CloneApp.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 10/05/25.
//

import SwiftUI

@main
struct ChatGPT_CloneApp: App {
    var body: some Scene {
        WindowGroup {
            ChatListView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
