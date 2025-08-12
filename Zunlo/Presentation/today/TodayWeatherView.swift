//
//  TodayWeatherView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import SwiftUI

struct TodayWeatherView: View {
    let weather: WeatherInfo?
    var greeting: String
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .themedSubtitle()
                HStack {
                    if let symbolName = weather?.condition.symbolName(for: Date()) {
                        Image(systemName: symbolName)
                            .themedSubtitle()
                    }
                    
                    Text("\(Int(weather?.measurement.value ?? 0))°")
                        .themedBody()
                    
                    Text(description)
                        .themedCallout()
                    Spacer()
                }
            }
            .themedCard(blurBackground: true)
        }
    }
    
    private var description: String {
        if let weather = weather?.condition {
            switch weather {
            case .clear: return String(localized: "Clear skies")
            case .drizzle: return String(localized: "Drizzle")
            case .mostlyClear: return String(localized: "Mostly clear")
            case .cloudy: return String(localized: "Cloudy")
            case .partlyCloudy: return String(localized: "Partly cloudy")
            case .mostlyCloudy: return String(localized: "Mostly cloudy")
            case .rain: return String(localized: "Rainy")
            case .snow: return String(localized: "Snowy")
            default: return String(localized: "Weather update")
            }
        }
        return String(localized: "Weather update")
    }
    
    private var backgroundImageName: String {
        if let weather = weather?.condition {
            let hour = Calendar.appDefault.component(.hour, from: Date())
            let isDay = (6...18).contains(hour)
            
            switch weather {
            case .clear, .mostlyClear: return isDay ? "bg_clear_day" : "bg_clear_night"
            case .partlyCloudy, .mostlyCloudy: return isDay ? "bg_partly_cloudy_day" : "bg_partly_cloudy_night"
            case .cloudy: return "bg_cloudy"
            case .rain: return "bg_rain"
            case .snow: return "bg_snow"
            default: return "bg_default"
            }
        }
        return "bg_default"
    }
}
