# Project Brief: Photo & Video Converter

## Core Goal

Develop a macOS application that allows users to select photos and videos from their Photos Library, convert them to standard formats (JPG for images, MP4 for videos), and rename the output files based on the original media capture date and time.

## Key Requirements

1.  **Platform:** macOS Desktop Application.
2.  **Input:** User selects photos and videos of any format from the Photos Library via PhotosPicker interface.
3.  **Conversion:** 
    *   Convert selected images (HEIC, JPG, PNG, etc.) to JPG format
    *   Convert selected videos (MOV, MP4, etc.) to MP4 format
4.  **Renaming:** Name the output files using the format `YYYY-MM-DD_HH-MM-SS.jpg` (images) or `YYYY-MM-DD_HH-MM-SS.mp4` (videos), based on the date and time the original media was captured (from EXIF/metadata).
5.  **Metadata Preservation:** Preserve essential metadata during conversion, specifically including GPS location data, camera information, and other technical metadata.
6.  **Metadata Update:**
    *   Update the EXIF creation date/time tag (`DateTimeOriginal` or similar) in the output files to match the original capture date/time.
    *   Update the file system creation and modification dates of the output files to match the original capture date/time.
    *   Set title metadata to match the filename (without extension) for consistency.
7.  **User Interface:** Provide a simple graphical user interface (GUI) for media selection and initiating the conversion process. 