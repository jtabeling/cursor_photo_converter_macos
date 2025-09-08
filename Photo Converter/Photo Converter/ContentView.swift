//
//  ContentView.swift
//  Photo Converter
//
//  Created by jerry tabeling on 4/21/25.
//

import SwiftUI
import PhotosUI

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
                Button("Select Media") {
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
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            let identifiers = newItems.compactMap { $0.itemIdentifier }
            selectedPhotoIdentifiers = identifiers
            if !identifiers.isEmpty {
                statusMessages.append("\(identifiers.count) media items selected.")
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
