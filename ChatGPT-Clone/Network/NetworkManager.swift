//
//  NetworkManager.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import Foundation
import AVFoundation

class NetworkManager {
    private let apiKey = Constants.API_KEY
    private let apiURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    func sendMessageStream(prompt: [[String: String]], onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) async {
        let payload: [String: Any] = [
            "model": Constants.MODEL_ID,
            "messages": prompt,
            "stream": true
        ]
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (stream, _) = try await URLSession.shared.bytes(for: request)
            for try await line in stream.lines {
                let cleanLine = line.dropFirst(6)
                if cleanLine == "[DONE]" {
                    break
                } else if cleanLine == ": OPENROUTER PROCESSING" || cleanLine == "ROUTER PROCESSING" {
                    continue
                }
                print(cleanLine)
                if let jsonData = cleanLine.data(using: .utf8),
                   let json = try? JSONDecoder().decode(LLMResponseModel.self, from: jsonData),
                   let choices = json.choices,
                   let delta = choices.first?.delta,
                   let content = delta.content {
                    print("Testing the content \(content)")
                    await MainActor.run {
                        onReceive(content)
                    }
                } else {
                    throw NSError(domain: "Invalid JSON format", code: 999, userInfo: nil)
                }
            }
            await MainActor.run {
                onComplete()
            }
        } catch {
            print("Streaming error: \(error.localizedDescription)")
            await MainActor.run {
                onComplete()
            }
        }
    }

    func synthesizeSpeech(text: String, completion: @escaping (Data) -> Void) {
        let url = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(Constants.GOOGLE_API_KEY)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": "en-US",
                "name": "en-US-Chirp3-HD-Achernar"
            ],
            "audioConfig": ["audioEncoding": "MP3"]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("TTS API error: \(error)")
                return
            }
            let result = try? JSONDecoder().decode(GoogleTTSResponse.self, from: data ?? Data())
            if let audioData = Data(base64Encoded: result?.audioContent ?? "") {
                completion(audioData)
            }
        }.resume()
    }
}

struct GoogleTTSResponse: Codable {
    let audioContent: String
}
