#if canImport(XCTest)
import CoreGraphics
import XCTest
@testable import P5Swift

final class P5RendererTests: XCTestCase {
    func testCircleUsesDiameterLikeP5JS() throws {
        let renderer = P5Renderer()
        renderer.size = CGSize(width: 20, height: 20)
        renderer.addOperation(.noStroke)
        renderer.addOperation(.fill(CGColor(gray: 1, alpha: 1)))
        renderer.addOperation(.ellipse(x: 10, y: 10, width: 8, height: 8))

        let bitmap = try XCTUnwrap(Bitmap(width: 20, height: 20))
        renderer.render(in: bitmap.context)

        XCTAssertEqual(bitmap.alpha(atX: 10, y: 10), 255)
        XCTAssertEqual(bitmap.alpha(atX: 5, y: 10), 0)
    }

    func testPushAndPopRestoreDrawingStyle() throws {
        let renderer = P5Renderer()
        renderer.size = CGSize(width: 3, height: 1)
        renderer.addOperation(.noStroke)
        renderer.addOperation(.fill(CGColor(gray: 1, alpha: 1)))
        renderer.addOperation(.push)
        renderer.addOperation(.noFill)
        renderer.addOperation(.rect(x: 0, y: 0, width: 1, height: 1))
        renderer.addOperation(.pop)
        renderer.addOperation(.rect(x: 1, y: 0, width: 1, height: 1))

        let bitmap = try XCTUnwrap(Bitmap(width: 3, height: 1))
        renderer.render(in: bitmap.context)

        XCTAssertEqual(bitmap.alpha(atX: 0, y: 0), 0)
        XCTAssertEqual(bitmap.alpha(atX: 1, y: 0), 255)
    }
}

private final class Bitmap {
    let context: CGContext
    private let bytes: UnsafeMutablePointer<UInt8>
    private let width: Int
    private let height: Int

    init?(width: Int, height: Int) {
        let bytesPerRow = width * 4
        let bytes = UnsafeMutablePointer<UInt8>.allocate(
            capacity: bytesPerRow * height
        )
        bytes.initialize(repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            bytes.deallocate()
            return nil
        }

        self.context = context
        self.bytes = bytes
        self.width = width
        self.height = height
    }

    func alpha(atX x: Int, y: Int) -> UInt8 {
        precondition((0..<width).contains(x) && (0..<height).contains(y))
        return bytes[(y * width + x) * 4 + 3]
    }

    deinit {
        bytes.deallocate()
    }
}
#endif
