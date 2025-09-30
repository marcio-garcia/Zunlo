//
//  WeatherProvider.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/1/25.
//

import WeatherKit
import CoreLocation

protocol WeatherService {
    var location: CLLocation? { get set }
    func fetchWeather(for date: Date) async throws -> WeatherInfo?
    func summaryForToday() async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool)
}

final class WeatherProvider: WeatherService {
    static let shared = WeatherProvider()

    var location: CLLocation?
    
    private let service = WeatherKit.WeatherService()

    func fetchWeather(for date: Date) async throws -> WeatherInfo? {
        guard let location else { return nil }
        
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather

        return WeatherInfo(
            temperature: current.temperature.value,
            unitSymbol: current.temperature.unit.symbolString,
            conditionCode: current.condition.rawValue
        )
    }
    
    /// Compact slice for AI: human-ish summary + max precip chance next 4h + rain flag.
    func fetchTodayAIContext() async throws -> (summary: String, precipNext4h: Double, rainingSoon: Bool) {
        guard let location else {
            return ("", 0, false)
        }
        
        // Pull current + hourly in one shot for efficiency
        let hourlyWeather = try await service.weather(for: location, including: .hourly)

        // Hourly forecast for the next 4 hours (including the current hour)
        let now = Date()
        let horizon = now.addingTimeInterval(4 * 3600)
        let next4h = hourlyWeather.filter { $0.date >= now && $0.date <= horizon }
        
        // Max precip chance in 0...1 (fallback 0)
        let maxPrecip = next4h.map(\.precipitationChance).max() ?? 0.0

        // “Raining soon” if any hour is precipitating or chance >= 0.5
        let rainingSoon = next4h.contains { hour in
            hour.precipitationAmount.value > 0 || hour.precipitationChance >= 0.5
        }

        guard let current = next4h.first else {
            return ("", 0, false)
        }
        
        let temp = Int(current.temperature.value.rounded())
        let unit = current.temperature.unit.symbolString
        let summary = "\(current.condition.rawValue.capitalized), \(temp)\(unit)"

        return (summary, maxPrecip, rainingSoon)
    }

    public func summaryForToday() async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool) {
        do {
            let ctx = try await fetchTodayAIContext()
            return (ctx.summary, ctx.precipNext4h, ctx.rainingSoon)
        } catch {
            return (nil, nil, false)
        }
    }
}

/// This mock class is mainly intended to be used in screenshot tests
final class MockWeatherProvider: WeatherService {
    
    var location: CLLocation?
    
    func fetchWeather(for date: Date) async throws -> WeatherInfo? {
        return WeatherInfo(temperature: 20.0, unitSymbol: "celsius", conditionCode: "clear")
    }
    
    func summaryForToday() async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool) {
        return (nil, nil, false)
    }
}
