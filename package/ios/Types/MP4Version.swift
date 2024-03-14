//
//  MP4Version.swift
//  VisionCamera
//
//  Created by Joey Priest on 3/14/24.
//

import AVFoundation
import Foundation

/**
 The version of MP4
 */
enum MP4Version: String, JSUnionValue {
  /**
      Standard mp4
   */
  case standard
  /**
    Fragmented mp4
   */
  case fragmented

  init(jsValue: String) throws {
    if let parsed = MP4Version(rawValue: jsValue) {
      self = parsed
    } else {
      throw CameraError.parameter(.invalid(unionName: "mp4Version", receivedValue: jsValue))
    }
  }

  var jsValue: String {
    return rawValue
  }
}
