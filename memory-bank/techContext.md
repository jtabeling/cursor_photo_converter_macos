# Technical Context

## Target Platform

*   macOS (Specific minimum version TBD, likely latest or one version prior)

## Primary Language

*   Swift (Latest stable version recommended)

## Key Frameworks/APIs (Implemented)

*   **UI:** SwiftUI
*   **Image Handling:** 
    *   `ImageIO` for HEIC to JPG conversion and metadata preservation
    *   `CoreGraphics` for image processing operations (`CGImageSource`, `CGImageDestination`)
*   **Video Handling:**
    *   `AVFoundation` for video processing and metadata manipulation (`AVAsset`, `AVAssetExportSession`)
    *   `Photos` framework for accessing and exporting media (`PHAssetResourceManager`)
*   **Media Access:**
    *   `PhotosUI` for Photos Library access and selection via `PhotosPicker`
    *   `PhotosKit` (`Photos` framework) for fetching and working with media assets (`PHAsset`, `PHImageManager`)
*   **Foundation:** For file system operations (`FileManager`, `URL`), date/time formatting (`DateFormatter`), basic data types, thread synchronization (`NSLock`).
*   **Concurrency:** Swift Concurrency (`async`/`await`, `Task`, `TaskGroup`, `Actor`) with controlled parallelism.
*   **Logging (2025-10-21):** Custom `Logger` class using `FileHandle` for immediate writes and `NSLock` for thread safety.

## Development Setup

*   **IDE:** Xcode
*   **Build System:** Standard Xcode build system.
*   **Dependency Management:** None currently needed (using native frameworks).
*   **Version Control:** Git with GitHub integration
    *   Repository: https://github.com/jtabeling/cursor_photo_converter_macos
    *   Comprehensive .gitignore configured for macOS/Xcode projects
    *   Remote origin properly configured for collaboration and backup

## Technical Constraints/Considerations

*   Requires macOS APIs for file access, image/video conversion, and metadata manipulation.
*   Performance: Conversion can be resource-intensive. Need efficient implementation, especially for batch processing. Using Swift Concurrency with controlled parallelism (max 6 concurrent operations).
*   Concurrency Management (2025-10-21): 
    *   Unlimited concurrent processing causes "Cannot Save" file system errors
    *   Large batches (100+ videos) overwhelm system resources
    *   Solution: Queue-based processing with maximum 6 concurrent conversions
*   Error Handling: Robust handling for file I/O errors, invalid formats, missing metadata, permissions issues.
*   Debugging Strategy (2025-10-21):
    *   Comprehensive logging system for crash diagnosis
    *   Thread-safe logging compatible with Swift actors
    *   Sandbox constraints require Application Support directory for log storage
    *   Immediate disk writes necessary to capture pre-crash state
*   Metadata Standards: 
    *   EXIF for images (e.g., `kCGImagePropertyExifDateTimeOriginal`, `kCGImagePropertyGPSDictionary`)
    *   IPTC for image titles (e.g., `kCGImagePropertyIPTCObjectName`)
    *   TIFF for image descriptions (e.g., `kCGImagePropertyTIFFImageDescription`)
    *   QuickTime metadata for videos (e.g., `AVMetadataIdentifier.quickTimeMetadataTitle`, `AVMetadataIdentifier.quickTimeMetadataLocationISO6709`)
    *   File system attributes for both (creation/modification dates)
*   Title Metadata Approach:
    *   Images: Using both IPTC ObjectName and TIFF ImageDescription for maximum compatibility
    *   Videos: Using QuickTime metadata title
    *   All titles set to match the filename format (without extension): `YYYY-MM-DD_HH-MM-SS`
*   Video Processing Strategy: Two-tiered approach with primary method using direct resource export for better metadata preservation, and fallback using export session.

## Dependencies

*   No external dependencies. Relies entirely on built-in macOS frameworks. 