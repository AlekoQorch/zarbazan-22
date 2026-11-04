import SwiftUI
import UniformTypeIdentifiers

struct MusicDocumentPicker: UIViewControllerRepresentable {
    var allowsMultipleSelection: Bool = true
    var onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types = MetadataExtractor.supportedTypes
        types.append(.folder)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var staged: [URL] = []

            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    for fileURL in Self.collectAudioFiles(in: url) {
                        if let copy = Self.stageCopy(of: fileURL) {
                            staged.append(copy)
                        }
                    }
                } else if let copy = Self.stageCopy(of: url) {
                    staged.append(copy)
                }
            }

            onPick(staged)
        }

        /// Copy into app temp storage while the security scope is valid.
        private static func stageCopy(of url: URL) -> URL? {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("nova-import-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let dest = folder.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: dest)
                return dest
            } catch {
                return nil
            }
        }

        private static func collectAudioFiles(in directory: URL) -> [URL] {
            var results: [URL] = []
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return results }

            for case let fileURL as URL in enumerator where MetadataExtractor.isSupported(url: fileURL) {
                results.append(fileURL)
            }
            return results.sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
        }
    }
}

struct ImportProgressOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let progress = appState.importer.progress
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: NovaTheme.Spacing.md) {
                Text(appState.importer.isImporting ? "Importing Music" : "Import Complete")
                    .font(.headline)
                    .foregroundStyle(Color.novaTextPrimary)

                if appState.importer.isImporting {
                    ProgressView(value: progress.fraction)
                        .tint(Color.novaAccent)
                    Text(progress.currentFileName)
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                        .lineLimit(1)
                    Text("\(progress.completed) of \(progress.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.novaTextSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        labelRow("Added", value: "\(progress.succeeded)")
                        labelRow("Duplicates skipped", value: "\(progress.skippedDuplicates)")
                        labelRow("Failed", value: "\(progress.failed)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !progress.errors.isEmpty {
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(progress.errors.prefix(8)) { error in
                                    Text("\(error.fileName): \(error.message)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.novaDestructive)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }

                    Button("Done") {
                        appState.importer.dismissProgress()
                    }
                    .buttonStyle(NovaPrimaryButtonStyle())
                    .padding(.top, NovaTheme.Spacing.sm)
                }
            }
            .padding(NovaTheme.Spacing.lg)
            .frame(maxWidth: 340)
            .background(Color.novaSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.sheet, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding()
        }
    }

    private func labelRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.novaTextSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.novaTextPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }
}

struct NovaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.novaAccent.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.large, style: .continuous))
    }
}

struct NovaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.novaTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.novaSurfaceElevated.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.medium, style: .continuous))
    }
}
