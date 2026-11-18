//
//  PagedDataSourceTests.swift
//  UnsplashPhotoPickerTests
//
//  Regression for the crash
//  "attempt to insert item 0 into section 0, but there are only 0 items in
//  section 0 after the update". A new search replaces the picker's data source
//  and cancels the old one, but the old request's response still arrived,
//  was appended to the old source and reported to the picker, which inserted
//  rows the new (empty) source did not have.
//

import XCTest
@testable import UnsplashPhotoPicker

final class PagedDataSourceTests: XCTestCase {

    func test_fetchNextPage_whenCancelledBeforeResponse_dropsStaleItems() {
        let factory = GatedRequestFactory(stubItems: PhotoFixtures.photos(count: 3))
        let dataSource = PagedDataSource(with: factory)
        let spy = PagedDataSourceDelegateSpy()
        dataSource.delegate = spy
        let staleCallback = expectation(description: "stale page reported")
        staleCallback.isInverted = true
        spy.onFetch = { staleCallback.fulfill() }

        dataSource.fetchNextPage()
        dataSource.cancelFetch()
        factory.requests.first?.release()

        wait(for: [staleCallback], timeout: 0.5)
        XCTAssertTrue(dataSource.items.isEmpty, "a cancelled page must not be appended")
        XCTAssertTrue(spy.fetchCallbacks.isEmpty, "a cancelled page must not reach the delegate")
    }

    func test_fetchNextPage_whenResetBeforeResponse_dropsStaleItems() {
        let factory = GatedRequestFactory(stubItems: PhotoFixtures.photos(count: 3))
        let dataSource = PagedDataSource(with: factory)
        let spy = PagedDataSourceDelegateSpy()
        dataSource.delegate = spy
        let staleCallback = expectation(description: "stale page reported")
        staleCallback.isInverted = true
        spy.onFetch = { staleCallback.fulfill() }

        dataSource.fetchNextPage()
        dataSource.reset()
        factory.requests.first?.release()

        wait(for: [staleCallback], timeout: 0.5)
        XCTAssertTrue(dataSource.items.isEmpty, "a page from before reset must not be appended")
        XCTAssertFalse(dataSource.isFetching)
    }

    func test_fetchNextPage_whenResponseArrives_reportsItemsOnMainThread() {
        let factory = GatedRequestFactory(stubItems: PhotoFixtures.photos(count: 3))
        let dataSource = PagedDataSource(with: factory)
        let spy = PagedDataSourceDelegateSpy()
        dataSource.delegate = spy
        let pageReported = expectation(description: "page reported")
        spy.onFetch = { pageReported.fulfill() }

        dataSource.fetchNextPage()
        factory.requests.first?.release()

        wait(for: [pageReported], timeout: 2.0)
        let callback = spy.fetchCallbacks.first
        XCTAssertEqual(callback?.fetchedCount, 3)
        XCTAssertEqual(callback?.itemCountAtCallback, 3)
        XCTAssertEqual(callback?.isMainThread, true, "items must change on the thread UICollectionView reads them on")
    }
}
