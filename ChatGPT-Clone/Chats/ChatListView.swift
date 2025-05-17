//
//  ChatListView.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chats.timestamp, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<Chats>
    @State private var newChatPush = false
    @State private var newChat: Chats? = nil
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            VStack {
                if sessions.count > 0 {
                    List {
                        ForEach(sessions) { session in
                            Button(action: {
                                self.newChat = session
                                self.newChatPush = true
                            }){
                                ListRow(session: session)
                                    .padding(10)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .id(refreshID)
                } else {
                    Text("Press the pencil icon to get started!")
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationDestination(isPresented: $newChatPush, destination: {
                if newChat != nil {
                    ChatView(session: newChat!)
                } else {
                    EmptyView()
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNewChat) {
                        HStack {
                            Image(systemName: "applepencil.gen2")
                            Text("New Chat")
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: newChatPush) {_, _ in
            refreshID = UUID()
        }
    }

    private func createNewChat() {
        let newSession = Chats(context: viewContext)
        newSession.id = UUID()
        newSession.timestamp = Date()

        do {
            try viewContext.save()
            self.newChat = newSession
            self.newChatPush = true
        } catch {
            print("Failed to create chat: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ChatListView()
}

struct ListRow: View {
    var session: Chats
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(session.title ?? "Untitled Chat")")
                .font(.title3.bold())
            Text("\(session.timestamp?.formatted(date: .numeric, time: .shortened) ?? Date().formatted(date: .numeric, time: .shortened))")
                .font(.caption)
        }
    }
}
