//
//  VoiceModeViewModel.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 12/05/25.
//

import CoreData
import Foundation
import Combine
import SwiftUI
import Speech

final class VoiceModeViewModel: NSObject, ObservableObject {

    let voiceHandler = VoiceChatHandler()
    let session: Chats
    private let context = PersistenceController.shared.container.viewContext
    private let networkManager = NetworkManager()
    private let currentMessages: FetchedResults<ChatMessage>
    private var textToSend = ""
    @Published var showEqualizer = false
    @Published var rotationAngle: Double = 0
    @Published var pulse: CGFloat = 1.0
    @Published var wavePhase: CGFloat = 0
    @Published var waveAmplitude: CGFloat = 0.5
    @Published var shouldTurnIntoLine: Bool = false
    @Published var showLine: Bool = true
    @Published var timer: Timer?
    @Published var aiThinkingOpacity = 1.0
    @Published var permissionsStatus = false
    
    @Published var networkMonitor = NetworkMonitor()
    
    var thinkingTimer: Timer?
    var isAITalking = false
    var permissionTimer: Timer?

    init(session: Chats, currentMessages: FetchedResults<ChatMessage>) {
        self.session = session
        self.currentMessages = currentMessages
    }
    
    func startASR() {
        voiceHandler.startVoiceInteraction(onUserText: { text in
            self.textToSend = text
            self.sendMessage()
        })
    }
    
    func sendMessage() {
        self.humanStoppedSpeaking()
        let userMessage = ChatMessage(context: context)
        userMessage.id = UUID()
        userMessage.text = textToSend
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
        messageContextForLLM.append(["role": "user", "content": textToSend])
        self.textToSend = ""
        aiThinking()
        Task {
            await networkManager.sendMessageStream(prompt: messageContextForLLM, onReceive: { chunk in
                print("Chunk received: \(chunk)")
                //                self.isThinking = false
                DispatchQueue.main.async {
                    botMessage.text? += chunk
                    self.saveContext()
                    //                    self.scrollProxy?.scrollTo(0, anchor: .bottom)
                }
            }, onComplete: {
                DispatchQueue.main.async {
                    self.aiSpeaking()
                    self.readMessage(botMessage.text ?? "")
                }
            })
        }
    }
    
    private func readMessage(_ message: String) {
        voiceHandler.readText(message, delegate: self)
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    func humanSpeaking() {
        withAnimation {
            self.shouldTurnIntoLine = false
            self.showEqualizer = false
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.rotationAngle += (self.voiceHandler.amplitude) * 100
        }
    }
    
    func humanStoppedSpeaking() {
        withAnimation {
            self.waveAmplitude = 0
            self.shouldTurnIntoLine = true
            self.timer?.invalidate()
        }
    }

    func aiThinking() {
        self.thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { _ in
            withAnimation {
                self.aiThinkingOpacity = (self.aiThinkingOpacity == 1) ? 0.2 : 1
            }
        })
    }
    func aiSpeaking() {
        aiThinkingOpacity = 1
        thinkingTimer?.invalidate()
        withAnimation {
            self.showEqualizer = true
            self.showLine = false
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.wavePhase += 0.2
            self.waveAmplitude = self.voiceHandler.volumeLevel * 10
        }
    }
    
    func aiStoppedSpeaking() {
        withAnimation {
            waveAmplitude = 0
            timer?.invalidate()
            showLine = true
        }
    }
}

extension VoiceModeViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.voiceHandler.timerToCheckAmplitudeofVoice?.invalidate()
        isAITalking = false
        self.aiStoppedSpeaking()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.startASR()
            self.humanSpeaking()
        }
    }
}
