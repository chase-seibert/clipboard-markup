import Combine
import Foundation

@MainActor
public final class LibraryPreferences: ObservableObject {
    @Published public private(set) var filter: LibraryFilter
    @Published public private(set) var selectedItemID: UUID?

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.filter = Self.loadFilter(from: userDefaults)
        self.selectedItemID = Self.loadSelectedItemID(from: userDefaults)
    }

    public func setFilter(_ filter: LibraryFilter) {
        self.filter = filter
        userDefaults.set(filter.rawValue, forKey: Keys.filter)
    }

    public func setSelectedItemID(_ selectedItemID: UUID?) {
        self.selectedItemID = selectedItemID

        if let selectedItemID {
            userDefaults.set(selectedItemID.uuidString, forKey: Keys.selectedItemID)
        } else {
            userDefaults.removeObject(forKey: Keys.selectedItemID)
        }
    }

    private static func loadFilter(from userDefaults: UserDefaults) -> LibraryFilter {
        guard let rawValue = userDefaults.string(forKey: Keys.filter),
              let filter = LibraryFilter(rawValue: rawValue)
        else {
            return .images
        }

        return filter
    }

    private static func loadSelectedItemID(from userDefaults: UserDefaults) -> UUID? {
        guard let rawValue = userDefaults.string(forKey: Keys.selectedItemID) else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    private enum Keys {
        static let filter = "library.filter"
        static let selectedItemID = "library.selectedItemID"
    }
}
