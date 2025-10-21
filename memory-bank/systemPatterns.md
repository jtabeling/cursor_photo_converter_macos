# System Patterns

## Architecture (Implemented)

*   **UI Layer:** Built with SwiftUI, handles user interaction for unrestricted media selection (photos and videos via PhotosPicker), output directory selection, and progress display.
*   **Core Logic Layer:** Implemented as `ConversionService` actor:
    *   Orchestrates the entire conversion process
    *   Provides **controlled concurrency** using Swift concurrency model (async/await, TaskGroup) with maximum 6 concurrent conversions
    *   Handles error reporting and progress updates
    *   Integrates comprehensive logging throughout conversion pipeline
*   **Logging Layer:** Implemented as `Logger` singleton class:
    *   Thread-safe logging with NSLock for concurrent access
    *   Immediate disk writes with synchronize() for crash resistance
    *   Stores logs in sandbox-safe Application Support directory
    *   Captures detailed asset information, metadata, and errors
    *   Initialized at app launch to log entire application lifecycle
*   **Image Processing:**
    *   Uses `ImageIO` framework for HEIC to JPG conversion with metadata preservation
    *   Handles image metadata extraction and updates using CGImageSource/CGImageDestination
*   **Video Processing:**
    *   Primary method: Uses `PHAssetResourceManager` for direct export to preserve metadata
    *   Fallback method: Uses `AVAssetExportSession` with metadata handling via `AVMetadataItem`
*   **Metadata Handling:**
    *   **Images:**
        *   Preserves original metadata including GPS coordinates
        *   Updates EXIF DateTimeOriginal to match original capture date
        *   Sets IPTC ObjectName and TIFF ImageDescription to match the filename (without extension)
    *   **Videos:**
        *   Preserves original metadata including camera information
        *   Updates or adds QuickTime title metadata to match the filename (without extension)
        *   Adds GPS metadata in ISO 6709 format when available
    *   **File System:**
        *   Updates creation and modification dates on exported files to match original capture date

## Key Technical Decisions (Implemented)

*   **UI Framework:** SwiftUI - provides clean implementation of file selection, progress reporting, and status updates.
*   **Image Conversion/Metadata Handling:** `ImageIO` framework handles both image conversion and metadata management, providing a complete solution.
*   **Video Conversion/Metadata Handling:** Hybrid approach using `PHAssetResourceManager` for export and `AVFoundation` for metadata handling.
*   **File Access:** `PhotosUI` (`PhotosPicker`) for input selection, `.fileImporter` for output directory selection.
*   **Concurrency:** Swift concurrency (`async/await`, `TaskGroup`, `Actor`) for responsive UI with **controlled parallelism:**
    *   Maximum 6 concurrent asset conversions to prevent system overload
    *   Queue-based processing where new tasks start as previous ones complete
    *   Prevents "Cannot Save" file system errors from excessive concurrent writes
*   **Logging Strategy (2025-10-21):**
    *   Synchronous logging with thread safety (NSLock) instead of async dispatch queues
    *   Immediate disk synchronization after each write for crash resistance
    *   Sandbox-compatible storage in Application Support directory
    *   Singleton pattern for global access from actor and non-actor contexts
*   **Metadata Strategy:** Preserve all existing metadata while selectively updating/adding specific fields (dates, titles, GPS) for consistency.

## Component Relationships (Implemented)

```mermaid
flowchart TD
    UI[ContentView (SwiftUI)] --> Core[ConversionService (Actor)]
    
    Core --> ImgProc[Image Processing]
    Core --> VidProc[Video Processing]
    Core --> Meta[Metadata Handling]
    Core --> FS[File System Operations]
    Core --> Log[Logger (Singleton)]
    
    ImgProc --> Meta
    ImgProc --> Log
    VidProc --> Meta
    VidProc --> Log
    Meta --> FS
    
    PhotosUI[PhotosUI] --> UI
    ImgIO[ImageIO] --> ImgProc
    ImgIO --> Meta
    AVF[AVFoundation] --> VidProc
    AVF --> Meta
    PHAsset[Photos Framework] --> Core
    
    Log --> LogFile[Application Support/Log Files]
    UI --> Log
``` 