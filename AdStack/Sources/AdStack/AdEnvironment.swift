//
//  AdEnvironment.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

// In AdStack

public enum AdEnvironmentType: String {
    case dev, staging, prod
}

public protocol AdEnvironmentProvider {
    var environment: AdEnvironmentType { get }
}

public enum AdEnvironment {
    private static var provider: AdEnvironmentProvider?

    public static func configure(provider: AdEnvironmentProvider) {
        self.provider = provider
    }

    public static var current: AdEnvironmentType {
        provider?.environment ?? .dev
    }
}
