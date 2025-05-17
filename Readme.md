# ChatGPT Clone — iOS App

An iOS ChatGPT-like conversational app built with **SwiftUI**, supporting **text and voice input**, using **Core Data** for persistence and the third-party library [`swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) for rendering markdown responses.

---

## 🧠 Features

### ✅ 1. Text Mode
- Users can type prompts using a SwiftUI `TextField` or `TextEditor`.
- On submitting, the message is saved via Core Data and displayed in a list.
- Responses from the LLM (Large Language Model) are rendered using **swift-markdown-ui** for rich formatting (code blocks, headings, etc).

### ✅ 2. Voice Mode
- Users can enter voice mode by tapping the voice UI.
- The app uses **`SFSpeechRecognizer`** to transcribe speech to text.
- The transcript is sent to the LLM, and the response is read aloud using **`Google Cloud Speech API`**.
- A custom waveform UI provides visual feedback during listening and speaking.

### ✅ 3. Dynamic Chat Title
- A new chat session starts untitled.
- Once the user sends the **first message**, the title of the session is automatically generated (e.g., from the message summary or timestamp).
- The title is saved to Core Data and shown in the list of conversations.

---

## 🗃️ Data Persistence

- **Core Data** is used to store:
  - Chat sessions (`Chats`)
  - Individual messages (`ChatMessage`)
- Relationships are properly set up for `Chats` ↔ `ChatMessage`.

---

## 🧱 Architecture

- **MVVM** architecture is followed.
- Views are reactive and driven by `@FetchRequest`, `@ObservedObject`, and `@Environment(\.managedObjectContext)` bindings.

---

## 📦 Dependencies

### [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)
- Used for rendering LLM responses in Markdown.
- Supports inline styles, code blocks, links, etc.
- Clean integration with SwiftUI views.

Install via **Swift Package Manager**:

## 🔊 Audio Mode Technical Details

- **Speech Recognition**: `SFSpeechRecognizer`
- **Text-to-Speech**: `Google Cloud Speech API`
- Voice UI includes animated waveform and orbiting ellipses.
- Audio output is routed to speaker (not the earpiece) for clarity.

---

## 📱 UI Highlights

- **NavigationStack** manages chat sessions and message details.
- **VoiceModeView** provides animated listening/speaking feedback.
- Minimal design, tailored for conversational flow.

## 👨‍💻 Author

Built by Saran Goda, 2025  
SwiftUI | iOS | AI Assistant Apps  
