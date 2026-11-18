//
//  PagedDataSource.swift
//  Unsplash
//
//  Created by Olivier Collet on 2017-10-10.
//  Copyright © 2017 Unsplash. All rights reserved.
//

import UIKit

protocol PagedDataSourceFactory {
    func initialCursor() -> UnsplashPagedRequest.Cursor
    func request(with cursor: UnsplashPagedRequest.Cursor) -> UnsplashPagedRequest
}

protocol PagedDataSourceDelegate: AnyObject {
    func dataSourceWillStartFetching(_ dataSource: PagedDataSource)
    func dataSource(_ dataSource: PagedDataSource, didFetch items: [UnsplashPhoto])
    func dataSource(_ dataSource: PagedDataSource, fetchDidFailWithError error: Error)
}

class PagedDataSource {

    enum DataSourceError: Error {
        case dataSourceIsFetching
        case wrongItemsType(Any)

        var localizedDescription: String {
            switch self {
            case .dataSourceIsFetching:
                return "The data source is already fetching."
            case .wrongItemsType(let returnedItems):
                return "The request return the wrong item type. Expecting \([UnsplashPhoto].self), got \(returnedItems.self)."
            }
        }
    }

    private(set) var items = [UnsplashPhoto]()
    private(set) var error: Error?
    private let factory: PagedDataSourceFactory
    private var cursor: UnsplashPagedRequest.Cursor
    private(set) var isFetching = false
    private var canFetchMore = true
    /// The only request whose page may still be applied. `reset()` and `cancelFetch()` clear it,
    /// so a response that arrives after a new search can no longer reach the collection view.
    private var activeRequest: UnsplashPagedRequest?
    private lazy var operationQueue = OperationQueue(with: "com.unsplash.pagedDataSource")

    weak var delegate: PagedDataSourceDelegate?

    init(with factory: PagedDataSourceFactory) {
        self.factory = factory
        self.cursor = factory.initialCursor()
    }

    func reset() {
        operationQueue.cancelAllOperations()
        activeRequest = nil
        items.removeAll()
        isFetching = false
        canFetchMore = true
        cursor = factory.initialCursor()
        error = nil
    }

    func fetchNextPage() {
        if isFetching {
            fetchDidComplete(withItems: nil, error: DataSourceError.dataSourceIsFetching)
            return
        }

        if canFetchMore == false {
            fetchDidComplete(withItems: [], error: nil)
            return
        }

        delegate?.dataSourceWillStartFetching(self)

        isFetching = true

        let request = factory.request(with: cursor)
        activeRequest = request
        // Apply the page on the main thread, the thread UICollectionView reads `items` on.
        request.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.requestDidFinish(request)
            }
        }

        operationQueue.addOperationWithDependencies(request)
    }

    func cancelFetch() {
        operationQueue.cancelAllOperations()
        activeRequest = nil
        isFetching = false
    }

    func item(at index: Int) -> UnsplashPhoto? {
        guard index < items.count else {
            return nil
        }

        return items[index]
    }

    // MARK: - Private

    private func requestDidFinish(_ request: UnsplashPagedRequest) {
        // Cancelled by a new search or reset: this page belongs to nothing on screen.
        guard request === activeRequest else { return }
        activeRequest = nil
        isFetching = false

        if let error = request.error {
            fetchDidComplete(withItems: nil, error: error)
            return
        }

        guard let items = request.items as? [UnsplashPhoto] else {
            fetchDidComplete(withItems: nil, error: DataSourceError.wrongItemsType(request.items))
            return
        }

        if items.count < cursor.perPage {
            canFetchMore = false
        } else {
            cursor = request.nextCursor()
        }

        self.items.append(contentsOf: items)
        fetchDidComplete(withItems: items, error: nil)
    }

    private func fetchDidComplete(withItems items: [UnsplashPhoto]?, error: Error?) {
        self.error = error

        if let error = error {
            delegate?.dataSource(self, fetchDidFailWithError: error)
        } else {
            let items = items ?? []
            delegate?.dataSource(self, didFetch: items)
        }
    }

}
