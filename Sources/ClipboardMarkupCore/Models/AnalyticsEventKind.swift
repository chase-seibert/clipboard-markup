import Foundation

public enum AnalyticsEventKind: Equatable {
    case appOpen
    case appWindowOpened
    case appMenuBarOpened
    case appSessionHeartbeat
    case clipCaptured(AnalyticsClipCaptureKind)
    case clipAction(AnalyticsClipAction)
    case libraryFilterChanged(AnalyticsLibraryFilter)
    case searchOpened
    case searchSubmitted
    case settingsOpened
    case settingsSectionOpened(AnalyticsSettingsSection)
    case storageLocationChanged(AnalyticsStorageProvider)

    var type: String {
        switch self {
        case .appOpen:
            "app.open"
        case .appWindowOpened:
            "app.window_opened"
        case .appMenuBarOpened:
            "app.menu_bar_opened"
        case .appSessionHeartbeat:
            "app.session_heartbeat"
        case .clipCaptured:
            "clip.captured"
        case .clipAction:
            "clip.action"
        case .libraryFilterChanged:
            "library.filter_changed"
        case .searchOpened:
            "search.opened"
        case .searchSubmitted:
            "search.submitted"
        case .settingsOpened:
            "settings.opened"
        case .settingsSectionOpened:
            "settings.section_opened"
        case .storageLocationChanged:
            "storage.location_changed"
        }
    }

    var value: String? {
        switch self {
        case let .clipCaptured(kind):
            kind.rawValue
        case let .clipAction(action):
            action.rawValue
        case let .libraryFilterChanged(filter):
            filter.rawValue
        case let .settingsSectionOpened(section):
            section.rawValue
        case let .storageLocationChanged(provider):
            provider.rawValue
        case .appOpen,
             .appWindowOpened,
             .appMenuBarOpened,
             .appSessionHeartbeat,
             .searchOpened,
             .searchSubmitted,
             .settingsOpened:
            nil
        }
    }
}

public enum AnalyticsClipCaptureKind: String, Codable, CaseIterable {
    case text
    case richText = "rich_text"
    case image
}

public enum AnalyticsClipAction: String, Codable, CaseIterable {
    case copy
    case copyPlainText = "copy_plain_text"
    case copyOriginalImage = "copy_original_image"
    case quickLook = "quick_look"
    case markupOpened = "markup_opened"
    case markupSaved = "markup_saved"
    case favoriteAdded = "favorite_added"
    case favoriteRemoved = "favorite_removed"
    case deleted
    case restored
    case renamed
    case exported
    case shared
}

public enum AnalyticsLibraryFilter: String, Codable, CaseIterable {
    case allClips = "all_clips"
    case images
    case text
    case favorites
    case deleted

    init(filter: LibraryFilter) {
        switch filter {
        case .allClips:
            self = .allClips
        case .images:
            self = .images
        case .text:
            self = .text
        case .favorites:
            self = .favorites
        case .deleted:
            self = .deleted
        }
    }
}

public enum AnalyticsSettingsSection: String, Codable, CaseIterable {
    case appearance
    case shortcut
    case storageLocation = "storage_location"
    case other
    case debug
}

public enum AnalyticsStorageProvider: String, Codable, CaseIterable {
    case applicationSupport = "application_support"
    case iCloudDrive = "icloud_drive"
    case dropbox
    case googleDrive = "google_drive"
    case custom

    init(preset: StorageLocationPreset.Identifier) {
        switch preset {
        case .applicationSupport:
            self = .applicationSupport
        case .iCloudDrive:
            self = .iCloudDrive
        case .dropbox:
            self = .dropbox
        case .googleDrive:
            self = .googleDrive
        case .custom:
            self = .custom
        }
    }
}
