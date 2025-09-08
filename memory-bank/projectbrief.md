# Project Brief: HEIC to JPG Converter

## Core Goal

Develop a macOS application that allows users to select HEIC image files, convert them to JPG format, and rename the output files based on the original image capture date and time.

## Key Requirements

1.  **Platform:** macOS Desktop Application.
2.  **Input:** User selects one or more HEIC (.heic) image files via a standard file open dialog or potentially the Photo Library.
3.  **Conversion:** Convert selected HEIC images to JPG (.jpg) format.
4.  **Renaming:** Name the output JPG files using the format `YYYY-MM-DD_HH-MM-SS.jpg`, based on the date and time the original photo was taken (from EXIF data).
5.  **Metadata Preservation:** Preserve essential metadata during conversion, specifically including GPS location data.
6.  **Metadata Update:**
    *   Update the EXIF creation date/time tag (`DateTimeOriginal` or similar) in the output JPG to match the original capture date/time.
    *   Update the file system creation and modification dates of the output JPG file to match the original capture date/time.
7.  **User Interface:** Provide a simple graphical user interface (GUI) for file selection and initiating the conversion process. 