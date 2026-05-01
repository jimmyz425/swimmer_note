import SwiftUI
import PDFKit

/// A clickable link that displays a technique file reference and generates a PDF when tapped
struct TechniqueRefLink: View {
    let techniqueFileRef: String
    let appModel: SwimNoteAppModel

    @State private var isGeneratingPDF = false
    @State private var showPDFPreview = false
    @State private var pdfURL: URL?
    @State private var errorMessage: String?
    @State private var showErrorToast = false

    private let pdfGenerator = PDFGenerator()

    var body: some View {
        Button {
            generatePDF()
        } label: {
            HStack(spacing: 6) {
                if isGeneratingPDF {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(PoolTheme.mid)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.caption2)
                        .foregroundStyle(PoolTheme.mid)
                }

                Text(formatRef(techniqueFileRef))
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PoolTheme.mid.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(isGeneratingPDF)
        .sheet(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                PDFPreviewSheet(
                    pdfURL: url,
                    title: techniqueTitle
                )
            }
        }
        .alert("Error", isPresented: $showErrorToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    /// Format the reference for display
    private func formatRef(_ ref: String) -> String {
        // Remove file extension and path prefix
        let formatted = ref
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "swimming-strokes/", with: "")

        // Capitalize and format
        let parts = formatted.split(separator: "-")
        if parts.count >= 3 {
            // Format like "Freestyle: Flutter Kick"
            let stroke = parts[0].capitalized
            let name = parts[2...].map { $0.capitalized }.joined(separator: " ")
            return "\(stroke): \(name)"
        }
        return formatted.capitalized
    }

    /// Get technique title from parsed content
    private var techniqueTitle: String {
        if let content = appModel.parsedTechnique(filename: techniqueFileRef) {
            return content.title
        }
        return formatRef(techniqueFileRef)
    }

    /// Generate PDF from technique file
    private func generatePDF() {
        isGeneratingPDF = true
        errorMessage = nil

        Task {
            // Load technique content
            guard let content = appModel.parsedTechnique(filename: techniqueFileRef) else {
                await MainActor.run {
                    errorMessage = "Could not find technique file: \(techniqueFileRef)"
                    showErrorToast = true
                    isGeneratingPDF = false
                }
                return
            }

            // Generate PDF
            guard let url = pdfGenerator.generatePDF(from: content) else {
                await MainActor.run {
                    errorMessage = "Failed to generate PDF"
                    showErrorToast = true
                    isGeneratingPDF = false
                }
                return
            }

            await MainActor.run {
                pdfURL = url
                showPDFPreview = true
                isGeneratingPDF = false
            }
        }
    }
}

/// Preview sheet for viewing and sharing PDF
struct PDFPreviewSheet: View {
    let pdfURL: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // PDF View
                if let document = pdfDocument {
                    PDFKitView(document: document)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView("Loading PDF...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Action buttons
                HStack(spacing: 20) {
                    // Share button
                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview(
                            title,
                            image: Image(systemName: "doc.text.fill")
                        )
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .foregroundStyle(PoolTheme.mid)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(PoolTheme.mid.opacity(0.1))
                            .cornerRadius(10)
                    }

                    // Save to Files button
                    Button {
                        saveToFiles()
                    } label: {
                        Label("Save", systemImage: "folder")
                            .font(.subheadline.bold())
                            .foregroundStyle(PoolTheme.deep)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(PoolTheme.light.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(PoolTheme.surface)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            pdfDocument = PDFDocument(url: pdfURL)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Save PDF to Files app
    private func saveToFiles() {
        // Use UIDocumentPickerViewController or share sheet
        // ShareLink handles saving to Files via the share sheet
        // This button can trigger a direct save dialog on iPad

        // For iOS, the share sheet provides "Save to Files" option
        // This is a convenience button that opens the share sheet
        let activityVC = UIActivityViewController(
            activityItems: [pdfURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

/// SwiftUI wrapper for PDFKit PDFView
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(PoolTheme.surface)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}

#Preview("Technique Ref Link") {
    let model = SwimNoteAppModel.bootstrap()
    return VStack(spacing: 20) {
        TechniqueRefLink(
            techniqueFileRef: "freestyle-02-flutter-kick",
            appModel: model
        )

        TechniqueRefLink(
            techniqueFileRef: "backstroke-03-flutter-kick",
            appModel: model
        )

        TechniqueRefLink(
            techniqueFileRef: "butterfly-02-dolphin-kick-mechanics",
            appModel: model
        )
    }
    .padding()
    .background(PoolTheme.surface)
}