//
//  ContentView.swift
//  Photo Converter
//
//  Created by jerry tabeling on 4/21/25.
//

import SwiftUI
import PhotosUI
import Photos

struct ContentView: View {
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoIdentifiers: [String] = []
    @State private var outputFolderURL: URL? = nil
    @State private var isProcessing = false
    @State private var progressValue: Double = 0.0
    @State private var statusMessages: [String] = []
    @State private var showFileImporter = false

    // Instance of the conversion service
    private let conversionService = ConversionService()

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button("Select HEIC Images (img*.heic)") {
                    selectedPhotoItems = []
                    selectedPhotoIdentifiers = []
                    showPhotosPicker = true
                }
                .disabled(isProcessing)

                Text("Selected: \(selectedPhotoIdentifiers.count) items")
                    .padding(.leading)
            }

            HStack {
                Button("Choose Output Folder") {
                    showFileImporter = true
                }
                .disabled(isProcessing || selectedPhotoIdentifiers.isEmpty)

                Text(outputFolderURL?.lastPathComponent ?? "No folder chosen")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading)
            }

            Button("Start Conversion") {
                // Ensure we have everything needed
                guard !selectedPhotoIdentifiers.isEmpty, let outputDir = outputFolderURL else {
                    statusMessages.append("Error: Select photos/videos and an output folder first.")
                    return
                }
                
                // Start the conversion process
                startConversion(identifiers: selectedPhotoIdentifiers, outputDirectory: outputDir)
            }
            .disabled(isProcessing || selectedPhotoIdentifiers.isEmpty || outputFolderURL == nil)
            .keyboardShortcut(.defaultAction)

            if isProcessing {
                ProgressView(value: progressValue, total: 1.0) {
                    Text("Processing... \(Int(progressValue * 100))%")
                } currentValueLabel: {
                    // Optional: You can add more detail here if needed
                }
                .padding(.vertical)
            }

            Text("Status:")
                .font(.headline)

            List {
                ForEach(statusMessages, id: \.self) { message in
                    Text(message)
                }
            }
            .frame(minHeight: 100)
            .border(Color.gray.opacity(0.5))
        }
        .padding()
        .frame(minWidth: 400, minHeight: 350)
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotoItems,
            matching: .images, // Only show images, not videos
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                let filteredIdentifiers = await filterImagesStartingWithImg(newItems)
                await MainActor.run {
                    selectedPhotoIdentifiers = filteredIdentifiers
                    if !filteredIdentifiers.isEmpty {
                        statusMessages.append("\(filteredIdentifiers.count) HEIC images starting with 'img' selected.")
                    } else if !newItems.isEmpty {
                        statusMessages.append("No images found starting with 'img' and ending with '.heic'.")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Stop accessing the previous folder if one was selected
                    outputFolderURL?.stopAccessingSecurityScopedResource()
                    
                    if url.startAccessingSecurityScopedResource() {
                        outputFolderURL = url
                        statusMessages.append("Output folder selected: \(url.path)")
                    } else {
                        outputFolderURL = nil // Reset if access failed
                        statusMessages.append("Error: Could not access output folder.")
                    }
                } else {
                    statusMessages.append("Error: No folder URL received.")
                }
            case .failure(let error):
                statusMessages.append("Error selecting output folder: \(error.localizedDescription)")
            }
        }
        // Make sure to stop accessing the security scoped resource on exit
        .onDisappear {
            outputFolderURL?.stopAccessingSecurityScopedResource()
        }
    }

    // Function to filter images that start with "img" and have .heic suffix
    private func filterImagesStartingWithImg(_ items: [PhotosPickerItem]) async -> [String] {
        var filteredIdentifiers: [String] = []
        
        for item in items {
            guard let identifier = item.itemIdentifier else { continue }
            
            // Fetch the PHAsset to check its filename
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = fetchResult.firstObject else { continue }
            
            // Get the asset resources to check the filename
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                let filename = resource.originalFilename.lowercased()
                
                // Check if filename starts with "img" and ends with ".heic"
                if filename.hasPrefix("img") && filename.hasSuffix(".heic") {
                    filteredIdentifiers.append(identifier)
                    break // Found a matching resource, no need to check others
                }
            }
        }
        
        return filteredIdentifiers
    }

    // Function to initiate the conversion task
    private func startConversion(identifiers: [String], outputDirectory: URL) {
        isProcessing = true
        statusMessages = ["Starting conversion..."] // Clear previous messages
        progressValue = 0.0

        Task { // Run the conversion in a background Task
            await conversionService.convert(
                photoIdentifiers: identifiers,
                outputDirectory: outputDirectory,
                progressHandler: { progress, message in // Runs on MainActor (UI thread)
                    self.progressValue = progress
                    self.statusMessages.append(message)
                },
                completionHandler: { errorMessages in // Runs on MainActor (UI thread)
                    self.isProcessing = false
                    // Optionally clear selection after completion?
                    // self.selectedPhotoIdentifiers = []
                    // self.selectedPhotoItems = []
                    // Prepend errors to status (summary is already first)
                    self.statusMessages.insert(contentsOf: errorMessages.dropFirst(), at: 1) // Insert errors after summary
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
