//
//  SupabaseAIChatConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/5/25.
//

public struct SupabaseAIChatConfig {
    let model: String
    let responseType: ResponseType
    let temperature: Double
    let maxWindowMessages: Int
    
    public init(
        model: String = "gpt-4o-mini",
        responseType: ResponseType = .plain,
        temperature: Double = 0.2,
        maxWindowMessages: Int = 16
    ) {
        self.model = model
        self.responseType = responseType
        self.temperature = temperature
        self.maxWindowMessages = maxWindowMessages
    }
    
}
