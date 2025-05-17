//
//  LLMResponseModel.swift
//  ChatGPT-Clone
//
//  Created by Saran Goda on 11/05/25.
//

import Foundation

struct LLMResponseModel: Codable, Identifiable {
    var id: String
    var choices: [LLMResponseChoice]?
}

struct LLMResponseChoice: Codable {
    var delta: LLMResponseDelta?
}

struct LLMResponseDelta: Codable {
    var content: String?
}
