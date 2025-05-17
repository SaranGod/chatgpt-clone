//
//  ChatView.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import CoreData
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    var fetchRequest: FetchRequest<ChatMessage>
    
    @State var shouldShowListView = false
    
    @FocusState private var isInputFocused: Bool
    @State private var textViewHeight: CGFloat = 45
    
    init(session: Chats) {
        self._viewModel = StateObject(wrappedValue: ChatViewModel(session: session))
        self.fetchRequest = FetchRequest(
            entity: ChatMessage.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session),
            animation: .default)
    }
    
    var message: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(fetchRequest.wrappedValue) { message in
                HStack {
                    if message.isUser { Spacer() }
                    VStack(alignment: .leading) {
                        Markdown {
                            message.text ?? ""
                        }
                        .markdownTextStyle {
                            ForegroundColor(message.isUser ? Color.black : Color.white)
                            BackgroundColor(nil)
                        }
                        if !message.isUser && viewModel.canCopyAndListen {
                            HStack {
                                Button(action: {
                                    UIPasteboard.general.setValue(message.text ?? "", forPasteboardType: UTType.plainText.identifier)
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    withAnimation {
                                        viewModel.messageCopied = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            viewModel.messageCopied = false
                                        }
                                    }
                                }) {
                                    Image(systemName: "document.on.document.fill")
                                        .foregroundStyle(.white)
                                }
                                Button(action: {
                                    if self.viewModel.voiceHandlerInstance == nil {
                                        self.viewModel.voiceHandlerInstance = VoiceChatHandler()
                                    }
                                    self.viewModel.isAudioDownloading = true
                                    self.viewModel.voiceHandlerInstance?.readText(message.text ?? "", delegate: viewModel)
                                    self.viewModel.isMessagePlaying.toggle()
                                }) {
                                    if viewModel.isMessagePlaying {
                                        Image(systemName: "speaker.slash.fill")
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: "speaker.wave.3.fill")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .disabled(viewModel.isAudioDownloading)
                                .shimmering(active: viewModel.isAudioDownloading)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding()
                    .background(message.isUser ? Color.white : Color.black)
                    .cornerRadius(10)
                    if !message.isUser { Spacer() }
                }
            }
            VStack {
                HStack {
                    if !viewModel.canCopyAndListen {
                        Text("Thinking...")
                            .font(.title3)
                            .shimmering()
                    }
                    Spacer()
                }
            }
            Color.clear
                .frame(height: isInputFocused ? UIScreen.main.bounds.height * 0.3 : 1)
                .id("bottom")
        }
        .padding()
        .navigationTitle(Constants.MODEL_ID)
        .navigationBarTitleDisplayMode(.inline)
        
    }
    
    var bottomBar: some View {
        HStack {
            GrowingTextView(text: $viewModel.inputText, height: $textViewHeight)
                .frame(height: textViewHeight)
                .focused($isInputFocused)
                .overlay {
                    HStack {
                        if viewModel.inputText.isEmpty {
                            Text("Type your thoughts...")
                                .foregroundColor(.gray)
                                .padding(.leading)
                            Spacer()
                        } else {
                            EmptyView()
                        }
                    }
                }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                isInputFocused = false
                viewModel.sendMessage(currentMessages: fetchRequest.wrappedValue)
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .disabled(viewModel.inputText.isEmpty || !viewModel.networkMonitor.isConnected)
            .opacity(viewModel.inputText.isEmpty || !viewModel.networkMonitor.isConnected ? 0.5 : 1)
            
            Button(action: { viewModel.isVoiceChatPresented = true }) {
                Image(systemName: "waveform")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.purple)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.networkMonitor.isConnected)
            .opacity(!viewModel.networkMonitor.isConnected ? 0.5 : 1)
            .fullScreenCover(isPresented: $viewModel.isVoiceChatPresented) {
                VoiceModeView(session: viewModel.session, previousChat: fetchRequest.wrappedValue, isPresented: $viewModel.isVoiceChatPresented)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.networkMonitor.isConnected {
                if viewModel.messageCopied {
                    Color.green.opacity(0.3)
                        .frame(height: 20)
                        .overlay {
                            Text("Text Copied to Clipboard!")
                        }
                } else {
                    Color.white
                        .frame(height: 1)
                }
            } else {
                Color.red
                    .frame(height: 20)
                    .overlay {
                        Text("No internet connection!!")
                    }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    message
                }
                .defaultScrollAnchor(.bottom)
                .simultaneousGesture(TapGesture().onEnded({ _ in
                    isInputFocused = false
                }))
                .simultaneousGesture(DragGesture().onChanged { _ in
                    isInputFocused = false
                })
                .onChange(of: isInputFocused) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom")
                    }
                }
                .onChange(of: viewModel.canCopyAndListen) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom")
                    }
                }
            }
            bottomBar
                .padding()
        }
        .toolbarBackground(.black, for: .navigationBar)
        .overlay {
            Color.black.opacity(shouldShowListView ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        shouldShowListView = false
                    }
                }
        }
        .background(Color.black)
    }
}

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.isScrollEnabled = true
        textView.backgroundColor = UIColor.gray.withAlphaComponent(0.1)
        textView.textColor = .white
        textView.layer.cornerRadius = 10
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
            if size.height < 220 {
                self.height = size.height
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        
        init(_ parent: GrowingTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude))
            if size.height < 220 {
                parent.height = size.height
            }
        }
    }
}
