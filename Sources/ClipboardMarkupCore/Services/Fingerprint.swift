import CryptoKit
import Foundation

enum Fingerprint {
    static func make(prefix: String, data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix):\(hex)"
    }

    static func make(prefix: String, string: String) -> String {
        make(prefix: prefix, data: Data(string.utf8))
    }
}
