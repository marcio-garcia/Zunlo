//
//  WeatherInfo.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import Foundation
import WeatherKit

struct CachedWeatherEntry: Codable {
    let info: WeatherInfo
    let timestamp: Date
}

struct WeatherInfo: Codable {
    let temperature: Double
    let unitSymbol: String
    let conditionCode: String

    var measurement: Measurement<UnitTemperature> {
        Measurement(value: temperature, unit: UnitTemperature.from(symbol: unitSymbol))
    }

    var condition: WeatherCondition {
        WeatherCondition(rawValue: conditionCode) ?? .clear
    }
}

extension UnitTemperature {
    static func from(symbol: String) -> UnitTemperature {
        switch symbol.lowercased() {
        case "fahrenheit", "°f": return .fahrenheit
        case "kelvin": return .kelvin
        default: return .celsius
        }
    }

    var symbolString: String {
        switch self {
        case .celsius: return "celsius"
        case .fahrenheit: return "fahrenheit"
        case .kelvin: return "kelvin"
        default: return "celsius"
        }
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
