//
//  VoiceChatHandler.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import Foundation
import AVFoundation
import Speech

class VoiceChatHandler: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
    private let audioEngine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    let synthesizer = AVSpeechSynthesizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var pauseDetectionTimer: Timer?
    private var detectedText: String = ""
    private var isSilenceDetected: Bool = false
    var player: AVAudioPlayer?
    let networkManager = NetworkManager()
    var timerToCheckAmplitudeofVoice: Timer?
    
    @Published var amplitude: Double = 0.0
    @Published var volumeLevel: Double = 0.0
    
    func startVoiceInteraction(onUserText: @escaping (String) -> Void) {
        requestMicrophonePermission()
        requestPermission()
        if checkPermission() {
            startListening(onUserText: onUserText)
        }
    }
    
    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { _ in
            
        }
    }
    
    func checkPermission() -> Bool {
        let micStatus = AVAudioApplication.shared.recordPermission
        return SFSpeechRecognizer.authorizationStatus() == .authorized && micStatus == .granted
    }
    
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition authorization status: \(status)")
        }
    }
    func startListening(onUserText: @escaping (String) -> Void) {
        isSilenceDetected = false
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? audioSession.setActive(true)
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            
            let rms = sqrt(sum / Float(frameLength))
            DispatchQueue.main.async {
                self.amplitude = Double(rms)
            }
        }
        audioEngine.prepare()
        try? audioEngine.start()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            guard let result = result else { return }
            let finalText = result.bestTranscription.formattedString
            if !finalText.isEmpty && finalText != self.detectedText && !self.isSilenceDetected {
                self.detectedText = finalText
                self.pauseDetectionTimer?.invalidate()
                self.pauseDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { _ in
                    self.isSilenceDetected = true
                    self.stopListening()
                    onUserText(self.detectedText)
                })
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        request.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask?.finish()
        recognitionTask = nil
    }
    
    func stopVoiceInteraction() {
        stopListening()
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    func readText(_ text: String, delegate: AVAudioPlayerDelegate) {
        if player != nil {
            if player!.isPlaying {
                player?.stop()
                return
            }
        }
        networkManager.synthesizeSpeech(text: text) { data in
            DispatchQueue.main.async {
                if delegate is ChatViewModel {
                    (delegate as? ChatViewModel)?.isAudioDownloading = false
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
                    try AVAudioSession.sharedInstance().setActive(true)
                    self.player = try AVAudioPlayer(data: data)
                    self.player?.delegate = delegate
                    self.player?.isMeteringEnabled = true
                    self.player?.prepareToPlay()
                    self.player?.play()
                    self.timerToCheckAmplitudeofVoice?.invalidate()
                    self.timerToCheckAmplitudeofVoice = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        self.player?.updateMeters()
                        let power = self.player?.averagePower(forChannel: 0)
                        let linearLevel = pow(10, (power ?? 0) / 20) // Convert dB to 0.0–1.0 scale
                        DispatchQueue.main.async {
                            print("The audio level is \(linearLevel)")
                            self.volumeLevel = Double(linearLevel)
                        }
                    }
                } catch {
                    print("Audio playback error: \(error)")
                }
            }
        }
    }
    
}
