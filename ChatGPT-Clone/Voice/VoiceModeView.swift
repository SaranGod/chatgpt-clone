//
//  VoiceModeView.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import SwiftUI
import AVFoundation

struct VoiceModeView: View {
    @StateObject var viewModel: VoiceModeViewModel
    @Binding var isPresented: Bool
    
    init(session: Chats, previousChat: FetchedResults<ChatMessage>, isPresented: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: VoiceModeViewModel(session: session, currentMessages: previousChat))
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            if viewModel.permissionsStatus {
                if viewModel.showEqualizer {
                    EqualizerLineView(phase: viewModel.wavePhase, amplitude: viewModel.waveAmplitude)
                }
                if viewModel.showLine {
                    ListeningBallView(rotationAngle: viewModel.rotationAngle, pulse: viewModel.pulse, shouldTurnIntoLine: $viewModel.shouldTurnIntoLine)
                        .opacity(viewModel.aiThinkingOpacity)
                }
            } else {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    }){
                        VStack(spacing: 10) {
                            Image(systemName: "microphone.badge.xmark.fill")
                                .resizable()
                                .foregroundColor(.red)
                                .frame(width: 200, height: 200)
                            Text("Tap here to provide permissions")
                                .foregroundStyle(.white)
                        }
                    }
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel.voiceHandler.requestPermission()
            viewModel.voiceHandler.requestMicrophonePermission()
            if viewModel.voiceHandler.checkPermission() {
                viewModel.permissionsStatus = true
                viewModel.humanSpeaking()
                viewModel.startASR()
                viewModel.permissionTimer?.invalidate()
            } else {
                viewModel.permissionsStatus = false
                viewModel.permissionTimer?.invalidate()
                viewModel.permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                    if viewModel.voiceHandler.checkPermission() {
                        viewModel.permissionsStatus = true
                        viewModel.humanSpeaking()
                        viewModel.startASR()
                        viewModel.permissionTimer?.invalidate()
                    } else {
                        viewModel.permissionsStatus = false
                    }
                }
                )
            }
        }
        .onDisappear() {
            viewModel.timer?.invalidate()
            viewModel.voiceHandler.stopListening()
        }
        .onChange(of: viewModel.networkMonitor.isConnected) { oldValue, newValue in
            if !newValue {
                isPresented = false
            }
        }
    }
}


struct ListeningBallView: View {
    let rotationAngle: Double
    let pulse: CGFloat
    @Binding var shouldTurnIntoLine: Bool
    
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.9), Color.black]),
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 60, height: 60)
                .blur(radius: 20)
                .scaleEffect(pulse)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            ZStack {
                OrbitingEllipse(axis: (1, 0, 0), angle: rotationAngle, scale: pulse, color: .blue, shouldTurnIntoLine: $shouldTurnIntoLine)
                OrbitingEllipse(axis: (0, 1, 0), angle: rotationAngle * 1.2, scale: pulse * 0.95, color: .green, shouldTurnIntoLine: $shouldTurnIntoLine)
                OrbitingEllipse(axis: (1, 1, 0), angle: rotationAngle * 0.8, scale: pulse * 1.05, color: .purple, shouldTurnIntoLine: $shouldTurnIntoLine)
                OrbitingEllipse(axis: (0, 1, 1), angle: rotationAngle * 1.5, scale: pulse * 0.9, color: .cyan, shouldTurnIntoLine: $shouldTurnIntoLine)
            }
            .scaleEffect(0.9 + 0.1 * pulse)
        }
    }
}


struct OrbitingEllipse: View {
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    let angle: Double
    let scale: CGFloat
    let color: Color
    
    @Binding var shouldTurnIntoLine: Bool
    
    var body: some View {
        Ellipse()
            .stroke(color, lineWidth: 2)
            .frame(width: shouldTurnIntoLine ? UIScreen.main.bounds.width : 120 * scale, height: shouldTurnIntoLine ? 1 : max(1, 60 * scale))
            .rotation3DEffect(
                .degrees(shouldTurnIntoLine ? 0 : angle),
                axis: (x: axis.x, y: axis.y, z: axis.z)
            )
            .opacity(0.6 + 0.4 * Double.random(in: 0...1))
            .shadow(color: color.opacity(0.7), radius: 8)
            .blendMode(.screen)
    }
}

struct EqualizerLineView: View {
    let phase: CGFloat
    let amplitude: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let midY = geo.size.height / 2
                let width = geo.size.width
                let step = width / 60
                
                path.move(to: CGPoint(x: 0, y: midY))
                
                for x in stride(from: 0, to: width, by: step) {
                    let y = midY + sin((x / width * 2 * .pi) + phase) * amplitude * 100
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.cyan, lineWidth: 3)
        }
    }
}

