# Active Context

## Current Focus

*   Application is fully functional and running successfully with unrestricted media selection.
*   Project has been successfully configured with GitHub repository.
*   All core functionality implemented and tested.
*   Filename and file type restrictions have been removed - users can now select any photos and videos.
*   Ready for production use and potential feature enhancements.

## Recent Changes

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

## Next Steps

1.  **Production Use:** The application is ready for regular use. All core functionality has been implemented and tested.
2.  **Optional Enhancements:** Consider future improvements based on user feedback:
    *   Batch processing optimizations for very large photo collections.
    *   Additional output format options (PNG, TIFF, etc.).
    *   Advanced metadata editing capabilities.
    *   Integration with cloud storage services.
    *   Command-line interface for automation.
3.  **Maintenance:** Regular updates to maintain compatibility with new macOS versions and frameworks.
4.  **Documentation:** Consider adding user documentation or help system for end users.

## Active Decisions/Considerations

*   **UI Framework:** SwiftUI (Implemented).
*   **Image Conversion/Metadata:** `ImageIO` (Implemented).
*   **Video Conversion/Metadata:** Combination of `PHAssetResourceManager` for export and `AVFoundation` for metadata (Implemented).
*   **File Access:** `PhotosUI` (`PhotosPicker`) for input, `.fileImporter` for output directory (Implemented).
*   **Concurrency:** Swift concurrency (`async/await`, `TaskGroup`, `Actor`) (Implemented).
*   **Output Location:** User-selected output folder (Implemented).
*   **Duplicate Handling:** Overwrite (Implemented).
*   **Error Handling Strategy:** Skip problematic files, continue processing, report summary and individual errors (Implemented).
*   **Security Scope Cleanup:** Implemented basic cleanup (`onDisappear`, explicit stop on new folder selection). Further review during refinement might be needed for complex scenarios.
*   **Video Metadata Strategy:** Preserve all original metadata while selectively updating title and location (Implemented).
*   **Metadata Consistency:** Title metadata now consistently set to match the filename (without extension) across both images and videos.
*   **Version Control:** Git repository configured with proper .gitignore and GitHub integration for collaboration and backup.
*   **Project Status:** All core functionality implemented and tested. Application is production-ready. 