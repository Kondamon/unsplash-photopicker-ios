//
//  UnsplashPhotoPicker.swift
//  UnsplashPhotoPicker
//
//  Created by Bichon, Nicolas on 2018-10-09.
//  Copyright © 2018 Unsplash. All rights reserved.
//

import UIKit

/// A protocol describing an object that can be notified of events from UnsplashPhotoPicker.
public protocol UnsplashPhotoPickerDelegate: AnyObject {

    /**
     Notifies the delegate that UnsplashPhotoPicker has selected photos.

     - parameter photoPicker: The `UnsplashPhotoPicker` instance responsible for selecting the photos.
     - parameter photos:      The selected photos.
     */
    func unsplashPhotoPicker(_ photoPicker: UnsplashPhotoPicker, didSelectPhotos photos: [UnsplashPhoto])

    /**
     Notifies the delegate that UnsplashPhotoPicker has been canceled.

     - parameter photoPicker: The `UnsplashPhotoPicker` instance responsible for selecting the photos.
     */
    func unsplashPhotoPickerDidCancel(_ photoPicker: UnsplashPhotoPicker)
    
    /**
     Notifies the delegate that UnsplashPhotoPicker has scrolled

     - parameter scrollView: The view for scrolling.
     */
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    
    /**
     Notifies the delegate that UnsplashPhotoPicker is searching for a certain term
     - parameter term: The search term.
     
     */
    func didSearch(_ term: String)
}

/// `UnsplashPhotoPicker` is an object that can be used to select photos from Unsplash.
public class UnsplashPhotoPicker: UINavigationController {

    // MARK: - Properties

    private let photoPickerViewController: UnsplashPhotoPickerViewController

    /// A delegate that is notified of significant events.
    public weak var photoPickerDelegate: UnsplashPhotoPickerDelegate?

    // MARK: - Lifetime

    /**
     Initializes an `UnsplashPhotoPicker` object with a configuration.

     - parameter configuration: The configuration struct that specifies how UnsplashPhotoPicker should be configured.
     */
    public init(configuration: UnsplashPhotoPickerConfiguration) {
        Configuration.shared = configuration

        self.photoPickerViewController = UnsplashPhotoPickerViewController()

        super.init(nibName: nil, bundle: nil)

        photoPickerViewController.delegate = self
    }
    
    public func setSearchQuery(_ text: String) {
      //  photoPickerViewController.setSearchText(text)
    }
    
    public func showSearchBar(_ forceShowingSearch: Bool, hideNaviagationBarDuringSearching: Bool) {
        self.setNavigationBarHidden(true, animated: false)
        photoPickerViewController.showSearchBar(forceShowingSearch: forceShowingSearch,
                                                hideNaviagationBarDuringSearching: hideNaviagationBarDuringSearching)
        
    
//        self.navigationBar.setBackgroundImage(UIImage(), for: .default)
//        self.navigationBar.shadowImage = UIImage()
//        self.navigationBar.barStyle = UIBarStyle.default
//
//        self.navigationBar.backgroundColor = .clear
//
//        self.navigationBar.isTranslucent = true
    }
    
    public func setCollectionId(_ collectionId:String) {
        let dataSource = PhotosDataSourceFactory.collection(identifier: collectionId).dataSource
        photoPickerViewController.dataSource = dataSource
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [photoPickerViewController]
    }

    // MARK: - Download tracking

    private func trackDownloads(for photos: [UnsplashPhoto]) {
        for photo in photos {
            if let downloadLocationURL = photo.links[.downloadLocation]?.appending(queryItems: [URLQueryItem(name: "client_id", value: Configuration.shared.accessKey)]) {
                URLSession.shared.dataTask(with: downloadLocationURL).resume()
            }
        }
    }

}

// MARK: - UnsplashPhotoPickerViewControllerDelegate
extension UnsplashPhotoPicker: UnsplashPhotoPickerViewControllerDelegate {
    func unsplashPhotoPickerViewController(_ viewController: UnsplashPhotoPickerViewController, didSelectPhotos photos: [UnsplashPhoto]) {
        trackDownloads(for: photos)
        photoPickerDelegate?.unsplashPhotoPicker(self, didSelectPhotos: photos)
        guard Configuration.shared.automaticallyDismissesViewController else { return }
        dismiss(animated: true, completion: nil)
    }

    func unsplashPhotoPickerViewControllerDidCancel(_ viewController: UnsplashPhotoPickerViewController) {
        photoPickerDelegate?.unsplashPhotoPickerDidCancel(self)
        guard Configuration.shared.automaticallyDismissesViewController else { return }
        dismiss(animated: true, completion: nil)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        photoPickerDelegate?.scrollViewDidScroll(scrollView)
    }
    
    func didSearch(_ term: String) {
        photoPickerDelegate?.didSearch(term)
    }
}
