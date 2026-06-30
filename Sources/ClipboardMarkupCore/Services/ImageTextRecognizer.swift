import AppKit
import Foundation
import Vision

public enum ImageTextRecognizer {
    public static func transcript(from image: NSImage) async -> String? {
        guard let tiffData = image.tiffRepresentation else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard let bitmap = NSBitmapImageRep(data: tiffData),
                      let cgImage = bitmap.cgImage
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    let transcript = request.results?
                        .compactMap { observation in
                            observation.topCandidates(1).first?.string
                        }
                        .joined(separator: " ")
                    continuation.resume(returning: ClipboardItem.normalizedTranscript(transcript))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
