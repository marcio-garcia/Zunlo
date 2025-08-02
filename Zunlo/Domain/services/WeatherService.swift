//
//  WeatherService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/1/25.
//

import WeatherKit
import CoreLocation

struct WeatherInfo {
    let temperature: Measurement<UnitTemperature>
    let conditionCode: WeatherCondition
}

final class WeatherService {
    static let shared = WeatherService()
    
    private let service = WeatherKit.WeatherService()

    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherInfo? {
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather

        return WeatherInfo(
            temperature: current.temperature,
            conditionCode: current.condition
        )
    }
}

extension WeatherCondition {
    func symbolName(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let isDaytime = (6...18).contains(hour)

        switch self {
        case .clear:
            return isDaytime ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy:
            return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunderstorms:
            return "cloud.bolt.rain.fill"
        case .foggy:
            return "cloud.fog.fill"
        default:
            return "cloud"
        }
    }
}
