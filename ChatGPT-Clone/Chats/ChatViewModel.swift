//
//  ChatViewModel.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import Foundation
import SwiftUI
import Speech

final class ChatViewModel: NSObject, ObservableObject, Sendable {
    @Published var inputText: String = ""
    @Published var isVoiceChatPresented = false
    @Published var isThinking = false
    @Published var canCopyAndListen: Bool = true
    @Published var networkMonitor = NetworkMonitor()
    @Published var isMessagePlaying = false
    @Published var messageCopied = false
    @Published var isAudioDownloading: Bool = false
    
    var didPlayHaptic = false
    var isNewChat = false

    private let networkManager = NetworkManager()
    private let context = PersistenceController.shared.container.viewContext
    let session: Chats
    
    var voiceHandlerInstance: VoiceChatHandler?
    init(session: Chats) {
        self.session = session
    }
    
    func sendMessage(currentMessages: FetchedResults<ChatMessage>) {
        let userMessage = ChatMessage(context: context)
        userMessage.id = UUID()
        userMessage.text = inputText
        userMessage.isUser = true
        userMessage.timestamp = Date()
        userMessage.session = session
        
        let botMessage = ChatMessage(context: context)
        botMessage.id = UUID()
        botMessage.text = ""
        botMessage.isUser = false
        botMessage.timestamp = Date()
        botMessage.session = session
        saveContext()
        
        var messageContextForLLM: [[String: String]] = []
        for result in currentMessages {
            messageContextForLLM.append(["role": result.isUser ? "user" : "assistant", "content": result.text ?? ""])
        }
        messageContextForLLM.append(["role": "user", "content": inputText])
        if messageContextForLLM.count == 1 {
            self.isNewChat = true
        }
        canCopyAndListen = false
        self.inputText = ""
        Task {
            await networkManager.sendMessageStream(prompt: messageContextForLLM, onReceive: { chunk in
                print("Chunk received: \(chunk)")
                if !self.didPlayHaptic {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    self.didPlayHaptic = true
                }
                self.isThinking = false
                DispatchQueue.main.async {
                    botMessage.text? += chunk
                    self.saveContext()
                }
            }, onComplete: {
                DispatchQueue.main.async {
                    self.didPlayHaptic = false
                    self.canCopyAndListen = true
                    if self.isNewChat {
                        self.getChatTitle(userMessage: userMessage.text ?? "", botMessage: botMessage.text ?? "")
                    }
                }
            })
        }
    }
    
    private func getChatTitle(userMessage: String, botMessage: String) {
        self.isNewChat = false
        var messageContextForLLM: [[String: String]] = []
        messageContextForLLM.append(["role": "user", "content": userMessage])
        messageContextForLLM.append(["role": "assistant", "content": botMessage])
        messageContextForLLM.append(["role": "user", "content": "Based on the messages, give me a 3 word title for this chat and do not add quotes around the title. Just the title"])
        var title = ""
        Task {
            await networkManager.sendMessageStream(prompt: messageContextForLLM, onReceive: { chunk in
                DispatchQueue.main.async {
                    title += chunk
                }
            }, onComplete: {
                DispatchQueue.main.async {
                    self.setTitle(title)
                }
            })
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    private func setTitle(_ title: String) {
        print("Title of this chat set to: \(title)")
        session.title = title
        saveContext()
    }
}

extension ChatViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.voiceHandlerInstance?.timerToCheckAmplitudeofVoice?.invalidate()
        self.isMessagePlaying = false
    }
}

