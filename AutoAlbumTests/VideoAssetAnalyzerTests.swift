import XCTest
import UIKit
@testable import AutoAlbum

final class VideoAssetAnalyzerTests: XCTestCase {
    func testChangingFramesReduceStabilityComparedWithSteadyFrames() throws {
        let analyzer = VideoAssetAnalyzer(imageAnalyzer: MediaAssetAnalyzer())

        let steadyFrames = [
            try makeSolidImage(color: .black),
            try makeSolidImage(color: .black),
            try makeSolidImage(color: .black)
        ]
        let changingFrames = [
            try makeSolidImage(color: .black),
            try makeSolidImage(color: .white),
            try makeSolidImage(color: .black)
        ]

        let steady = try analyzer.analyze(frames: steadyFrames, duration: 12)
        let changing = try analyzer.analyze(frames: changingFrames, duration: 12)

        XCTAssertEqual(steady.sampledFrameCount, 3)
        XCTAssertEqual(changing.sampledFrameCount, 3)
        XCTAssertGreaterThan(steady.stability, changing.stability)
        XCTAssertGreaterThan(changing.motion, 0)
    }

    func testCombinesFrameObservationsAcrossFrames() throws {
        let analyzer = VideoAssetAnalyzer(imageAnalyzer: MediaAssetAnalyzer())
        let frames = [
            try makeSolidImage(color: .white),
            try makeSolidImage(color: .white)
        ]

        let observation = try analyzer.analyze(frames: frames, duration: 8)

        XCTAssertGreaterThanOrEqual(observation.sharpness, 0)
        XCTAssertLessThanOrEqual(observation.sharpness, 1)
        XCTAssertEqual(observation.faces, 0)
    }

    private func makeSolidImage(color: UIColor) throws -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
        }

        return try XCTUnwrap(image.cgImage)
    }
}
