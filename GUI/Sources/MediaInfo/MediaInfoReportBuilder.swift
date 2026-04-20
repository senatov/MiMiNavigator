//
//  MediaInfoReportBuilder.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MediaInfoReportBuilder {
    struct Sections {
        var general: [String] = []
        var image: [String] = []
        var metadata: [String] = []
        var media: [String] = []
        var coordinates: (Double, Double)?
    }

    static func build(url: URL, fast: Bool) async -> (String, (Double, Double)?) {
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)

        do {
            var sections = try makeGeneralSection(for: url, type: type)

            if type?.conforms(to: .image) == true {
                appendImageMetadata(for: url, into: &sections)
            }

            if (type?.conforms(to: .movie) == true || type?.conforms(to: .audio) == true) && !fast {
                await appendMediaMetadata(for: url, into: &sections)
            }

            return (render(sections), sections.coordinates)
        } catch {
            log.error("[MediaInfo] failed to read file info for '\(url.path)': \(error.localizedDescription)")
            return ("Failed to read file info", nil)
        }
    }

    private static func makeGeneralSection(for url: URL, type: UTType?) throws -> Sections {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)

        var sections = Sections()
        sections.general.append("File: \(url.lastPathComponent)")
        sections.general.append("Type: \(url.pathExtension.isEmpty ? "UNKNOWN" : url.pathExtension.uppercased())")
        sections.general.append("UTType: \(type?.identifier ?? "unknown")")
        sections.general.append("Size: \(sizeString) (\(size) bytes)")
        sections.general.append("Path: \(url.path)")

        if let created = attrs[.creationDate] as? Date {
            sections.general.append("Created: \(created.ISO8601Format())")
        }
        if let modified = attrs[.modificationDate] as? Date {
            sections.general.append("Modified: \(modified.ISO8601Format())")
        }

        return sections
    }

    private static func appendImageMetadata(for url: URL, into sections: inout Sections) {
        guard
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        else {
            return
        }

        if let width = metadata[kCGImagePropertyPixelWidth as String],
           let height = metadata[kCGImagePropertyPixelHeight as String] {
            sections.image.append("Resolution: \(width)x\(height)")
        }

        appendValue(metadata[kCGImagePropertyOrientation as String], labeled: "Orientation", into: &sections.image)
        appendValue(metadata[kCGImagePropertyColorModel as String], labeled: "Color Model", into: &sections.image)
        appendValue(metadata[kCGImagePropertyProfileName as String], labeled: "Color Profile", into: &sections.image)

        if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            appendValue(tiff[kCGImagePropertyTIFFMake as String], labeled: "Make", into: &sections.image)
            appendValue(tiff[kCGImagePropertyTIFFModel as String], labeled: "Model", into: &sections.image)
            appendValue(tiff[kCGImagePropertyTIFFSoftware as String], labeled: "Software", into: &sections.image)
        }

        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            appendValue(exif[kCGImagePropertyExifDateTimeOriginal as String], labeled: "Date", into: &sections.image)

            if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                sections.image.append("Exposure: 1/\(Int((1.0 / max(exposure.doubleValue, 0.000001)).rounded())) sec")
            }
            if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                sections.image.append(String(format: "Aperture: f/%.1f", fNumber.doubleValue))
            }
            if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber {
                sections.image.append(String(format: "Focal Length: %.1f mm", focalLength.doubleValue))
            }
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber],
               let iso = isoArray.first {
                sections.image.append("ISO: \(iso.intValue)")
            } else if let iso = exif[kCGImagePropertyExifISOSpeed as String] as? NSNumber {
                sections.image.append("ISO: \(iso.intValue)")
            }
            appendValue(exif[kCGImagePropertyExifLensModel as String], labeled: "Lens", into: &sections.image)

            if let flash = exif[kCGImagePropertyExifFlash as String] as? NSNumber {
                sections.image.append("Flash: \(flash.intValue != 0 ? "Fired" : "No flash")")
            }
            if let whiteBalance = exif[kCGImagePropertyExifWhiteBalance as String] as? NSNumber {
                sections.image.append("White Balance: \(whiteBalance.intValue == 0 ? "Auto" : "Manual")")
            }
            if let subjectDistance = exif[kCGImagePropertyExifSubjectDistance as String] as? NSNumber {
                sections.image.append(String(format: "Subject Distance: %.2f m", subjectDistance.doubleValue))
            }
        }

        if let dpi = metadata[kCGImagePropertyDPIWidth as String] as? NSNumber {
            sections.image.append(String(format: "DPI: %.0f", dpi.doubleValue))
        }
        if let depth = metadata[kCGImagePropertyDepth as String] as? NSNumber {
            sections.image.append("Bit Depth: \(depth.intValue)")
        }

        if let iptc = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            appendValue(iptc[kCGImagePropertyIPTCCaptionAbstract as String], labeled: "Caption", into: &sections.image)
            appendValue(iptc[kCGImagePropertyIPTCCopyrightNotice as String], labeled: "Copyright", into: &sections.image)

            if let keywords = iptc[kCGImagePropertyIPTCKeywords as String] as? [String], !keywords.isEmpty {
                sections.image.append("Keywords: \(keywords.joined(separator: ", "))")
            }
        }

        if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let latitudeValue = gps[kCGImagePropertyGPSLatitude as String],
           let longitudeValue = gps[kCGImagePropertyGPSLongitude as String] {
            let latitude = (latitudeValue as? NSNumber)?.doubleValue ?? 0
            let longitude = (longitudeValue as? NSNumber)?.doubleValue ?? 0
            let latitudeDirection = latitude >= 0 ? "N" : "S"
            let longitudeDirection = longitude >= 0 ? "E" : "W"

            sections.image.append(
                String(format: "GPS: %.6f° %@, %.6f° %@", abs(latitude), latitudeDirection, abs(longitude), longitudeDirection)
            )
            if let altitude = gps[kCGImagePropertyGPSAltitude as String] as? NSNumber {
                sections.image.append(String(format: "Altitude: %.1f m", altitude.doubleValue))
            }
            if let direction = gps[kCGImagePropertyGPSImgDirection as String] as? NSNumber {
                sections.image.append(String(format: "Direction: %.1f°", direction.doubleValue))
            }

            sections.coordinates = (latitude, longitude)
        }
    }

    private static func appendMediaMetadata(for url: URL, into sections: inout Sections) async {
        let asset = AVURLAsset(url: url)

        if let durationTime = try? await asset.load(.duration) {
            let duration = CMTimeGetSeconds(durationTime)
            if duration.isFinite && duration > 0 {
                sections.media.append("Duration: \(formatDuration(duration))")
            }
        }

        if let commonMetadata = try? await asset.load(.commonMetadata) {
            for item in commonMetadata {
                guard let key = item.commonKey?.rawValue,
                      let value = try? await item.load(.stringValue),
                      !value.isEmpty else { continue }

                switch key {
                case "creator":
                    sections.metadata.append("Creator: \(value)")
                case "software":
                    sections.metadata.append("Software: \(value)")
                case "title":
                    sections.metadata.append("Title: \(value)")
                case "artist":
                    sections.metadata.append("Artist: \(value)")
                case "albumName":
                    sections.metadata.append("Album: \(value)")
                default:
                    break
                }
            }
        }

        await appendVideoTrackMetadata(from: asset, into: &sections.media)
        await appendAudioTrackMetadata(from: asset, into: &sections.media)
    }

    private static func appendVideoTrackMetadata(from asset: AVURLAsset, into media: inout [String]) async {
        guard
            let videoTracks = try? await asset.loadTracks(withMediaType: .video),
            let videoTrack = videoTracks.first
        else {
            return
        }

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

        if let naturalSize = try? await videoTrack.load(.naturalSize),
           naturalSize.height > 0 {
            let ratio = naturalSize.width / naturalSize.height
            let label: String
            if abs(ratio - 16.0 / 9.0) < 0.05 {
                label = "16:9"
            } else if abs(ratio - 4.0 / 3.0) < 0.05 {
                label = "4:3"
            } else if abs(ratio - 21.0 / 9.0) < 0.1 {
                label = "21:9"
            } else {
                label = String(format: "%.2f:1", ratio)
            }
            media.append("Aspect Ratio: \(label)")
        }

        if let formatDescriptions = try? await videoTrack.load(.formatDescriptions),
           let firstDescription = formatDescriptions.first {
            media.append("Video Codec: \(fourCharCodeToString(CMFormatDescriptionGetMediaSubType(firstDescription)))")
        }
    }

    private static func appendAudioTrackMetadata(from asset: AVURLAsset, into media: inout [String]) async {
        guard
            let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
            let audioTrack = audioTracks.first
        else {
            return
        }

        media.append("Audio Track: present")

        if let languageCode = try? await audioTrack.load(.languageCode), !languageCode.isEmpty {
            media.append("Audio Language: \(languageCode)")
        }

        if let bitRate = try? await audioTrack.load(.estimatedDataRate), bitRate > 0 {
            media.append(String(format: "Audio Bitrate: %.2f kbps", bitRate / 1000.0))
        }

        if let formatDescriptions = try? await audioTrack.load(.formatDescriptions),
           let firstDescription = formatDescriptions.first {
            media.append("Audio Codec: \(fourCharCodeToString(CMFormatDescriptionGetMediaSubType(firstDescription)))")

            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(firstDescription)?.pointee {
                media.append(String(format: "Sample Rate: %.0f Hz", asbd.mSampleRate))
                media.append("Channels: \(asbd.mChannelsPerFrame)")
            }
        }
    }

    private static func render(_ sections: Sections) -> String {
        var result: [String] = []

        append(sectionLines: sections.general, title: nil, into: &result)
        append(sectionLines: sections.image, title: "Image", into: &result)
        append(sectionLines: sections.metadata, title: "Metadata", into: &result)
        append(sectionLines: sections.media, title: "Media", into: &result)

        return result.joined(separator: "\n")
    }

    private static func append(sectionLines: [String], title: String?, into result: inout [String]) {
        guard !sectionLines.isEmpty else { return }
        if !result.isEmpty {
            result.append("")
        }
        if let title {
            result.append("--- \(title) ---")
        }
        result.append(contentsOf: sectionLines)
    }

    private static func appendValue(_ value: Any?, labeled label: String, into target: inout [String]) {
        guard let value else { return }
        target.append("\(label): \(value)")
    }

    private static func formatDuration(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff),
        ]

        return String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
