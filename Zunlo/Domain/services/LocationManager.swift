//
//  LocationManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/8/25.
//

import CoreLocation

class LocationManager: NSObject, ObservableObject {
    @Published var latitude: CLLocationDegrees = 40.0 // Default to Northern Hemisphere (fake)
    @Published var status: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func checkStatus() {
        status = manager.authorizationStatus
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    func stop() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first {
            latitude = loc.coordinate.latitude
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
