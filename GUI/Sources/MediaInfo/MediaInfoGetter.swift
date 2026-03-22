import AppKit
//
//  MediaInfoGetter.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import Foundation
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

final class MediaInfoGetter: @unchecked Sendable {

    func getMediaInfoToFile(url: URL, fast: Bool = false) {
        log.info("[MediaInfo] request file='\(url.path)'")

        Task { @MainActor in
            MediaInfoPanel.shared.show(title: "📦 Media Info", text: "Processing…")
        }

        Task.detached(priority: .userInitiated) { [url, fast] in
            let (info, coords) = await Self.buildInfo(url: url, fast: fast)
            await MainActor.run {
                MediaInfoPanel.shared.update(title: "📦 Media Info", text: info, coordinates: coords)
            }
        }
    }

    // MARK: - Core

    private static func buildInfo(url: URL, fast: Bool) async -> (String, (Double, Double)?) {
        let fileName = url.lastPathComponent
        log.debug("[MediaInfo] building info for '\(fileName)'")

        var coords: (Double, Double)? = nil

        // Structured sections
        var general: [String] = []
        var image: [String] = []
        var media: [String] = []
        var metadataSection: [String] = []

        general.append("File: \(fileName)")
        let extUpper = url.pathExtension.isEmpty ? "UNKNOWN" : url.pathExtension.uppercased()
        general.append("Type: \(extUpper)")
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        if let type {
            general.append("UTType: \(type.identifier)")
        } else {
            general.append("UTType: unknown")
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            general.append("Size: \(sizeStr) (\(size) bytes)")
            general.append("Path: \(url.path)")
            if let created = attrs[.creationDate] as? Date {
                general.append("Created: \(created.ISO8601Format())")
            }
            if let modified = attrs[.modificationDate] as? Date {
                general.append("Modified: \(modified.ISO8601Format())")
            }
        } catch {
            return ("Failed to read file info", nil)
        }

        // MARK: - Image metadata
        if type?.conforms(to: .image) == true {
            image.append("--- Image ---")
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let metadata = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] {

                if let w = metadata[kCGImagePropertyPixelWidth as String],
                   let h = metadata[kCGImagePropertyPixelHeight as String] {
                    image.append("Resolution: \(w)x\(h)")
                }

                if let orientation = metadata[kCGImagePropertyOrientation as String] {
                    image.append("Orientation: \(orientation)")
                }

                if let colorModel = metadata[kCGImagePropertyColorModel as String] {
                    image.append("Color Model: \(colorModel)")
                }

                if let profileName = metadata[kCGImagePropertyProfileName as String] {
                    image.append("Color Profile: \(profileName)")
                }

                if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    if let make = tiff[kCGImagePropertyTIFFMake as String] {
                        image.append("Make: \(make)")
                    }
                    if let model = tiff[kCGImagePropertyTIFFModel as String] {
                        image.append("Model: \(model)")
                    }
                    if let software = tiff[kCGImagePropertyTIFFSoftware as String] {
                        image.append("Software: \(software)")
                    }
                }

                if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    if let date = exif[kCGImagePropertyExifDateTimeOriginal as String] {
                        image.append("Date: \(date)")
                    }
                    if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                        image.append("Exposure: 1/\(Int((1.0 / max(exposure.doubleValue, 0.000001)).rounded())) sec")
                    }
                    if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                        image.append(String(format: "Aperture: f/%.1f", fNumber.doubleValue))
                    }
                    if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber {
                        image.append(String(format: "Focal Length: %.1f mm", focalLength.doubleValue))
                    }
                    if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber],
                       let iso = isoArray.first {
                        image.append("ISO: \(iso.intValue)")
                    } else if let iso = exif[kCGImagePropertyExifISOSpeed as String] as? NSNumber {
                        image.append("ISO: \(iso.intValue)")
                    }
                    if let lensModel = exif[kCGImagePropertyExifLensModel as String] {
                        image.append("Lens: \(lensModel)")
                    }
                }

                if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                   let lat = gps[kCGImagePropertyGPSLatitude as String],
                   let lon = gps[kCGImagePropertyGPSLongitude as String] {
                    let latVal = (lat as? NSNumber)?.doubleValue ?? 0
                    let lonVal = (lon as? NSNumber)?.doubleValue ?? 0
                    let latDir = latVal >= 0 ? "N" : "S"
                    let lonDir = lonVal >= 0 ? "E" : "W"
                    image.append(String(format: "GPS: %.6f° %@, %.6f° %@", abs(latVal), latDir, abs(lonVal), lonDir))
                    if let altitude = gps[kCGImagePropertyGPSAltitude as String] as? NSNumber {
                        image.append(String(format: "Altitude: %.1f m", altitude.doubleValue))
                    }
                    if let direction = gps[kCGImagePropertyGPSImgDirection as String] as? NSNumber {
                        image.append(String(format: "Direction: %.1f°", direction.doubleValue))
                    }
                    coords = (latVal, lonVal)
                }
            }
        }

        // MARK: - Video / Audio metadata
        if type?.conforms(to: .movie) == true || type?.conforms(to: .audio) == true {
            guard !fast else {
                var result: [String] = []

                if !general.isEmpty {
                    result.append(contentsOf: general)
                }

                if !image.isEmpty {
                    result.append("")
                    result.append("--- Image ---")
                    result.append(contentsOf: image)
                }

                if !metadataSection.isEmpty {
                    result.append("")
                    result.append("--- Metadata ---")
                    result.append(contentsOf: metadataSection)
                }

                if !media.isEmpty {
                    result.append("")
                    result.append("--- Media ---")
                    result.append(contentsOf: media)
                }

                return (result.joined(separator: "\n"), coords)
            }
            let asset = AVURLAsset(url: url)

            // Duration
            if let durationTime = try? await asset.load(.duration) {
                let duration = CMTimeGetSeconds(durationTime)
                if duration.isFinite && duration > 0 {
                    let totalSeconds = Int(duration)
                    let hours = totalSeconds / 3600
                    let minutes = (totalSeconds % 3600) / 60
                    let seconds = totalSeconds % 60
                    media.append(String(format: "Duration: %02d:%02d:%02d", hours, minutes, seconds))
                }
            }

            if let commonMetadata = try? await asset.load(.commonMetadata) {
                for item in commonMetadata {
                    guard let key = item.commonKey?.rawValue else { continue }
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        switch key {
                        case "creator":
                            metadataSection.append("Creator: \(v)")
                        case "software":
                            metadataSection.append("Software: \(v)")
                        case "title":
                            metadataSection.append("Title: \(v)")
                        case "artist":
                            metadataSection.append("Artist: \(v)")
                        case "albumName":
                            metadataSection.append("Album: \(v)")
                        default:
                            break
                        }
                    }
                }
            }

            // Video
            if let videoTracks = try? await asset.loadTracks(withMediaType: .video),
               let videoTrack = videoTracks.first {

                if let naturalSize = try? await videoTrack.load(.naturalSize),
                   let transform = try? await videoTrack.load(.preferredTransform) {
                    let size = naturalSize.applying(transform)
                    media.append("Resolution: \(Int(abs(size.width)))x\(Int(abs(size.height)))")
                }

                if let frameRate = try? await videoTrack.load(.nominalFrameRate), frameRate > 0 {
                    media.append(String(format: "FPS: %.2f", frameRate))
                }

                if let bitRate = try? await videoTrack.load(.estimatedDataRate), bitRate > 0 {
                    media.append(String(format: "Video Bitrate: %.2f Mbps", bitRate / 1_000_000.0))
                }

                if let formatDescriptions = try? await videoTrack.load(.formatDescriptions),
                   let firstDescription = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(firstDescription)
                    let codec = fourCharCodeToString(mediaSubType)
                    media.append("Video Codec: \(codec)")
                }
            }

            // Audio
            if let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
               let audioTrack = audioTracks.first {
                media.append("Audio Track: present")

                if let bitRate = try? await audioTrack.load(.estimatedDataRate), bitRate > 0 {
                    media.append(String(format: "Audio Bitrate: %.2f kbps", bitRate / 1000.0))
                }

                if let formatDescriptions = try? await audioTrack.load(.formatDescriptions),
                   let firstDescription = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(firstDescription)
                    let codec = fourCharCodeToString(mediaSubType)
                    media.append("Audio Codec: \(codec)")

                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(firstDescription)?.pointee {
                        media.append(String(format: "Sample Rate: %.0f Hz", asbd.mSampleRate))
                        media.append("Channels: \(asbd.mChannelsPerFrame)")
                    }
                }
            }
        }

        var result: [String] = []

        if !general.isEmpty {
            result.append(contentsOf: general)
        }

        if !image.isEmpty {
            result.append("")
            result.append("--- Image ---")
            result.append(contentsOf: image)
        }

        if !metadataSection.isEmpty {
            result.append("")
            result.append("--- Metadata ---")
            result.append(contentsOf: metadataSection)
        }

        if !media.isEmpty {
            result.append("")
            result.append("--- Media ---")
            result.append(contentsOf: media)
        }

        return (result.joined(separator: "\n"), coords)
    }

    private static func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]

        return String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
