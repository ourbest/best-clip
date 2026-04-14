import XCTest
import UIKit
@testable import AutoAlbum

final class MediaAssetAnalyzerTests: XCTestCase {
    func testAnalyzesImageDataIntoObservation() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
        }

        let data = try XCTUnwrap(image.pngData())
        let observation = try MediaAssetAnalyzer().analyze(imageData: data)

        XCTAssertGreaterThanOrEqual(observation.sharpness, 0)
        XCTAssertLessThanOrEqual(observation.sharpness, 1)
        XCTAssertEqual(observation.faces, 0)
    }
}
