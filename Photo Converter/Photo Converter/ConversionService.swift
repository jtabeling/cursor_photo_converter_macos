import Foundation
import Photos
import ImageIO
import UniformTypeIdentifiers // For UTType.jpeg
import AppKit // For NSBitmapImageRep specific things if needed, maybe just ImageIO is enough
import AVFoundation // Added for video processing

actor ConversionService {

    enum ConversionError: LocalizedError {
        case authorizationDenied(String)
        case assetFetchFailed
        case missingCreationDate(String)
        case imageDataRequestFailed(String, Error?)
        case imageSourceCreationFailed(String)
        case destinationCreationFailed(String, Error?)
        case imageAddFailed(String, Error?)
        case timestampUpdateFailed(String, Error?)
        case outputDirectoryInvalid(String)
        case videoExportFailed(String, Error?)
        case videoMetadataUpdateFailed(String, Error?)
        case unknownError(String)

        var errorDescription: String? {
            switch self {
            case .authorizationDenied(let status): return "Photo Library access denied or restricted (\(status)). Please grant access in System Settings."
            case .assetFetchFailed: return "Failed to fetch photo assets from the library."
            case .missingCreationDate(let id): return "Could not determine original creation date for asset \(id)."
            case .imageDataRequestFailed(let id, let err): return "Failed to request image data for asset \(id): \(err?.localizedDescription ?? "Unknown reason")."
            case .imageSourceCreationFailed(let id): return "Failed to create image source for asset \(id)."
            case .destinationCreationFailed(let path, let err): return "Failed to create JPG destination at \(path): \(err?.localizedDescription ?? "Unknown reason")."
            case .imageAddFailed(let id, let err): return "Failed to add image data to JPG destination for asset \(id): \(err?.localizedDescription ?? "Unknown reason")."
            case .timestampUpdateFailed(let path, let err): return "Failed to update file timestamps for \(path): \(err?.localizedDescription ?? "Unknown reason")."
            case .outputDirectoryInvalid(let path): return "Output directory is invalid or not writable: \(path)."
            case .videoExportFailed(let id, let err): return "Failed to export video for asset \(id): \(err?.localizedDescription ?? "Unknown reason")."
            case .videoMetadataUpdateFailed(let msg, let err): return "Failed to update video metadata: \(msg) \(err?.localizedDescription ?? "")."
            case .unknownError(let msg): return "An unknown error occurred: \(msg)"
            }
        }
    }

    private let fileManager = FileManager.default
    private let imageManager = PHImageManager.default()

    // Formatter for the output filename
    private lazy var filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensure consistency
        formatter.timeZone = TimeZone.current // Use local time for filenames as per typical user expectation
        return formatter
    }()

    // Formatter for EXIF date strings (expects specific format)
    private lazy var exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss" // EXIF DateTime format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // TimeZone for EXIF is often undefined or local; using current seems reasonable for writing
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    func convert(
        photoIdentifiers: [String],
        outputDirectory: URL,
        progressHandler: @escaping @MainActor (Double, String) -> Void, // Ensure UI updates on main thread
        completionHandler: @escaping @MainActor ([String]) -> Void      // Ensure UI updates on main thread
    ) async {

        var errorMessages: [String] = []
        let totalAssets = photoIdentifiers.count
        var processedCount = 0

        // --- 1. Check Authorization ---
        let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite) // Need metadata access
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            let statusString: String
            switch authorizationStatus {
            case .denied: statusString = "Denied"
            case .restricted: statusString = "Restricted"
            case .notDetermined: statusString = "Not Determined (Should not happen after request)"
            default: statusString = "Unknown"
            }
            await completionHandler([ConversionError.authorizationDenied(statusString).localizedDescription])
            return
        }
        await progressHandler(0, "Authorization granted.")

        // --- 2. Verify Output Directory ---
        guard outputDirectory.startAccessingSecurityScopedResource() else {
             await completionHandler([ConversionError.outputDirectoryInvalid(outputDirectory.path).localizedDescription + " (Could not start access)"])
             return
        }
        // Remember to stop accessing later
        defer { outputDirectory.stopAccessingSecurityScopedResource() }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: outputDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            await completionHandler([ConversionError.outputDirectoryInvalid(outputDirectory.path).localizedDescription + " (Does not exist or is not a directory)"])
            return
        }
         guard fileManager.isWritableFile(atPath: outputDirectory.path) else {
            await completionHandler([ConversionError.outputDirectoryInvalid(outputDirectory.path).localizedDescription + " (Not writable)"])
            return
        }


        // --- 3. Fetch Assets ---
        let fetchOptions = PHFetchOptions()
        // fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)] // Optional sorting
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: photoIdentifiers, options: fetchOptions)

        // Check if any assets were fetched at all
        guard fetchResult.count > 0 else {
            await completionHandler(["Error: Found 0 assets for the provided identifiers."])
            return
        }

        // Log a warning if the number of fetched assets doesn't match the requested identifiers
        if fetchResult.count != totalAssets {
             await progressHandler(0, "Warning: Could not fetch all selected assets (\(fetchResult.count) of \(totalAssets) found).")
             // Continue processing with the assets that were found.
        }

        await progressHandler(0, "Starting conversion for \(fetchResult.count) media items...")

        // --- 4. Process Assets Concurrently ---
        await withTaskGroup(of: Result<String, ConversionError>.self) { group in
            for i in 0..<fetchResult.count {
                let asset = fetchResult.object(at: i)

                group.addTask {
                    // This closure runs concurrently for each asset
                    if asset.mediaType == .video {
                        return await self.processVideoAsset(asset: asset, outputDirectory: outputDirectory)
                    } else {
                        return await self.processImageAsset(asset: asset, outputDirectory: outputDirectory)
                    }
                }
            }

            // Collect results as they complete
            for await result in group {
                processedCount += 1
                let progress = Double(processedCount) / Double(fetchResult.count) // Use fetchResult.count which might be less than totalAssets

                switch result {
                case .success(let successMessage):
                    await progressHandler(progress, successMessage)
                case .failure(let error):
                    errorMessages.append(error.localizedDescription)
                    // Still report progress, but with error context if possible
                    await progressHandler(progress, "Error processing asset: \(error.localizedDescription)")
                }
            }
        }

        // --- 5. Completion ---
        let finalMessage = "Conversion complete. \(fetchResult.count - errorMessages.count) succeeded, \(errorMessages.count) failed."
        await progressHandler(1.0, finalMessage) // Ensure progress hits 100%
        errorMessages.insert(finalMessage, at: 0) // Add summary as first item
        await completionHandler(errorMessages)
    }

    // --- Helper function to process a single image asset ---
    private func processImageAsset(asset: PHAsset, outputDirectory: URL) async -> Result<String, ConversionError> {
        // --- 4a. Get Creation Date ---
        guard let creationDate = asset.creationDate else {
            // Maybe fallback to EXIF here if needed? PHAsset.creationDate should be reliable though.
            return .failure(.missingCreationDate(asset.localIdentifier))
        }
        let outputFilename = filenameDateFormatter.string(from: creationDate) + ".jpg"
        let outputFileURL = outputDirectory.appendingPathComponent(outputFilename)

        // --- 4b. Request Image Data and Metadata ---
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true // Required for fetchImageDataAndOrientation
        requestOptions.version = .current     // Get edits if available, .original for original
        requestOptions.deliveryMode = .highQualityFormat // Get best quality

        do {
            let imageDataResult = try await fetchImageData(for: asset, options: requestOptions)
            let heicData = imageDataResult.imageData
            let properties = imageDataResult.properties


            // --- Phase 5: Conversion & Metadata ---
            guard let source = CGImageSourceCreateWithData(heicData as CFData, nil) else {
                return .failure(.imageSourceCreationFailed(asset.localIdentifier))
            }

            // Preserve existing properties (like GPS, camera info etc.)
            var updatedProperties = properties as? [String: Any] ?? [:]

            // Update/Set EXIF DateTimeOriginal
            let exifDateString = exifDateFormatter.string(from: creationDate)
            var exifDict = updatedProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exifDict[kCGImagePropertyExifDateTimeOriginal as String] = exifDateString
            // Also update DateTimeDigitized if desired (often same as original)
            // exifDict[kCGImagePropertyExifDateTimeDigitized as String] = exifDateString
            updatedProperties[kCGImagePropertyExifDictionary as String] = exifDict

            // Add orientation if needed (often handled by system, but explicit can be good)
            // if let orientation = properties[kCGImagePropertyOrientation] {
            //     updatedProperties[kCGImagePropertyOrientation as String] = orientation
            // }
            
            // Set the image title metadata to match the filename (without extension)
            let filenameWithoutExtension = filenameDateFormatter.string(from: creationDate)
            var iptcDict = updatedProperties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
            iptcDict[kCGImagePropertyIPTCObjectName as String] = filenameWithoutExtension
            updatedProperties[kCGImagePropertyIPTCDictionary as String] = iptcDict
            
            // Also set the title in the TIFF dictionary
            var tiffDict = updatedProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiffDict[kCGImagePropertyTIFFImageDescription as String] = filenameWithoutExtension
            updatedProperties[kCGImagePropertyTIFFDictionary as String] = tiffDict

            // Specify JPG quality
            updatedProperties[kCGImageDestinationLossyCompressionQuality as String] = 0.8 // Adjust quality 0.0 (low) to 1.0 (high)

            guard let destination = CGImageDestinationCreateWithURL(outputFileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                 return .failure(.destinationCreationFailed(outputFileURL.path, nil))
            }

            // Add the image with updated metadata
             CGImageDestinationAddImageFromSource(destination, source, 0, updatedProperties as CFDictionary)

            // Finalize (write) the JPG file
             guard CGImageDestinationFinalize(destination) else {
                 // Try to get more error info if possible
                 return .failure(.imageAddFailed(asset.localIdentifier, nil))
             }


             // --- Phase 6: Update File Timestamps ---
             do {
                 try fileManager.setAttributes([
                     .creationDate: creationDate,
                     .modificationDate: creationDate
                 ], ofItemAtPath: outputFileURL.path)
             } catch {
                 // Log error but don't fail the whole conversion for this? Maybe return warning message?
                 // For now, return failure.
                 return .failure(.timestampUpdateFailed(outputFileURL.path, error))
             }

            return .success("Converted: \(outputFilename)")

        } catch let error as ConversionError {
             return .failure(error) // Propagate specific errors
        } catch {
             return .failure(.imageDataRequestFailed(asset.localIdentifier, error)) // Catch other errors from fetchImageData
        }
    }
    
    // --- Helper function to process a video asset ---
    private func processVideoAsset(asset: PHAsset, outputDirectory: URL) async -> Result<String, ConversionError> {
        // Get creation date for filename
        guard let creationDate = asset.creationDate else {
            return .failure(.missingCreationDate(asset.localIdentifier))
        }
        
        // Create filename with date/time and .mov extension
        let outputFilename = filenameDateFormatter.string(from: creationDate) + ".mov"
        let outputFileURL = outputDirectory.appendingPathComponent(outputFilename)
        
        // Check if output file already exists and remove it
        if fileManager.fileExists(atPath: outputFileURL.path) {
            do {
                try fileManager.removeItem(at: outputFileURL)
            } catch {
                return .failure(.videoExportFailed(asset.localIdentifier, error))
            }
        }
        
        // Log location info for debugging
        if let location = asset.location {
            print("Video has GPS data: lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), alt=\(location.altitude)")
        } else {
            print("Video has NO GPS data")
        }
        
        // Also check the asset's metadata directly for debugging
        let assetResources = PHAssetResource.assetResources(for: asset)
        print("Asset resources count: \(assetResources.count)")
        for resource in assetResources {
            print("Resource type: \(resource.type.rawValue), filename: \(resource.originalFilename)")
        }
        
        // Try AVAssetExportSession first as it better preserves metadata
        do {
            try await exportVideoWithExportSession(asset: asset, outputURL: outputFileURL, creationDate: creationDate)
            
            // Update file timestamps
            do {
                try fileManager.setAttributes([
                    .creationDate: creationDate,
                    .modificationDate: creationDate
                ], ofItemAtPath: outputFileURL.path)
            } catch {
                return .failure(.timestampUpdateFailed(outputFileURL.path, error))
            }
            
            // Verify the output file exists and has non-zero size
            if fileManager.fileExists(atPath: outputFileURL.path),
               let fileAttributes = try? fileManager.attributesOfItem(atPath: outputFileURL.path),
               let fileSize = fileAttributes[.size] as? UInt64, fileSize > 0 {
                return .success("Processed video: \(outputFilename) with direct resource export")
            } else {
                // If file doesn't exist or has zero size, throw an error to try the fallback method
                throw ConversionError.videoExportFailed(asset.localIdentifier, nil)
            }
        } 
        catch {
            print("First method failed: \(error.localizedDescription). Trying fallback method...")
            
            // If export session failed, try the direct resource export approach
            do {
                try await exportVideoWithAssetResource(asset: asset, outputURL: outputFileURL, creationDate: creationDate)
                
                // Update file timestamps
                do {
                    try fileManager.setAttributes([
                        .creationDate: creationDate,
                        .modificationDate: creationDate
                    ], ofItemAtPath: outputFileURL.path)
                } catch {
                    return .failure(.timestampUpdateFailed(outputFileURL.path, error))
                }
                
                return .success("Processed video with export session fallback: \(outputFilename)")
            }
            catch let fallbackError {
                print("Both video export methods failed: \(fallbackError)")
                return .failure(.videoExportFailed(asset.localIdentifier, fallbackError))
            }
        }
    }
    
    // Fallback export method using PHAssetResource - this should preserve metadata better
    private func exportVideoWithAssetResource(asset: PHAsset, outputURL: URL, creationDate: Date) async throws {
        // Get the video resource from the asset
        guard let assetResource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .video }) else {
            throw ConversionError.videoExportFailed(asset.localIdentifier, nil)
        }
        
        print("Exporting video using PHAssetResource: \(assetResource.originalFilename)")
        
        // Request the resource data
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            
            PHAssetResourceManager.default().writeData(for: assetResource, toFile: outputURL, options: options) { error in
                if let error = error {
                    print("PHAssetResource export failed: \(error.localizedDescription)")
                    continuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, error))
                } else {
                    print("PHAssetResource export succeeded")
                    
                    // After successful export, check if we need to update metadata
                    Task {
                        do {
                            // Check what metadata was preserved in the exported file
                            let exportedAsset = AVAsset(url: outputURL)
                            let exportedMetadata = try await exportedAsset.load(.metadata)
                            print("Exported file metadata count: \(exportedMetadata.count)")
                            
                            // Print all exported metadata for debugging
                            for (index, item) in exportedMetadata.enumerated() {
                                if let identifier = item.identifier {
                                    let valueString = (try? await item.load(.value))?.description ?? "nil"
                                    print("Exported Metadata[\(index)]: \(identifier.rawValue) = \(valueString)")
                                }
                            }
                            
                            // Check if GPS data was preserved
                            var hasGPSInExported = false
                            for item in exportedMetadata {
                                guard let identifier = item.identifier else { continue }
                                if identifier == AVMetadataIdentifier.quickTimeMetadataLocationISO6709 ||
                                   identifier == AVMetadataIdentifier.quickTimeMetadataLocationName ||
                                   identifier == AVMetadataIdentifier.quickTimeMetadataLocationNote ||
                                   identifier == AVMetadataIdentifier.quickTimeMetadataLocationRole ||
                                   identifier == AVMetadataIdentifier.quickTimeMetadataLocationBody ||
                                   identifier == AVMetadataIdentifier.quickTimeMetadataLocationDate {
                                    hasGPSInExported = true
                                    print("GPS metadata preserved in exported file: \(identifier.rawValue)")
                                    break
                                }
                            }
                            
                            if hasGPSInExported {
                                print("GPS metadata was preserved during PHAssetResource export")
                                // Only update title if needed
                                try await self.updateVideoMetadataPreservingExisting(at: outputURL, creationDate: creationDate, location: nil)
                            } else {
                                print("GPS metadata was NOT preserved, attempting to add it")
                                // Try to add GPS data from PHAsset location
                                try await self.updateVideoMetadataPreservingExisting(at: outputURL, creationDate: creationDate, location: asset.location)
                            }
                            
                            continuation.resume()
                        } catch {
                            print("Metadata update failed: \(error.localizedDescription)")
                            // Still continue, as the video export itself was successful
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
    
    // Primary export method using PHImageManager.requestExportSession with enhanced metadata handling
    private func exportVideoWithExportSession(asset: PHAsset, outputURL: URL, creationDate: Date) async throws {
        print("Trying export session approach")
        
        let options = PHVideoRequestOptions()
        options.version = .original // Use original to preserve all metadata
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        // Use continuation to handle the asynchronous PHImageManager request
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            imageManager.requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetPassthrough) { exportSession, info in
                // Check for errors in the info dictionary
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Export session creation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, error))
                    return
                }
                
                guard let exportSession = exportSession else {
                    print("Export session is nil")
                    continuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, nil))
                    return
                }
                
                // Get the AVAsset to access its metadata
                let avAsset = exportSession.asset
                
                // Get existing metadata from the original asset
                Task {
                    do {
                        let existingMetadata = try await avAsset.load(.metadata)
                        print("Original asset metadata count: \(existingMetadata.count)")
                        
                        // Print all existing metadata for debugging
                        for (index, item) in existingMetadata.enumerated() {
                            if let identifier = item.identifier {
                                let valueString = (try? await item.load(.value))?.description ?? "nil"
                                print("Original Metadata[\(index)]: \(identifier.rawValue) = \(valueString)")
                            }
                        }
                        
                        // Check if we have GPS data in the original
                        var hasOriginalGPS = false
                        for item in existingMetadata {
                            guard let identifier = item.identifier else { continue }
                            if identifier == AVMetadataIdentifier.quickTimeMetadataLocationISO6709 ||
                               identifier == AVMetadataIdentifier.quickTimeMetadataLocationName ||
                               identifier == AVMetadataIdentifier.quickTimeMetadataLocationNote ||
                               identifier == AVMetadataIdentifier.quickTimeMetadataLocationRole ||
                               identifier == AVMetadataIdentifier.quickTimeMetadataLocationBody ||
                               identifier == AVMetadataIdentifier.quickTimeMetadataLocationDate {
                                hasOriginalGPS = true
                                print("Found existing GPS metadata: \(identifier.rawValue)")
                                break
                            }
                        }
                        
                        print("Original asset has GPS data: \(hasOriginalGPS)")
                        
                        // Prepare metadata for export - start with ALL existing metadata
                        var exportMetadata = existingMetadata
                        
                        // Remove any existing title metadata to avoid duplicates
                        exportMetadata.removeAll { item in
                            return item.identifier == AVMetadataIdentifier.quickTimeMetadataTitle
                        }
                        
                        // Add our new title metadata
                        let filenameWithoutExtension = self.filenameDateFormatter.string(from: creationDate)
                        let titleItem = AVMutableMetadataItem()
                        titleItem.identifier = AVMetadataIdentifier.quickTimeMetadataTitle
                        titleItem.value = filenameWithoutExtension as NSString
                        titleItem.extendedLanguageTag = "und"
                        exportMetadata.append(titleItem)
                        
                        // Add GPS data if missing and we have location data from PHAsset
                        if !hasOriginalGPS, let location = asset.location {
                            print("Adding GPS data to export metadata from PHAsset location")
                            let coordinatesString = String(format: "%+.6f%+.6f/", location.coordinate.latitude, location.coordinate.longitude)
                            
                            let gpsItem = AVMutableMetadataItem()
                            gpsItem.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
                            gpsItem.value = coordinatesString as NSString
                            gpsItem.extendedLanguageTag = "und"
                            exportMetadata.append(gpsItem)
                            
                            if location.altitude != 0 {
                                let altitudeItem = AVMutableMetadataItem()
                                altitudeItem.identifier = AVMetadataIdentifier(rawValue: "com.apple.quicktime.altitude")
                                altitudeItem.value = NSNumber(value: location.altitude)
                                altitudeItem.extendedLanguageTag = "und"
                                exportMetadata.append(altitudeItem)
                            }
                        } else if hasOriginalGPS {
                            print("Preserving existing GPS metadata from original asset")
                        }
                        
                        // Configure export with metadata
                        exportSession.outputURL = outputURL
                        exportSession.outputFileType = .mov
                        exportSession.metadata = exportMetadata
                        
                        print("Export metadata count: \(exportMetadata.count)")
                        
                        // Use a continuation to wait for the export
                        try await withCheckedThrowingContinuation { (exportContinuation: CheckedContinuation<Void, Error>) in
                            exportSession.exportAsynchronously {
                                switch exportSession.status {
                                case .completed:
                                    print("Export session completed successfully")
                                    exportContinuation.resume()
                                case .failed:
                                    print("Export session failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
                                    exportContinuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, exportSession.error))
                                case .cancelled:
                                    print("Export session cancelled")
                                    exportContinuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, nil))
                                default:
                                    print("Export session ended with unexpected status: \(exportSession.status.rawValue)")
                                    exportContinuation.resume(throwing: ConversionError.videoExportFailed(asset.localIdentifier, nil))
                                }
                            }
                        }
                        
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // Helper method to update metadata on an exported video file while preserving existing metadata
    private func updateVideoMetadataPreservingExisting(at fileURL: URL, creationDate: Date, location: CLLocation?) async throws {
        // Create an AVAsset from the exported file
        let asset = AVAsset(url: fileURL)
        
        // Get all existing metadata
        var allMetadata = try await asset.load(.metadata)
        print("Original metadata count: \(allMetadata.count)")
        
        // Print debugging information about existing metadata
        for (index, item) in allMetadata.enumerated() {
            if let identifier = item.identifier {
                let valueString = (try? await item.load(.value))?.description ?? "nil"
                print("Metadata[\(index)]: \(identifier.rawValue) = \(valueString)")
            }
        }
        
        // Check if we already have GPS data
        var hasExistingGPS = false
        for item in allMetadata {
            guard let identifier = item.identifier else { continue }
            if identifier == AVMetadataIdentifier.quickTimeMetadataLocationISO6709 ||
               identifier == AVMetadataIdentifier.quickTimeMetadataLocationName ||
               identifier == AVMetadataIdentifier.quickTimeMetadataLocationNote ||
               identifier == AVMetadataIdentifier.quickTimeMetadataLocationRole ||
               identifier == AVMetadataIdentifier.quickTimeMetadataLocationBody ||
               identifier == AVMetadataIdentifier.quickTimeMetadataLocationDate {
                hasExistingGPS = true
                break
            }
        }
        
        print("Has existing GPS data: \(hasExistingGPS)")
        
        // Only update title metadata if it doesn't match our desired format
        let filenameWithoutExtension = filenameDateFormatter.string(from: creationDate)
        let hasCorrectTitle = allMetadata.contains { item in
            guard let identifier = item.identifier,
                  identifier == AVMetadataIdentifier.quickTimeMetadataTitle else { return false }
            // Note: We can't easily check the value here due to async nature, so we'll assume it needs updating
            return false
        }
        
        // If we have existing GPS data and correct title, no need to re-export
        if hasExistingGPS && hasCorrectTitle {
            print("Video already has correct GPS data and title, skipping metadata update")
            return
        }
        
        // Create a temporary output file URL
        let tempFilename = UUID().uuidString + ".mov"
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(tempFilename)
        
        // Create an export session to add metadata
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw ConversionError.videoMetadataUpdateFailed("Failed to create export session", nil)
        }
        
        // Only remove metadata items we plan to replace to avoid duplication
        allMetadata.removeAll { item in
            return item.identifier == AVMetadataIdentifier.quickTimeMetadataTitle
        }
        
        // Add our new title metadata if needed
        if !hasCorrectTitle {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = AVMetadataIdentifier.quickTimeMetadataTitle
            titleItem.value = filenameWithoutExtension as NSString
            titleItem.extendedLanguageTag = "und"
            allMetadata.append(titleItem)
        }
        
        // Add GPS data only if it's missing and we have location data
        if !hasExistingGPS, let location = location {
            print("Adding missing GPS data")
            // GPS coordinates in ISO 6709 format: ±DD.DDDD±DDD.DDDD/
            let coordinatesString = String(format: "%+.6f%+.6f/", location.coordinate.latitude, location.coordinate.longitude)
            
            // Create GPS coordinates metadata item
            let gpsItem = AVMutableMetadataItem()
            gpsItem.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
            gpsItem.value = coordinatesString as NSString
            gpsItem.extendedLanguageTag = "und"
            allMetadata.append(gpsItem)
            
            // Create altitude metadata if available
            if location.altitude != 0 {
                let altitudeItem = AVMutableMetadataItem()
                altitudeItem.identifier = AVMetadataIdentifier(rawValue: "com.apple.quicktime.altitude")
                altitudeItem.value = NSNumber(value: location.altitude)
                altitudeItem.extendedLanguageTag = "und"
                allMetadata.append(altitudeItem)
            }
        }
        
        // Apply all metadata to the export session
        exportSession.metadata = allMetadata
        print("Final metadata count: \(allMetadata.count)")
        
        // Configure export
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        
        // Export asynchronously
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    do {
                        // Replace original file with the updated one
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try FileManager.default.removeItem(at: fileURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: fileURL)
                        print("Successfully updated video metadata")
                        continuation.resume()
                    } catch {
                        print("Error replacing file after metadata update: \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? ConversionError.videoMetadataUpdateFailed("Export failed", nil))
                case .cancelled:
                    continuation.resume(throwing: ConversionError.videoMetadataUpdateFailed("Export was cancelled", nil))
                default:
                    continuation.resume(throwing: ConversionError.videoMetadataUpdateFailed("Unexpected export status", nil))
                }
            }
        }
    }
    
    // Legacy helper method to update metadata on an exported video file (kept for compatibility)
    private func updateVideoMetadata(at fileURL: URL, creationDate: Date, location: CLLocation?) async throws {
        // Create an AVAsset from the exported file
        let asset = AVAsset(url: fileURL)
        
        // Create a temporary output file URL
        let tempFilename = UUID().uuidString + ".mov"
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(tempFilename)
        
        // Create an export session to add metadata
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw ConversionError.videoMetadataUpdateFailed("Failed to create export session", nil)
        }
        
        // Get all existing metadata
        var allMetadata = try await asset.load(.metadata)
        print("Original metadata count: \(allMetadata.count)")
        
        // Print debugging information about existing metadata
        for (index, item) in allMetadata.enumerated() {
            if let identifier = item.identifier {
                let valueString = (try? await item.load(.value))?.description ?? "nil"
                print("Metadata[\(index)]: \(identifier.rawValue) = \(valueString)")
            }
        }
        
        // Only remove metadata items we plan to replace to avoid duplication
        allMetadata.removeAll { item in
            return item.identifier == AVMetadataIdentifier.quickTimeMetadataTitle
        }
        
        // Create and add our new title metadata - using the filename without extension
        let filenameWithoutExtension = filenameDateFormatter.string(from: creationDate)
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = AVMetadataIdentifier.quickTimeMetadataTitle
        titleItem.value = filenameWithoutExtension as NSString
        titleItem.extendedLanguageTag = "und"
        allMetadata.append(titleItem)
        
        // Create and add creation date if missing
        if !allMetadata.contains(where: { $0.identifier == AVMetadataIdentifier.quickTimeMetadataCreationDate }) {
            let creationDateItem = AVMutableMetadataItem()
            creationDateItem.identifier = AVMetadataIdentifier.quickTimeMetadataCreationDate
            creationDateItem.value = exifDateFormatter.string(from: creationDate) as NSString
            creationDateItem.extendedLanguageTag = "und"
            allMetadata.append(creationDateItem)
        }
        
        // Add location data if provided and missing in original metadata
        if let location = location {
            // Check if GPS data already exists
            let hasGPSData = allMetadata.contains { item in
                return item.identifier == AVMetadataIdentifier.quickTimeMetadataLocationISO6709
            }
            
            if !hasGPSData {
                print("Adding missing GPS data")
                // GPS coordinates in ISO 6709 format: ±DD.DDDD±DDD.DDDD/
                let coordinatesString = String(format: "%+.6f%+.6f/", location.coordinate.latitude, location.coordinate.longitude)
                
                // Create GPS coordinates metadata item
                let gpsItem = AVMutableMetadataItem()
                gpsItem.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
                gpsItem.value = coordinatesString as NSString
                gpsItem.extendedLanguageTag = "und"
                allMetadata.append(gpsItem)
                
                // Create altitude metadata if available
                if location.altitude != 0 {
                    let altitudeItem = AVMutableMetadataItem()
                    altitudeItem.identifier = AVMetadataIdentifier(rawValue: "com.apple.quicktime.altitude")
                    altitudeItem.value = NSNumber(value: location.altitude)
                    altitudeItem.extendedLanguageTag = "und"
                    allMetadata.append(altitudeItem)
                }
            }
        }
        
        // Apply all metadata to the export session
        exportSession.metadata = allMetadata
        print("Final metadata count: \(allMetadata.count)")
        
        // Configure export
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        
        // Export asynchronously
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    do {
                        // Replace original file with the updated one
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try FileManager.default.removeItem(at: fileURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: fileURL)
                        print("Successfully updated video metadata")
                        continuation.resume()
                    } catch {
                        print("Error replacing file after metadata update: \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? ConversionError.videoMetadataUpdateFailed("Export failed", nil))
                case .cancelled:
                    continuation.resume(throwing: ConversionError.videoMetadataUpdateFailed("Export was cancelled", nil))
                default:
                    continuation.resume(throwing: ConversionError.videoMetadataUpdateFailed("Unexpected export status", nil))
                }
            }
        }
    }
    
    // Helper function to fetch image data asynchronously
    private func fetchImageData(for asset: PHAsset, options: PHImageRequestOptions) async throws -> (imageData: Data, properties: NSDictionary) {
         return try await withCheckedThrowingContinuation { continuation in
             imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                 // Check for errors passed in the info dictionary
                 if let error = info?[PHImageErrorKey] as? Error {
                     continuation.resume(throwing: ConversionError.imageDataRequestFailed(asset.localIdentifier, error))
                     return
                 }
                 // Ensure we got data
                 guard let imageData = data else {
                     continuation.resume(throwing: ConversionError.imageDataRequestFailed(asset.localIdentifier, nil))
                     return
                 }

                 // Extract properties (metadata)
                 guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                       let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) else {
                      // This should ideally not fail if data is valid, but handle it
                      continuation.resume(throwing: ConversionError.imageSourceCreationFailed(asset.localIdentifier))
                     return
                 }

                 continuation.resume(returning: (imageData: imageData, properties: properties))
             }
         }
     }
} 