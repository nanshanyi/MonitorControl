//
//  SunTimeTool.swift
//  MonitorControl
//
//  Created by 南山忆 on 2024/11/20.
//  Copyright © 2024 MonitorControl. All rights reserved.
//

import Foundation
import CoreLocation
import os

class SunTimeTool: NSObject, CLLocationManagerDelegate {
  static let shared = SunTimeTool()
  var solar: Solar?
  private let locationManager = CLLocationManager()
  private var completion: ((Solar?) -> Void)?
  var changeTimer: Timer?
  var currentDate: Date = Date()
  
  override init() {
    super.init()
    resetLocationManager()
  }
  
  func resetLocationManager() {
    locationManager.delegate = self
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager.startUpdatingLocation()
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      if let location = locations.first {
        self.solar = Solar(for: Date(), coordinate: location.coordinate)
        locationManager.stopUpdatingLocation()
      }
    print("Location: \(locations)")
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .notDetermined:
        print("用户尚未决定是否授予权限")
    case .restricted:
        print("位置权限受限")
    case .denied:
        print("用户拒绝了位置权限")
    case .authorizedAlways, .authorizedWhenInUse:
        print("位置权限已授予")
    @unknown default:
        print("未知的权限状态")
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
    print("Error: \(error)")
  }
}

extension SunTimeTool {
  func autoBrightnessWithTime() {
    changeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      guard prefs.bool(forKey: PrefKey.autoChange.rawValue) else { return }
      guard let solar = self.solar,
            Calendar.current.isDate(Date(), inSameDayAs: self.currentDate) else {
        self.currentDate = Date()
        self.resetLocationManager()
        return
      }
      guard let sunrise = solar.sunrise,
            let sunset = solar.sunset else { return }
      let sunriseR = sunrise.addingTimeInterval(TimeInterval(prefs.integer(forKey: PrefKey.sunriseOffset.rawValue)))
      let sunsetOffSet = prefs.float(forKey: PrefKey.sunsetOffset.rawValue)
      let sunsetR = sunset.addingTimeInterval(TimeInterval(sunsetOffSet))
      let sunsetAfter: TimeInterval = 600
      let sunsetEnd = sunset.addingTimeInterval(sunsetAfter)
      guard let otherDisplay = DisplayManager.shared.getOtherDisplays().first else { return }
      let date = Date()
      let dayBrightness = prefs.float(forKey: PrefKey.autoBrightnessDay.rawValue) / 100.0
      let nightBrightness = prefs.float(forKey: PrefKey.autoBrightnessNight.rawValue) / 100.0
      let isSunrise = date > sunriseR && date < sunsetR
      let isSunset = date > sunsetR && date < sunsetEnd
      var result: Float = otherDisplay.getBrightness()
      var needSync = false
      if isSunrise {
        if fabsf(result - dayBrightness) > 0.1 {
          result = dayBrightness
          needSync = true
        }
      } else if isSunset {
        let diff = (dayBrightness - nightBrightness) * (Float(date.timeIntervalSince1970 - sunsetR.timeIntervalSince1970) / (fabsf(sunsetOffSet) + Float(sunsetAfter)))
        result = dayBrightness - diff
        if result > nightBrightness {
          needSync = true
        }
      }
      guard needSync else { return }
      _ = otherDisplay.setBrightness(result, slow: true)
      NotificationCenter.default.post(name: brightnessChangeNotify, object: Int(result * 100), userInfo: nil)
      let slider = otherDisplay.sliderHandler[.brightness]
      slider?.setValue(result, displayID: otherDisplay.identifier)
    }
  }
  
}
  


