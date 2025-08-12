//
//  WeatherCache.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import Foundation

final class WeatherCache {
    private let defaultsKey = "CachedWeather"
    private let expiry: TimeInterval = 60 * 15 // 15 minutes
    private var inMemory: [String: CachedWeatherEntry] = [:]

    init() {
        loadFromDisk()
    }

    func get(for date: Date) -> WeatherInfo? {
        let key = cacheKey(for: date)
        guard let entry = inMemory[key], Date().timeIntervalSince(entry.timestamp) < expiry else {
            return nil
        }
        return entry.info
    }

    func set(_ info: WeatherInfo, for date: Date) {
        let key = cacheKey(for: date)
        let entry = CachedWeatherEntry(info: info, timestamp: Date())
        inMemory[key] = entry
        saveToDisk()
    }

    private func cacheKey(for date: Date) -> String {
        let components = Calendar.appDefault.dateComponents([.year, .month, .day], from: date)
        return "weather-\(components.year!)-\(components.month!)-\(components.day!)"
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(inMemory) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: CachedWeatherEntry].self, from: data) {
            inMemory = decoded
        }
    }
}
