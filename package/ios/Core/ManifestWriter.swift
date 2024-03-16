//
//  ManifestWriter.swift
//  VisionCamera
//
//  Created by Fouad Mirza on 3/15/24.
//

import Foundation

class ManifestWriter {
  private var fileHandle: FileHandle?
  let manifestURL: URL

  init(url: URL,
       fileName: String) {
    let fileName = fileName.hasSuffix(".m3u8") ? fileName : "\(fileName).m3u8"
    manifestURL = url.appendingPathComponent(fileName)
    do {
      if !FileManager.default.fileExists(atPath: manifestURL.path) {
        FileManager.default.createFile(atPath: manifestURL.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: manifestURL)
        fileHandle?.seekToEndOfFile()
      }
    } catch {
      NSLog("Could not create manifest file.")
    }
  }

  func initializeManifest(maxSegmentInterval: Int) {
    guard let fileHandle = fileHandle else { return }
    let newContent = "#EXTM3U\n"
      + "#EXT-X-VERSION:6\n"
      + "#EXT-X-TARGETDURATION:\(maxSegmentInterval)\n"
      + "#EXT-X-MEDIA-SEQUENCE:0\n"
      + "#EXT-X-PLAYLIST-TYPE:VOD\n"
      + "#EXT-X-INDEPENDENT-SEGMENTS\n"

    guard let data = newContent.data(using: .utf8)
    else { return }

    fileHandle.write(data)
  }

  func append(segmentFileURL: URL, segmentDuration: Double?) {
    guard let fileHandle = fileHandle else { return }

    let newContent: String
    if segmentFileURL.pathExtension == "mp4" {
      newContent = "#EXT-X-MAP:URI=\"\(segmentFileURL.lastPathComponent)\"\n"
    } else {
      newContent = "#EXTINF:\(String(format: "%0.6f", segmentDuration ?? 0)),\n"
        + "\(segmentFileURL.lastPathComponent)\n"
    }

    guard let data = newContent.data(using: .utf8)
    else { return }

    fileHandle.write(data)
  }

  func finalizeManifest() {
    guard let fileHandle = fileHandle else { return }

    let newContent = "#EXT-X-ENDLIST\n"
    guard let data = newContent.data(using: .utf8)
    else { return }

    fileHandle.write(data)
    fileHandle.synchronizeFile()
    fileHandle.closeFile()
  }
}
