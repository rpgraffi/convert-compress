import AppKit
import SwiftUI

struct HoverControls: View {
    let asset: ImageAsset
    let isVisible: Bool

    @Environment(EncodedOutputModule.self) private var encodedOutput
    @Environment(ImageToolsSessionModule.self) private var session
    @State private var copyState: CopyState = .idle

    private enum CopyState {
        case idle, loading, success, error
    }

    var body: some View {
        HStack(spacing: 10) {
            revealButton
            copyButton
            removeButton
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(6)
        .background(OverlayBackground(cornerRadius: 6))
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        .opacity(isVisible ? 1 : 0)
    }

    private var revealButton: some View {
        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([asset.workingURL]) }) {
            Image(systemName: "folder.fill")
        }
        .buttonStyle(.plain)
        .help(String(localized: "Reveal in Finder"))
    }

    private var copyButton: some View {
        Button(action: copyToClipboard) {
            ZStack {
                if copyState == .loading {
                    ProgressView()
                        .controlSize(.mini)
                        .transition(.opacity)
                } else {
                    Image(systemName: copyIconName)
                        .foregroundStyle(copyIconColor)
                        .contentTransition(.symbolEffect(.replace))
                        .transition(.opacity)
                }
            }
            .frame(width: 13, height: 13)
            .animation(.easeInOut(duration: 0.15), value: copyState)
        }
        .buttonStyle(.plain)
        .disabled(copyState == .loading)
        .help(String(localized: "Copy image to clipboard"))
    }

    private var copyIconColor: Color {
        switch copyState {
        case .idle, .loading: .secondary
        case .success: .green
        case .error: .red
        }
    }

    private var copyIconName: String {
        switch copyState {
        case .idle, .loading: "doc.on.doc.fill"
        case .success: "checkmark.app.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var removeButton: some View {
        Button(role: .destructive, action: { session.remove(asset) }) {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .help(String(localized: "Remove from list"))
    }

    private func copyToClipboard() {
        copyState = .loading

        let localAsset = asset

        Task {
            do {
                let tempURL = try await encodedOutput.temporaryEncodedOutputURL(for: localAsset)
                ClipboardService.copyFileURL(tempURL)
                copyState = .success
            } catch {
                copyState = .error
            }

            try? await Task.sleep(for: .seconds(1))
            copyState = .idle
        }
    }
}
