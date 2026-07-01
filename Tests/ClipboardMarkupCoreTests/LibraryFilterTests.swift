@testable import ClipboardMarkupCore
import XCTest

final class LibraryFilterTests: XCTestCase {
    func testImagesFilterMatchesOnlyImages() {
        XCTAssertTrue(LibraryFilter.images.matches(imageItem))
        XCTAssertFalse(LibraryFilter.images.matches(textItem))
        XCTAssertFalse(LibraryFilter.images.matches(deletedImageItem))
    }

    func testTextFilterMatchesOnlyText() {
        XCTAssertTrue(LibraryFilter.text.matches(textItem))
        XCTAssertFalse(LibraryFilter.text.matches(imageItem))
        XCTAssertFalse(LibraryFilter.text.matches(deletedTextItem))
    }

    func testAllClipsFilterMatchesBothKinds() {
        XCTAssertTrue(LibraryFilter.allClips.matches(textItem))
        XCTAssertTrue(LibraryFilter.allClips.matches(imageItem))
        XCTAssertFalse(LibraryFilter.allClips.matches(deletedTextItem))
    }

    func testFavoritesFilterMatchesSavedItems() {
        XCTAssertTrue(LibraryFilter.favorites.matches(favoriteItem))
        XCTAssertFalse(LibraryFilter.favorites.matches(textItem))
        XCTAssertFalse(LibraryFilter.favorites.matches(deletedFavoriteItem))
    }

    func testDeletedFilterMatchesOnlyDeletedItems() {
        XCTAssertTrue(LibraryFilter.deleted.matches(deletedTextItem))
        XCTAssertTrue(LibraryFilter.deleted.matches(deletedImageItem))
        XCTAssertFalse(LibraryFilter.deleted.matches(textItem))
        XCTAssertFalse(LibraryFilter.deleted.matches(imageItem))
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

    private var deletedTextItem: ClipboardItem {
        ClipboardItem(
            deletedAt: Date(),
            kind: .text,
            plainText: "Deleted text",
            fingerprint: "text:deleted"
        )
    }

    private var deletedImageItem: ClipboardItem {
        ClipboardItem(
            deletedAt: Date(),
            kind: .image,
            imageWidth: 300,
            imageHeight: 440,
            fingerprint: "image:deleted"
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

    private var deletedFavoriteItem: ClipboardItem {
        ClipboardItem(
            deletedAt: Date(),
            kind: .text,
            plainText: "Deleted saved text",
            isSaved: true,
            fingerprint: "text:deleted-favorite"
        )
    }
}
