//
//  TodayWeatherView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import SwiftUI

struct TodayWeatherView: View {
    let weather: WeatherInfo
    var greeting: String
    
    var body: some View {
        ZStack {
            Image(backgroundImageName)
                .resizable()
                .scaledToFill()
                .frame(height: 80)
            //                .clipped()
                .cornerRadius(8)
//                .overlay(Color.black.opacity(0.3).blur(radius: 4))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .themedTitle()
                HStack {
                    Image(systemName: weather.condition.symbolName(for: Date()))
                        .themedSubtitle()
                    
                    VStack(alignment: .leading) {
                        Text("\(Int(weather.measurement.value))°")
                            .themedBody()
                        
                        Text(description)
                            .themedCallout()
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var description: String {
        switch weather.condition {
        case .clear: return "Clear skies"
        case .cloudy: return "Cloudy"
        case .partlyCloudy: return "Partly cloudy"
        case .rain: return "Rainy"
        case .snow: return "Snowy"
        default: return "Weather update"
        }
    }
    
    private var backgroundImageName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isDay = (6...18).contains(hour)
        
        switch weather.condition {
        case .clear, .mostlyClear: return isDay ? "bg_clear_day" : "bg_clear_night"
        case .partlyCloudy, .mostlyCloudy: return isDay ? "bg_partly_cloudy_day" : "bg_partly_cloudy_night"
        case .cloudy: return "bg_cloudy"
        case .rain: return "bg_rain"
        case .snow: return "bg_snow"
        default: return "bg_default"
        }
    }
}
