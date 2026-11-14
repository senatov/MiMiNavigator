// ThumbnailImageLoader.swift
// MiMiNavigator
//
// Description: Content-based, size-limited image thumbnails for the file grid.

import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Thumbnail Image Loader
enum ThumbnailImageLoader {
    // MARK: - Load Image
    static func image(for url: URL, pixelEdge: Int) async -> NSImage? {
        guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true else { return nil }
        let image = await Task.detached(priority: .utility) { () -> CGImage? in
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, pixelEdge),
                kCGImageSourceShouldCacheImmediately: true,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        guard !Task.isCancelled, let image else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
