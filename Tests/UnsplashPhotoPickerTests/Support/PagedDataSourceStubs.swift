//
//  PagedDataSourceStubs.swift
//  UnsplashPhotoPickerTests
//

import Foundation
import XCTest
@testable import UnsplashPhotoPicker

/// A paged request that never touches the network. It blocks until `release()`
/// is called and then finishes with `stubItems` — even when it was cancelled in
/// the meantime, like a real data task whose response already arrived.
final class GatedPagedRequest: UnsplashPagedRequest, @unchecked Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let stubItems: [UnsplashPhoto]

    init(cursor: Cursor, stubItems: [UnsplashPhoto]) {
        self.stubItems = stubItems
        super.init(with: cursor)
    }

    func release() {
        gate.signal()
    }

    override func main() {
        DispatchQueue.global().async {
            self.gate.wait()
            self.items = self.stubItems
            self.completeOperation()
        }
    }
}

/// Hands out `GatedPagedRequest`s and keeps them, so a test can release them.
final class GatedRequestFactory: PagedDataSourceFactory {
    private let stubItems: [UnsplashPhoto]
    private(set) var requests = [GatedPagedRequest]()

    init(stubItems: [UnsplashPhoto]) {
        self.stubItems = stubItems
    }

    func initialCursor() -> UnsplashPagedRequest.Cursor {
        return UnsplashPagedRequest.Cursor(page: 1, perPage: 10, parameters: nil)
    }

    func request(with cursor: UnsplashPagedRequest.Cursor) -> UnsplashPagedRequest {
        let request = GatedPagedRequest(cursor: cursor, stubItems: stubItems)
        requests.append(request)
        return request
    }
}

/// Records every delegate callback together with the state it was delivered in.
final class PagedDataSourceDelegateSpy: PagedDataSourceDelegate {
    struct FetchCallback {
        let fetchedCount: Int
        let itemCountAtCallback: Int
        let isMainThread: Bool
    }

    private(set) var fetchCallbacks = [FetchCallback]()
    var onFetch: (() -> Void)?

    func dataSourceWillStartFetching(_ dataSource: PagedDataSource) {}

    func dataSource(_ dataSource: PagedDataSource, didFetch items: [UnsplashPhoto]) {
        let callback = FetchCallback(
            fetchedCount: items.count,
            itemCountAtCallback: dataSource.items.count,
            isMainThread: Thread.isMainThread)
        fetchCallbacks.append(callback)
        onFetch?()
    }

    func dataSource(_ dataSource: PagedDataSource, fetchDidFailWithError error: Error) {}
}

enum PhotoFixtures {
    static func photos(count: Int) -> [UnsplashPhoto] {
        return (0..<count).map { index in photo(identifier: "photo-\(index)") }
    }

    static func photo(identifier: String) -> UnsplashPhoto {
        let json = """
            {
              "id": "\(identifier)", "width": 100, "height": 150, "likes": 0,
              "urls": { "thumb": "https://example.com/t.jpg", "small": "https://example.com/s.jpg" },
              "links": { "html": "https://example.com/p" },
              "user": {
                "id": "user", "username": "user",
                "profile_image": { "small": "https://example.com/u.jpg" },
                "links": { "html": "https://example.com/u" },
                "total_collections": 0, "total_likes": 0, "total_photos": 0
              }
            }
            """
        // Force-try: a broken fixture must fail loudly, not silently skip a test.
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(UnsplashPhoto.self, from: Data(json.utf8))
    }
}
