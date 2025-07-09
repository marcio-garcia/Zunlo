//
//  LocationManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/8/25.
//

import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var latitude: CLLocationDegrees = 40.0 // Default to Northern Hemisphere (fake)
    
     private let manager = CLLocationManager()
    
     override init() {
         super.init()
         manager.delegate = self
         manager.requestWhenInUseAuthorization()
         manager.startUpdatingLocation()
     }
    
     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         if let loc = locations.first {
             self.latitude = loc.coordinate.latitude
         }
     }
}
