import Combine
import Foundation

@MainActor
public final class AppearancePreferences: ObservableObject {
    public static let minimumFontScale = 0.85
    public static let maximumFontScale = 1.45
    public static let defaultFontScale = 1.0
    public static let fontScaleStep = 0.1
    public static let minimumThumbnailSize = 44.0
    public static let maximumThumbnailSize = 300.0
    public static let defaultThumbnailSize = 64.0
    public static let thumbnailSizeStep = 4.0

    @Published public private(set) var fontScale: Double
    @Published public private(set) var thumbnailSize: Double

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let stored = userDefaults.object(forKey: Keys.fontScale) == nil
            ? Self.defaultFontScale
            : userDefaults.double(forKey: Keys.fontScale)
        self.fontScale = Self.clamp(stored)

        let storedThumbnailSize = userDefaults.object(forKey: Keys.thumbnailSize) == nil
            ? Self.defaultThumbnailSize
            : userDefaults.double(forKey: Keys.thumbnailSize)
        self.thumbnailSize = Self.clampThumbnailSize(storedThumbnailSize)
    }

    public var percentageLabel: String {
        "\(Int(round(fontScale * 100)))%"
    }

    public var thumbnailSizeLabel: String {
        "\(Int(round(thumbnailSize))) pt"
    }

    public func increaseFontScale() {
        setFontScale(fontScale + Self.fontScaleStep)
    }

    public func decreaseFontScale() {
        setFontScale(fontScale - Self.fontScaleStep)
    }

    public func resetFontScale() {
        setFontScale(Self.defaultFontScale)
    }

    public func resetThumbnailSize() {
        setThumbnailSize(Self.defaultThumbnailSize)
    }

    public func setFontScale(_ fontScale: Double) {
        let clamped = Self.clamp(fontScale)
        self.fontScale = clamped
        userDefaults.set(clamped, forKey: Keys.fontScale)
    }

    public func setThumbnailSize(_ thumbnailSize: Double) {
        let clamped = Self.clampThumbnailSize(thumbnailSize)
        self.thumbnailSize = clamped
        userDefaults.set(clamped, forKey: Keys.thumbnailSize)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, minimumFontScale), maximumFontScale)
    }

    private static func clampThumbnailSize(_ value: Double) -> Double {
        min(max(value, minimumThumbnailSize), maximumThumbnailSize)
    }

    private enum Keys {
        static let fontScale = "appearance.fontScale"
        static let thumbnailSize = "appearance.thumbnailSize"
    }
}
