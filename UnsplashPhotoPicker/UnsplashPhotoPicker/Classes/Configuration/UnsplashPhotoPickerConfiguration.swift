//
//  UnsplashPhotoPickerConfiguration.swift
//  UnsplashPhotoPicker
//
//  Created by Bichon, Nicolas on 2018-10-09.
//  Copyright © 2018 Unsplash. All rights reserved.
//

import Foundation
import UIKit

/**
 Content Safety

 By default, endpoints set the `content_filter` to `low`, which guarantees that no content violating our
 submission guidelines (like images containing nudity or violence) will be returned in results.

 To give you flexibility in filtering content further, set the `content_filter` to `high` (on endpoints that
 support it) to further remove content that may be unsuitable for younger audiences. Note that we can’t
 guarantee that all potentially unsuitable content is removed.
 */
public enum ContentFilterLevel: String {
    case low
    case high
}

/// Encapsulates configuration information for the behavior of UnsplashPhotoPicker.
public struct UnsplashPhotoPickerConfiguration {

    /// Your application’s access key.
    public var accessKey = ""

    /// Your application’s secret key.
    public var secretKey = ""

    /// A search query. When set, hides the search bar and shows results instead of the editorial photos.
    public var query: String?

    /// Controls whether the picker allows multiple or single selection.
    public var allowsMultipleSelection = false
    
    /// Controls wheter the navigationController automatically dismisses after clicking on an image or done
    public var automaticallyDismissesViewController = true
    
    /// Color that is used for e.g. checkmark fills
    public var fillColor = UIColor.systemBlue

    /// The memory capacity used by the cache.
    public var memoryCapacity = defaultMemoryCapacity

    /// The disk capacity used by the cache.
    public var diskCapacity = defaultDiskCapacity

    /// Set the content safety filter.
    public var contentFilterLevel = defaultContentFilterLevel

    /// The default memory capacity used by the cache.
    public static let defaultMemoryCapacity: Int = ImageCache.memoryCapacity

    /// The default disk capacity used by the cache.
    public static let defaultDiskCapacity: Int = ImageCache.diskCapacity

    /// The default content safety filter.
    public static let defaultContentFilterLevel: ContentFilterLevel = .low

    /// The Unsplash API url.
    let apiURL = "https://api.unsplash.com/"

    /// The Unsplash editorial collection id.
    public var editorialCollectionId = "317099"

    /**
     Initializes an `UnsplashPhotoPickerConfiguration` object with optionally customizable behaviors.

     - parameter accessKey:               Your application’s access key.
     - parameter secretKey:               Your application’s secret key.
     - parameter query:                   A search query.
     - parameter collectionId:            Collection id to be displayed (default editorial collection id)
     - parameter allowsMultipleSelection: Controls whether the picker allows multiple or single selection.
     - parameter memoryCapacity:          The memory capacity used by the cache.
     - parameter diskCapacity:            The disk capacity used by the cache.
     */
    public init(accessKey: String,
                secretKey: String,
                query: String? = nil,
                collectionId: String = "317099",
                allowsMultipleSelection: Bool = false,
                memoryCapacity: Int = defaultMemoryCapacity,
                diskCapacity: Int = defaultDiskCapacity,
                contentFilterLevel: ContentFilterLevel = defaultContentFilterLevel
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.query = query
        self.editorialCollectionId = collectionId
        self.allowsMultipleSelection = allowsMultipleSelection
        self.memoryCapacity = memoryCapacity
        self.diskCapacity = diskCapacity
        self.contentFilterLevel = contentFilterLevel
    }

    init() {}

}
