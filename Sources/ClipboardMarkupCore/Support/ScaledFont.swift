import SwiftUI

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

private struct AppThumbnailSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 64
}

public extension EnvironmentValues {
    var appFontScale: Double {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }

    var appThumbnailSize: CGFloat {
        get { self[AppThumbnailSizeKey.self] }
        set { self[AppThumbnailSizeKey.self] = newValue }
    }
}

public extension View {
    func appFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, design: design))
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appFontScale) private var appFontScale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: max(8, size * appFontScale), weight: weight, design: design))
    }
}
