# Active Context

## Current Focus

*   **Debugging and Performance Enhancement:** Added comprehensive logging system to diagnose video conversion failures.
*   **Concurrency Management:** Fixed crash issues caused by excessive concurrent processing (141 videos at once).
*   **Production Stability:** Application now processes media in controlled batches to prevent system overload.
*   **Branch:** Working on `added-logger-2025-10-21` branch with logging and performance improvements.

## Recent Changes

*   **Comprehensive Logging System (2025-10-21):**
    *   Created new `Logger.swift` class for crash-resistant debugging.
    *   Implemented thread-safe logging with NSLock for concurrent operations.
    *   Log files saved to sandbox-compatible location: `~/Library/Containers/jerry.Photo-Converter/Data/Library/Application Support/Photo Converter/`.
    *   Immediate disk writes with `synchronize()` to capture data before crashes.
    *   Comprehensive logging throughout conversion process:
        *   Asset information (dimensions, GPS data, creation dates).
        *   Video resource details (original filename, UTI, resource type).
        *   Export session status and metadata counts.
        *   Detailed error messages with specific failure points.
    *   Logger initialized at app launch to capture all activity.
    *   Log file path displayed to user in completion status.
*   **Concurrency Limit Implementation (2025-10-21):**
    *   Discovered crash issue: app was processing 141 videos simultaneously causing "Cannot Save" errors.
    *   Implemented controlled concurrency with maximum 6 concurrent asset conversions.
    *   Queue-based processing: as each conversion completes, next asset begins.
    *   Prevents file system overload and memory exhaustion.
    *   Maintains responsive UI while processing large batches.
    *   Significantly improved stability for bulk operations.
*   **Git Branch Management (2025-10-21):**
    *   Created new branch `added-logger-2025-10-21` for logging and performance improvements.
    *   Committed changes: Logger.swift (new), ConversionService.swift (updated), Photo_ConverterApp.swift (updated).
    *   Pushed branch to GitHub: https://github.com/jtabeling/cursor_photo_converter_macos/tree/added-logger-2025-10-21

*   Created Xcode project (`Photo Converter`) using SwiftUI.
*   Configured `Info.plist` for Photos Library access.
*   Implemented basic SwiftUI `ContentView` with buttons, state management, progress view, and status list.
*   Integrated `PhotosUI` framework for selecting images via `PhotosPicker`.
*   Implemented output folder selection using `.fileImporter` with security scope handling.
*   Created `ConversionService` actor using Swift concurrency (`async/await`, `TaskGroup`).
*   Implemented core conversion logic within `ConversionService`:
    *   Photo Library authorization check (`PHPhotoLibrary`).
    *   Fetching assets (`PHAsset`).
    *   Requesting image data and properties (`PHImageManager`, `ImageIO`).
    *   Extracting creation date for filename and metadata.
    *   Converting HEIC to JPG (`CGImageSource`, `CGImageDestination`) with metadata preservation (including GPS) and EXIF date update.
    *   Saving JPG to user-selected output directory (overwriting duplicates).
    *   Updating file system creation/modification dates (`FileManager`).
*   Integrated `ConversionService` with `ContentView` for asynchronous processing with UI updates for progress and completion/errors.
*   Added `.onDisappear` cleanup for security-scoped resource access.
*   Implemented video conversion functionality:
    *   Added `processVideoAsset` method parallel to `processImageAsset`.
    *   Created two-tiered approach to video export: primary method using `PHAssetResourceManager` for direct export, with fallback to `AVAssetExportSession`.
    *   Enhanced metadata preservation for videos, ensuring title, creation date, and GPS coordinates are properly maintained.
    *   Implemented robust error handling with the `videoExportFailed` and `videoMetadataUpdateFailed` error types.
*   Enhanced metadata handling approach to preserve all original metadata while selectively updating specific fields:
    *   For videos: using `AVAsset.metadata` to get all existing metadata.
    *   Preserving camera type and other technical metadata while adding/updating title and location information.
    *   Using ISO 6709 format for GPS coordinates to ensure compatibility.
*   **Debugging & Resolution:** Addressed application launch crashes and build errors related to project configuration:
    *   Fixed linter error in `ConversionService` (`guard` fallthrough).
    *   Verified `NSPhotoLibraryUsageDescription` was present in `Photo Converter/Info.plist`.
    *   Added required `Photos Library` capability (Read/Write) in Target -> Signing & Capabilities, updating `.entitlements`.
    *   Corrected the `Info.plist File` path in Target -> Build Settings.
    *   Re-added missing `Info.plist` file reference to the Xcode project navigator.
    *   Added missing `CFBundleIdentifier` and other standard keys to `Info.plist` to resolve final launch crash.
    *   Fixed issues with video metadata preservation, ensuring GPS coordinates and camera type information are maintained.
*   **Image and Video Title Metadata:** Implemented setting the title metadata to match the file name (without extension):
    *   For images: Added IPTC ObjectName and TIFF ImageDescription metadata fields to match the filename format.
    *   For videos: Updated QuickTime metadata title to match the filename format.
    *   This ensures media title/name in file explorers and viewers matches the output filename pattern.
*   **GitHub Repository Setup:** Successfully configured version control and GitHub integration:
    *   Initialized local git repository with proper .gitignore for macOS/Xcode projects.
    *   Created comprehensive .gitignore excluding build files, user data, and memory bank documentation.
    *   Made initial commit with all project files and descriptive commit message.
    *   Connected to GitHub repository: https://github.com/jtabeling/cursor_photo_converter_macos
    *   Pushed code to GitHub with proper remote origin configuration.
*   **Unrestricted Media Selection:** Removed filename and file type restrictions:
    *   Updated PhotosPicker to accept both images and videos (`.any(of: [.images, .videos])`)
    *   Changed button text from "Select HEIC Images (img*.heic)" to "Select Photos & Videos"
    *   Removed filtering logic that restricted selection to only `img*.heic` files
    *   Users can now select any photos (HEIC, JPG, PNG, etc.) and videos (MOV, MP4, etc.) from their Photos Library
    *   Simplified selection process - all selected media is immediately accepted without filtering
*   **MP4 Video Output Format (2025-10-21):** Changed video conversion output format from MOV to MP4:
    *   Updated output filename extension from `.mov` to `.mp4`
    *   Changed `AVAssetExportSession.outputFileType` from `.mov` to `.mp4` in all export operations
    *   Updated temporary file naming to use `.mp4` extension
    *   All metadata preservation features remain intact (GPS, camera info, title matching)
    *   More widely compatible format for cross-platform sharing and playback

## Next Steps

1.  **Production Use:** Application ready for regular use with comprehensive logging and performance optimizations.
2.  **Monitoring:** Use log files to identify and address any edge cases or problematic video types that emerge during real-world use.
3.  **Analysis:** Review log files from any failed conversions to identify patterns (4K videos, specific codecs, etc.) and implement targeted fixes as needed.
4.  **Optional Enhancements:** Consider future improvements:
    *   Additional output format options (PNG, TIFF, etc.).
    *   Advanced metadata editing capabilities.
    *   Integration with cloud storage services.
    *   Command-line interface for automation.
    *   User documentation or help system.
5.  **Maintenance:** Regular updates to maintain compatibility with new macOS versions and frameworks.

## Active Decisions/Considerations

*   **UI Framework:** SwiftUI (Implemented).
*   **Image Conversion/Metadata:** `ImageIO` (Implemented).
*   **Video Conversion/Metadata:** Combination of `PHAssetResourceManager` for export and `AVFoundation` for metadata (Implemented).
*   **File Access:** `PhotosUI` (`PhotosPicker`) for input, `.fileImporter` for output directory (Implemented).
*   **Concurrency:** Swift concurrency (`async/await`, `TaskGroup`, `Actor`) with **controlled concurrency limit of 6** to prevent system overload (Implemented 2025-10-21).
*   **Logging Strategy:** Comprehensive logging system with immediate disk writes for crash debugging, sandbox-compatible storage location (Implemented 2025-10-21).
*   **Output Location:** User-selected output folder (Implemented).
*   **Duplicate Handling:** Overwrite (Implemented).
*   **Error Handling Strategy:** Skip problematic files, continue processing, report summary and individual errors, log detailed debugging information (Enhanced 2025-10-21).
*   **Security Scope Cleanup:** Implemented basic cleanup (`onDisappear`, explicit stop on new folder selection).
*   **Video Metadata Strategy:** Preserve all original metadata while selectively updating title and location (Implemented).
*   **Metadata Consistency:** Title metadata consistently set to match the filename (without extension) across both images and videos.
*   **Version Control:** Git repository configured with proper .gitignore and GitHub integration. All feature branches merged into main.
*   **Project Status:** Production ready. Core functionality complete with logging and performance improvements fully integrated. 