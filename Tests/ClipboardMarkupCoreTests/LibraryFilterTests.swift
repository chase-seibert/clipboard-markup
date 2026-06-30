@testable import ClipboardMarkupCore
import XCTest

final class LibraryFilterTests: XCTestCase {
    func testImagesFilterMatchesOnlyImages() {
        XCTAssertTrue(LibraryFilter.images.matches(imageItem))
        XCTAssertFalse(LibraryFilter.images.matches(textItem))
    }

    func testTextFilterMatchesOnlyText() {
        XCTAssertTrue(LibraryFilter.text.matches(textItem))
        XCTAssertFalse(LibraryFilter.text.matches(imageItem))
    }

    func testAllClipsFilterMatchesBothKinds() {
        XCTAssertTrue(LibraryFilter.allClips.matches(textItem))
        XCTAssertTrue(LibraryFilter.allClips.matches(imageItem))
    }

    func testFavoritesFilterMatchesSavedItems() {
        XCTAssertTrue(LibraryFilter.favorites.matches(favoriteItem))
        XCTAssertFalse(LibraryFilter.favorites.matches(textItem))
    }

    private var textItem: ClipboardItem {
        ClipboardItem(
            kind: .text,
            plainText: "Copied text",
            fingerprint: "text:test"
        )
    }

    private var imageItem: ClipboardItem {
        ClipboardItem(
            kind: .image,
            imageWidth: 300,
            imageHeight: 440,
            fingerprint: "image:test"
        )
    }

    private var favoriteItem: ClipboardItem {
        ClipboardItem(
            kind: .text,
            plainText: "Saved text",
            isSaved: true,
            fingerprint: "text:favorite"
        )
    }
}
