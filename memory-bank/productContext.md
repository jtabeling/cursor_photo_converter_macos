# Product Context

## Problem Solved

Modern iPhones and other devices often capture photos in the HEIC (High Efficiency Image Container) format. While efficient, HEIC is not universally supported across all platforms, applications, and web services. Users often need to convert these images to the more widely compatible JPG format for sharing, editing, or archiving purposes.

Existing conversion tools might strip important metadata (like GPS location or the original capture date) or fail to update file timestamps correctly, leading to disorganized photo collections and loss of information.

## How It Should Work (User Experience)

1.  The user launches the application.
2.  The user is presented with a simple interface with buttons to select photos/videos and an output folder.
3.  The user clicks "Select Media" which opens a PhotosPicker interface to access the Photos Library.
4.  The user selects one or more media files (HEIC images or videos).
5.  The user selects an output folder using the "Choose Output Folder" button.
6.  The user initiates conversion by clicking "Start Conversion".
7.  For each image file:
    *   Extracts the original capture date/time from the EXIF metadata.
    *   Extracts other relevant metadata (especially GPS).
    *   Converts the HEIC image data to JPG format.
    *   Constructs the new filename: `YYYY-MM-DD_HH-MM-SS.jpg`.
    *   Sets the image title metadata to match the filename (without extension).
    *   Saves the JPG image with the new filename.
    *   Injects the preserved metadata (GPS, etc.) into the new JPG file.
    *   Updates the relevant EXIF date/time tag in the JPG to match the original capture time.
    *   Updates the file system creation and modification dates of the new JPG file to match the original capture time.
8.  For each video file:
    *   Extracts the original capture date/time.
    *   Constructs the new filename: `YYYY-MM-DD_HH-MM-SS.mov`.
    *   Exports the video to the MOV format.
    *   Sets the video title metadata to match the filename (without extension).
    *   Preserves original metadata including GPS coordinates and camera information.
    *   Updates the file system creation and modification dates to match the original capture time.
9.  The application provides real-time progress feedback during conversion (progress bar and status messages).
10. Upon completion, the application displays a summary of successes and any errors encountered.
11. The converted files are saved in the user-selected output folder. 