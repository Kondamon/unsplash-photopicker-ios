//
//  UnsplashPhotoPickerViewController.swift
//  UnsplashPhotoPicker
//
//  Created by Bichon, Nicolas on 2018-10-09.
//  Copyright © 2018 Unsplash. All rights reserved.
//

import UIKit

protocol UnsplashPhotoPickerViewControllerDelegate: AnyObject {
    func unsplashPhotoPickerViewController(_ viewController: UnsplashPhotoPickerViewController, didSelectPhotos photos: [UnsplashPhoto])
    func unsplashPhotoPickerViewControllerDidCancel(_ viewController: UnsplashPhotoPickerViewController)
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func didSearch(_ term: String)
}

class UnsplashPhotoPickerViewController: UIViewController {
    
    static let inset: CGFloat = 13.0
    
    /// Search bar not on navigationbar, but directly added in view
    private var hasManuallyAddedSearchBar = false
    
    /// To adjust top inset to prevent clash with manually added search bar
    private var collectionViewTopLayoutConstraint: NSLayoutConstraint?

    // MARK: - Properties

    private lazy var cancelBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelBarButtonTapped(sender:))
        )
    }()

    private lazy var doneBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneBarButtonTapped(sender:))
        )
    }()

    private lazy var searchController: UISearchController = {
        let searchController = UnsplashSearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "search.placeholder".localized()
        searchController.searchBar.autocapitalizationType = .none
        // white search bar background
        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.backgroundImage = UIImage()
        searchController.searchBar.isTranslucent = false
        if #available(iOS 13.0, *) {
            searchController.searchBar.barTintColor = .systemBackground
        }
       
        return searchController
    }()

    private lazy var layout = WaterfallLayout(with: self)

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        collectionView.register(PagingView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: PagingView.reuseIdentifier)
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.layoutMargins = UIEdgeInsets(top: 0.0, left: UnsplashPhotoPickerViewController.inset,
                                                    bottom: 0.0, right: UnsplashPhotoPickerViewController.inset)
        collectionView.backgroundColor = UIColor.photoPicker.background
        collectionView.allowsMultipleSelection = Configuration.shared.allowsMultipleSelection
        return collectionView
    }()

    private let spinner: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.hidesWhenStopped = true
            return spinner
        } else {
            let spinner = UIActivityIndicatorView(style: .gray)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.hidesWhenStopped = true
            return spinner
        }
    }()

    private lazy var emptyView: EmptyView = {
        let view = EmptyView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var dataSource: PagedDataSource {
        didSet {
            oldValue.cancelFetch()
            dataSource.delegate = self
            refresh()
        }
    }

    var numberOfSelectedPhotos: Int {
        return collectionView.indexPathsForSelectedItems?.count ?? 0
    }

    private let editorialDataSource = PhotosDataSourceFactory.collection(identifier: Configuration.shared.editorialCollectionId).dataSource

    private var previewingContext: UIViewControllerPreviewing?
    private var searchText: String?

    weak var delegate: UnsplashPhotoPickerViewControllerDelegate?

    // MARK: - Lifetime

    init() {
        self.dataSource = editorialDataSource

        super.init(nibName: nil, bundle: nil)

        dataSource.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.photoPicker.background
        setupNotifications()
        setupNavigationBar()
        setupSearchController()
        setupCollectionView()
        setupSpinner()

        let trimmedQuery = Configuration.shared.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        setSearchText(trimmedQuery)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if dataSource.items.count == 0 {
            refresh()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Fix to avoid a retain issue
        searchController.dismiss(animated: true, completion: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (_) in
            self.layout.invalidateLayout()
        })
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowNotification(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHideNotification(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func setupNavigationBar() {
        updateTitle()
        navigationItem.leftBarButtonItem = cancelBarButtonItem

        if Configuration.shared.allowsMultipleSelection {
            doneBarButtonItem.isEnabled = false
            navigationItem.rightBarButtonItem = doneBarButtonItem
        }
    }

    private func setupSearchController() {
        let trimmedQuery = Configuration.shared.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query = trimmedQuery, query.isEmpty == false { return }

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        extendedLayoutIncludesOpaqueBars = true
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            collectionView.leftAnchor.constraint(equalTo: view.leftAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        collectionViewTopLayoutConstraint = collectionView.topAnchor.constraint(equalTo: safe.topAnchor)
        collectionViewTopLayoutConstraint?.isActive = true
    }

    private func setupSpinner() {
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }

    private func showEmptyView(with state: EmptyViewState) {
        emptyView.state = state

        guard emptyView.superview == nil else { return }

        spinner.stopAnimating()

        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            emptyView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyView.leftAnchor.constraint(equalTo: view.leftAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }

    private func hideEmptyView() {
        emptyView.removeFromSuperview()
    }

    func updateTitle() {
        title = String.localizedStringWithFormat("title".localized(), numberOfSelectedPhotos)
    }

    func updateDoneButtonState() {
        doneBarButtonItem.isEnabled = numberOfSelectedPhotos > 0
    }

    // MARK: - Actions

    @objc private func cancelBarButtonTapped(sender: AnyObject?) {
        searchController.searchBar.resignFirstResponder()

        delegate?.unsplashPhotoPickerViewControllerDidCancel(self)
    }

    @objc private func doneBarButtonTapped(sender: AnyObject?) {
        searchController.searchBar.resignFirstResponder()

        let selectedPhotos = collectionView.indexPathsForSelectedItems?.reduce([], { (photos, indexPath) -> [UnsplashPhoto] in
            var mutablePhotos = photos
            if let photo = dataSource.item(at: indexPath.item) {
                mutablePhotos.append(photo)
            }
            return mutablePhotos
        })

        delegate?.unsplashPhotoPickerViewController(self, didSelectPhotos: selectedPhotos ?? [UnsplashPhoto]())
    }

    private func scrollToTop() {
        let contentOffset = CGPoint(x: 0, y: -collectionView.safeAreaInsets.top)
        collectionView.setContentOffset(contentOffset, animated: false)
    }

    // MARK: - Data

    private func setSearchText(_ text: String?) {
        if let text = text, text.isEmpty == false {
            dataSource = PhotosDataSourceFactory.search(query: text).dataSource
            searchText = text
        } else {
            dataSource = editorialDataSource
            searchText = nil
        }
    }
    
    func showSearchBar(forceShowingSearch: Bool, hideNaviagationBarDuringSearching: Bool) {
        guard !hasManuallyAddedSearchBar else {
            searchController.searchBar.becomeFirstResponder()
            return
        }
        
        navigationItem.searchController = nil
        let searchBar = searchController.searchBar
        let directionalMargins = NSDirectionalEdgeInsets(top: 0, leading: UnsplashPhotoPickerViewController.inset,
                                                         bottom: 0, trailing: UnsplashPhotoPickerViewController.inset)
        searchController.searchBar.directionalLayoutMargins = directionalMargins
        view.addSubview(searchBar)
    
       // searchController.isActive = true
        if forceShowingSearch {
            searchController.searchBar.becomeFirstResponder()
        } else {
            searchController.searchBar.resignFirstResponder()
        }
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.collectionViewTopLayoutConstraint?.constant = searchBar.frame.size.height - 10
        })
        
        hasManuallyAddedSearchBar = true
    }

    @objc func refresh() {
        guard dataSource.items.isEmpty else { return }

        if dataSource.isFetching == false && dataSource.items.count == 0 {
            dataSource.reset()
            reloadData()
            fetchNextItems()
        }
    }

    func reloadData() {
        collectionView.reloadData()
    }

    func fetchNextItems() {
        dataSource.fetchNextPage()
    }

    private func fetchNextItemsIfNeeded() {
        if dataSource.items.count == 0 {
            fetchNextItems()
        }
    }

    // MARK: - Notifications

    @objc func keyboardWillShowNotification(_ notification: Notification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.size,
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
                return
        }

        let bottomInset = keyboardSize.height - view.safeAreaInsets.bottom
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0)

        UIView.animate(withDuration: duration) { [weak self] in
            self?.collectionView.contentInset = contentInsets
            self?.collectionView.scrollIndicatorInsets = contentInsets
        }
    }

    @objc func keyboardWillHideNotification(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        UIView.animate(withDuration: duration) { [weak self] in
            self?.collectionView.contentInset = .zero
            self?.collectionView.scrollIndicatorInsets = .zero
        }
    }
}

// MARK: - UISearchBarDelegate
extension UnsplashPhotoPickerViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text else { return }

        setSearchText(text)
        refresh()
        scrollToTop()
        hideEmptyView()
        updateTitle()
        updateDoneButtonState()
        delegate?.didSearch(text)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard self.searchText != nil && searchText.isEmpty else { return }

        setSearchText(nil)
        refresh()
        reloadData()
        scrollToTop()
        hideEmptyView()
        updateTitle()
        updateDoneButtonState()
    }
}

// MARK: - UIScrollViewDelegate
extension UnsplashPhotoPickerViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if searchController.searchBar.isFirstResponder {
            searchController.searchBar.resignFirstResponder()
        }
        delegate?.scrollViewDidScroll(scrollView)
    }
}

// MARK: - PagedDataSourceDelegate
extension UnsplashPhotoPickerViewController: PagedDataSourceDelegate {
    func dataSourceWillStartFetching(_ dataSource: PagedDataSource) {
        if dataSource.items.count == 0 {
            spinner.startAnimating()
        }
    }

    func dataSource(_ dataSource: PagedDataSource, didFetch items: [UnsplashPhoto]) {
        guard items.count > 0 else { return }
        guard dataSource.items.count > 0 else {
            DispatchQueue.main.async {
                self.spinner.stopAnimating()
                self.showEmptyView(with: .noResults)
            }

            return
        }

        let newPhotosCount = items.count
        let startIndex = self.dataSource.items.count - newPhotosCount
        let endIndex = startIndex + newPhotosCount
        var newIndexPaths = [IndexPath]()
        // crash fix, https://gist.github.com/radianttap/c06445d8cd24ed636a4f12fe5370a0c5
        for index in startIndex..<endIndex where ((index < NSNotFound - 1_000) && index >= 0) {
            newIndexPaths.append(IndexPath(item: index, section: 0))
        }

        guard newIndexPaths.count > 0 else { return }
        
        DispatchQueue.main.async { [unowned self] in
            self.spinner.stopAnimating()
            self.hideEmptyView()

            let hasWindow = self.collectionView.window != nil
            let collectionViewItemCount = self.collectionView.numberOfItems(inSection: 0)
            if hasWindow && collectionViewItemCount < dataSource.items.count {
                self.collectionView.insertItems(at: newIndexPaths)
            } else {
                self.reloadData()
            }
        }
    }

    func dataSource(_ dataSource: PagedDataSource, fetchDidFailWithError error: Error) {
        let state: EmptyViewState = (error as NSError).isNoInternetConnectionError() ? .noInternetConnection : .serverError

        DispatchQueue.main.async {
            self.showEmptyView(with: state)
        }
    }
}
