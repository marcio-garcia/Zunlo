//
//  WeatherService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/1/25.
//

import WeatherKit
import CoreLocation

final class WeatherService {
    static let shared = WeatherService()
    
    private let service = WeatherKit.WeatherService()

    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherInfo? {
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather

        return WeatherInfo(
            temperature: current.temperature.value,
            unitSymbol: current.temperature.unit.symbolString,
            conditionCode: current.condition.rawValue
        )
    }
}
