//
//  SupabaseFunctionsStreamer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/5/25.
//

import Foundation
import Supabase

public protocol EdgeFunctionStreamer {
    func setAuth(token: String)
    func stream(function: String, options: FunctionInvokeOptions) -> AsyncThrowingStream<Data, Error>
    func invoke(function: String, options: FunctionInvokeOptions) async throws -> EmptyResponse
}

public final class SupabaseFunctionsStreamer: EdgeFunctionStreamer {
    private let supabase: SupabaseClient
    public init(supabase: SupabaseClient) { self.supabase = supabase }
    public func setAuth(token: String) { supabase.functions.setAuth(token: token) }
    public func stream(function: String, options: FunctionInvokeOptions) -> AsyncThrowingStream<Data, Error> {
        supabase.functions._invokeWithStreamedResponse(function, options: options)
    }
    public func invoke(function: String, options: FunctionInvokeOptions) async throws -> EmptyResponse {
        try await supabase.functions.invoke(function, options: options) as EmptyResponse
    }
}
