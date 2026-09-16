// SystemIconNormalizer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Crops transparent system-icon padding and produces a Retina-ready row icon.

import AppKit

// MARK: - System Icon Normalizer
enum SystemIconNormalizer {
    static let logicalSize = NSSize(width: 32, height: 32)
    static let pixelDimension = 64
    private static let alphaThreshold: UInt8 = 20
    private static let occupancy: CGFloat = 0.90
    // MARK: - Normalize
    @MainActor
    static func normalize(_ image: NSImage) -> NSImage {
        guard let source = sourceImage(from: image),
              let sourceContext = bitmapContext(),
              let sourceData = sourceContext.data
        else { return sizedCopy(of: image) }
        drawAspectFit(source, in: sourceContext)
        let bytes = sourceData.bindMemory(to: UInt8.self, capacity: pixelDimension * pixelDimension * 4)
        guard let bounds = alphaBounds(bytes: bytes) else { return sizedCopy(of: image) }
        guard let cropped = sourceContext.makeImage()?.cropping(to: bounds),
              let outputContext = bitmapContext()
        else { return sizedCopy(of: image) }
        outputContext.interpolationQuality = .high
        outputContext.draw(cropped, in: fittedDestinationRect(for: bounds))
        guard let output = outputContext.makeImage() else { return sizedCopy(of: image) }
        return NSImage(cgImage: output, size: logicalSize)
    }
    // MARK: - Source Image
    @MainActor
    private static func sourceImage(from image: NSImage) -> CGImage? {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
    // MARK: - Bitmap Context
    private static func bitmapContext() -> CGContext? {
        CGContext(
            data: nil,
            width: pixelDimension,
            height: pixelDimension,
            bitsPerComponent: 8,
            bytesPerRow: pixelDimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
    // MARK: - Initial Draw
    private static func drawAspectFit(_ image: CGImage, in context: CGContext) {
        let scale = min(
            CGFloat(pixelDimension) / CGFloat(image.width),
            CGFloat(pixelDimension) / CGFloat(image.height)
        )
        let width = CGFloat(image.width) * scale
        let height = CGFloat(image.height) * scale
        let rect = CGRect(
            x: (CGFloat(pixelDimension) - width) / 2,
            y: (CGFloat(pixelDimension) - height) / 2,
            width: width,
            height: height
        )
        context.interpolationQuality = .high
        context.draw(image, in: rect)
    }
    // MARK: - Alpha Bounds
    private static func alphaBounds(bytes: UnsafePointer<UInt8>) -> CGRect? {
        var minX = pixelDimension
        var minY = pixelDimension
        var maxX = -1
        var maxY = -1
        for y in 0..<pixelDimension {
            for x in 0..<pixelDimension where bytes[(y * pixelDimension + x) * 4 + 3] > alphaThreshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
    // MARK: - Destination Geometry
    static func fittedDestinationRect(for sourceBounds: CGRect) -> CGRect {
        let available = CGFloat(pixelDimension) * occupancy
        let scale = min(available / sourceBounds.width, available / sourceBounds.height)
        let width = sourceBounds.width * scale
        let height = sourceBounds.height * scale
        return CGRect(
            x: (CGFloat(pixelDimension) - width) / 2,
            y: (CGFloat(pixelDimension) - height) / 2,
            width: width,
            height: height
        ).integral
    }
    // MARK: - Fallback
    @MainActor
    private static func sizedCopy(of image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = logicalSize
        return copy
    }
}
