import AppKit
import Foundation
import Vision

public struct ImageTextRecognitionResult: Equatable {
    public var transcript: String?
    public var thumbnailFocusRect: NormalizedRect?

    public init(transcript: String?, thumbnailFocusRect: NormalizedRect?) {
        self.transcript = ClipboardItem.normalizedTranscript(transcript)
        self.thumbnailFocusRect = thumbnailFocusRect
    }
}

public enum ImageTextRecognizer {
    public static func recognize(in image: NSImage) async -> ImageTextRecognitionResult {
        guard let tiffData = image.tiffRepresentation else {
            return ImageTextRecognitionResult(transcript: nil, thumbnailFocusRect: nil)
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard let bitmap = NSBitmapImageRep(data: tiffData),
                      let cgImage = bitmap.cgImage
                else {
                    continuation.resume(returning: ImageTextRecognitionResult(transcript: nil, thumbnailFocusRect: nil))
                    return
                }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let transcript = observations
                        .compactMap { observation in
                            observation.topCandidates(1).first?.string
                        }
                        .joined(separator: " ")
                    continuation.resume(
                        returning: ImageTextRecognitionResult(
                            transcript: transcript,
                            thumbnailFocusRect: thumbnailFocusRect(from: observations)
                        )
                    )
                } catch {
                    continuation.resume(returning: ImageTextRecognitionResult(transcript: nil, thumbnailFocusRect: nil))
                }
            }
        }
    }

    public static func transcript(from image: NSImage) async -> String? {
        await recognize(in: image).transcript
    }

    private static func thumbnailFocusRect(from observations: [VNRecognizedTextObservation]) -> NormalizedRect? {
        let candidates = observations.compactMap { observation -> TextBandCandidate? in
            guard let text = observation.topCandidates(1).first?.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            return TextBandCandidate(
                rect: observation.boundingBox,
                score: max(1, text.count)
            )
        }

        guard !candidates.isEmpty else {
            return nil
        }

        let bestBand = candidates
            .map { candidate in
                let nearby = candidates.filter {
                    abs($0.rect.midY - candidate.rect.midY) <= 0.08
                }
                let score = nearby.reduce(0) { $0 + $1.score }
                let union = nearby.dropFirst().reduce(nearby[0].rect) { $0.union($1.rect) }
                return TextBandCandidate(rect: union, score: score)
            }
            .max { left, right in
                if left.score == right.score {
                    return left.rect.midY < right.rect.midY
                }
                return left.score < right.score
            }

        guard let bestBand else {
            return nil
        }

        let cropHeight = max(0.18, min(0.34, bestBand.rect.height * 3.2))
        let centerYFromTop = 1 - bestBand.rect.midY
        return NormalizedRect(
            x: 0,
            y: centerYFromTop - cropHeight / 2,
            width: 1,
            height: cropHeight
        )
    }
}

private struct TextBandCandidate {
    let rect: CGRect
    let score: Int
}
