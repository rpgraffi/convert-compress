import SwiftUI

struct RenamePopover: View {
    @Environment(AssetCollectionModule.self) private var assets
    @Environment(ExportRenameModule.self) private var rename
    @State private var cursorOffset = 0
    @State private var requestedCursorOffset: Int?
    @State private var isFieldFocused = false

    private let rowHeight: CGFloat = 28
    private let chipHeight: CGFloat = 28
    private let chipCornerRadius: CGFloat = 7
    private let joinedChipCornerRadius: CGFloat = 4

    var body: some View {
        @Bindable var rename = rename

        VStack(spacing: 0) {
            VStack(spacing: 8) {
                templateField
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                shortcuts(selection: $rename.dateFormatPreset)
            }
            .padding(.bottom, 10)

            Divider()

            previewList
        }
        .frame(width: 420)
        .onAppear {
            focusTemplateField()
        }
    }

    private var templateField: some View {
        HStack(spacing: 8) {
            RenameTemplateField(
                text: Binding(
                    get: { rename.template },
                    set: { rename.setTemplate($0) }
                ),
                cursorOffset: $cursorOffset,
                requestedCursorOffset: $requestedCursorOffset,
                isFocused: $isFieldFocused,
                placeholder: String(localized: "Rename images")
            )
            .frame(height: 28)

            if rename.hasDuplicateDestinations {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(String(localized: "This template creates duplicate destination filenames. Export will still continue."))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isFieldFocused ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }

    private func shortcuts(selection: Binding<RenameDateFormatPreset>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                shortcutButton(String(localized: "Original"), token: .originalName)
                indexShortcut
                dateMenu(selection: selection)
                shortcutButton(String(localized: "Width"), token: .width)
                shortcutButton(String(localized: "Height"), token: .height)
                shortcutButton(String(localized: "Quality"), token: .quality)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indexShortcut: some View {
        let width = assets.images.count > 100 ? 3 : 2

        return HStack(spacing: 1) {
            indexShortcutButton(
                String(localized: "Index ↑"),
                token: .indexUp(width: width),
                shape: UnevenRoundedRectangle(
                    topLeadingRadius: chipCornerRadius,
                    bottomLeadingRadius: chipCornerRadius,
                    bottomTrailingRadius: joinedChipCornerRadius,
                    topTrailingRadius: joinedChipCornerRadius,
                    style: .continuous
                )
            )
            indexShortcutButton(
                "↓",
                token: .indexDown(width: width),
                shape: UnevenRoundedRectangle(
                    topLeadingRadius: joinedChipCornerRadius,
                    bottomLeadingRadius: joinedChipCornerRadius,
                    bottomTrailingRadius: chipCornerRadius,
                    topTrailingRadius: chipCornerRadius,
                    style: .continuous
                )
            )
        }
    }

    private func shortcutButton(_ title: String, token: RenameToken) -> some View {
        Button {
            insert(token.text)
        } label: {
            shortcutChip(title)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func indexShortcutButton(
        _ title: String,
        token: RenameToken,
        shape: UnevenRoundedRectangle
    ) -> some View {
        Button {
            insert(token.text)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: chipHeight)
                .background(shape.fill(Theme.Colors.controlBackground))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func dateMenu(selection: Binding<RenameDateFormatPreset>) -> some View {
        Menu {
            dateMenuContent(selection: selection)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(String(localized: "Date"))
            }
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .frame(height: chipHeight)
        .background(
            RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
                .fill(Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous))
        .fixedSize()
    }

    @ViewBuilder
    private func dateMenuContent(selection: Binding<RenameDateFormatPreset>) -> some View {
        Button(String(localized: "Today")) {
            insert(RenameToken.today.text)
        }
        Button(String(localized: "Created")) {
            insert(RenameToken.created.text)
        }
        Button(String(localized: "Modified")) {
            insert(RenameToken.modified.text)
        }

        Divider()

        Picker(String(localized: "Date Format"), selection: selection) {
            ForEach(RenameDateFormatPreset.allCases) { preset in
                Text(preset.label).tag(preset)
            }
        }
    }

    private func shortcutChip(_ title: String) -> some View {
        Text(title)
            .shortcutChipStyle(height: chipHeight, cornerRadius: chipCornerRadius)
    }

    @ViewBuilder
    private var previewList: some View {
        if assets.images.isEmpty {
            let hasSamplePreview = rename.template.isEmpty == false

            previewRow(
                hasSamplePreview ? rename.samplePreviewFilename() : String(localized: "Preview renamed image names"),
                font: hasSamplePreview ? .system(size: 14, design: .monospaced) : .system(size: 12),
                foregroundStyle: hasSamplePreview ? .primary : .secondary,
                alignment: hasSamplePreview ? .leading : .center
            )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: rowHeight * 2)
        } else {
            let visibleRows = min(max(assets.images.count, 1), 4)
            let previewHeight = max(rowHeight * 2, CGFloat(visibleRows) * rowHeight + 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(assets.images.enumerated()), id: \.element.id) { index, asset in
                        Text(rename.previewFilename(for: asset, index: index))
                            .font(.system(size: 14, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: rowHeight)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: previewHeight, alignment: .center)
            }
            .frame(height: previewHeight)
            .mask(previewMask(isScrollable: assets.images.count > 4))
        }
    }

    private func previewRow(
        _ text: String,
        font: Font,
        foregroundStyle: Color,
        alignment: Alignment
    ) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: alignment)
            .frame(height: rowHeight)
    }

    private func previewMask(isScrollable: Bool) -> some View {
        Group {
            if isScrollable {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.78),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
            }
        }
    }

    private func insert(_ tokenText: String) {
        requestedCursorOffset = rename.insert(tokenText, atUTF16Offset: cursorOffset)
        focusTemplateField()
    }

    private func focusTemplateField() {
        Task { @MainActor in
            await Task.yield()
            isFieldFocused = true
        }
    }
}

private extension View {
    func shortcutChipStyle(height: CGFloat, cornerRadius: CGFloat) -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Colors.controlBackground)
            )
    }
}

