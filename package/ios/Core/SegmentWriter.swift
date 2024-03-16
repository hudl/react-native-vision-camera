//
//  SegmentWriter.swift
//  VisionCamera
//
//  Created by Fouad Mirza on 3/14/24.
//

import Foundation

// MARK: - SegmentInfo

struct SegmentInfo {
  var order: UInt
  var fileURL: URL
  var recordedAt: Date
  var duration: TimeInterval
}

// MARK: - SegmentWriter

@available(iOS 14.0, *)
class SegmentWriter: NSObject, AVAssetWriterDelegate {
  private var segmentCount: UInt = 0
  private let url: URL
  private let fileNamePrefix: String
  private var manifestWriter: ManifestWriter?

  public let manifestURL: URL?

  init(url: URL,
       fileNamePrefix: String,
       segmentInterval: Double,
       createManifest: Bool = true) {
    self.url = url
    self.fileNamePrefix = fileNamePrefix

    if createManifest {
      // Actual segment durations can be milliseconds longer than the preferred configuration
      let maxSegmentInterval = Int(floor(segmentInterval)) + 1
      manifestWriter = ManifestWriter(url: url, fileName: fileNamePrefix)
      manifestWriter?.initializeManifest(maxSegmentInterval: maxSegmentInterval)
    }
    manifestURL = manifestWriter?.manifestURL
  }

  func assetWriter(_: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType: AVAssetSegmentType, segmentReport: AVAssetSegmentReport?) {
    let fileName = generateFileName(for: segmentType)
    let fileURL = url.appendingPathComponent(fileName)
    do {
      try segmentData.write(to: fileURL)
      NSLog("[SegmentWriter] Wrote segment file: \(fileURL.path)")

      segmentOutputHandler(segmentOrder: segmentCount, segmentFileURL: fileURL, segmentType: segmentType, segmentReport: segmentReport)
    } catch {
      NSLog("[SegmentWriter] Failed to write segment file: \(fileURL.path)")
    }

    segmentCount += 1
  }

  private func segmentOutputHandler(segmentOrder: UInt, segmentFileURL: URL, segmentType: AVAssetSegmentType, segmentReport: AVAssetSegmentReport?) {
    let duration: Double
    let recordedAt: Date
    if segmentType == .initialization {
      duration = 0
      recordedAt = getModifiedDate(for: segmentFileURL)
    } else {
      let timingTrackReport = getTrackReport(for: segmentReport!)
      duration = timingTrackReport.duration.seconds
      guard duration > 0 else {
        NSLog("[SegmentWriter] Skipping segment without video frames: \(segmentFileURL.relativePath)")
        return
      }
      recordedAt = getModifiedDate(for: segmentFileURL).addingTimeInterval(-1 * duration)
    }
    let segmentInfo = SegmentInfo(order: segmentOrder, fileURL: segmentFileURL, recordedAt: recordedAt, duration: duration)
    manifestWriter?.append(segmentFileURL: segmentFileURL, segmentDuration: duration)
    NotificationCenter.default.post(name: .SegmentCreated, object: self, userInfo: ["segmentInfo": segmentInfo])
  }

  private func generateFileName(for segmentType: AVAssetSegmentType) -> String {
    let baseFileName = "\(fileNamePrefix)-\(segmentCount)"
    switch segmentType {
    case .initialization:
      return "\(baseFileName)-init.mp4"
    case .separable:
      return "\(baseFileName).m4s"
    @unknown default:
      return "\(baseFileName)"
    }
  }

  private func getModifiedDate(for url: URL) -> Date {
    let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return fileAttributes?[FileAttributeKey.modificationDate] as? Date ?? Date()
  }

  private func getTrackReport(for segmentReport: AVAssetSegmentReport, of mediaType: AVMediaType = .video) -> AVAssetSegmentTrackReport {
    return segmentReport.trackReports.first(where: { $0.mediaType == mediaType })!
  }
}

@available(iOS 14.0, *)
extension SegmentWriter {
  func finishWriting() {
    manifestWriter?.finalizeManifest()
  }
}

extension Notification.Name {
  @available(iOS 14.0, *)
  static let SegmentCreated: NSNotification.Name = .init("SegmentCreated")
}
