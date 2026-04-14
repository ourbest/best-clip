import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import CoreGraphics
import Vision

struct MediaAssetObservation {
    let faces: Int
    let ocrText: String?
    let sharpness: Double
}

final class MediaAssetAnalyzer {
    private let context = CIContext(options: nil)

    func analyze(imageData: Data) throws -> MediaAssetObservation {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AnalyzerError.unreadableImage
        }

        return try analyze(image: image)
    }

    func analyze(image: CGImage) throws -> MediaAssetObservation {
        let faces = try detectFaces(in: image)
        let ocrText = try recognizeText(in: image)
        let sharpness = estimateSharpness(in: image)
        return MediaAssetObservation(faces: faces, ocrText: ocrText, sharpness: sharpness)
    }

    private func detectFaces(in image: CGImage) throws -> Int {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.count ?? 0
    }

    private func recognizeText(in image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let text = request.results?
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .joined(separator: "\n")

        return text?.isEmpty == false ? text : nil
    }

    private func estimateSharpness(in image: CGImage) -> Double {
        let ciImage = CIImage(cgImage: image)
        let edges = ciImage.applyingFilter("CIEdges", parameters: ["inputIntensity": 1.0])

        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = edges
        averageFilter.extent = edges.extent

        guard let outputImage = averageFilter.outputImage else {
            return 0.5
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let intensity = (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3.0 * 255.0)
        return min(max(intensity * 1.5, 0.0), 1.0)
    }
}

enum AnalyzerError: Error {
    case unreadableImage
}
