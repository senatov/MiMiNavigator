import CoreGraphics
import ImageIO
import XCTest

@testable import MiMiNavigator

// MARK: - Thumbnail Image Loader Tests
@MainActor
final class ThumbnailImageLoaderTests: XCTestCase {
    // MARK: - Mismatched Extension
    func testJPEGContentWithPNGExtensionProducesBoundedThumbnail() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let context = try XCTUnwrap(CGContext(data: nil, width: 160, height: 80, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 80))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let loaded = await ThumbnailImageLoader.image(for: url, pixelEdge: 64)
        let thumbnail = try XCTUnwrap(loaded)
        XCTAssertLessThanOrEqual(thumbnail.size.width, 64)
        XCTAssertLessThanOrEqual(thumbnail.size.height, 64)
        XCTAssertGreaterThan(thumbnail.size.width, thumbnail.size.height)
    }
}
