import SwiftUI

struct PresetPopover: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @Binding var isPresented: Bool
    @State private var isAddingPreset = false
    @State private var newPresetName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Presets list
            if vm.presets.isEmpty {
                VStack(spacing: 4) {
                    Text("Here are your presets")
                        .foregroundStyle(.secondary)
                    Text("Presets are synced across all your devices over iCloud.")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(height: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(vm.presets.enumerated()), id: \.element.id) { index, preset in
                                PresetListItem(
                                    preset: preset,
                                    index: index,
                                    isPresented: $isPresented
                                )
                                .id(preset.id)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: vm.presets.count) { oldCount, newCount in
                        guard newCount > oldCount, let lastPreset = vm.presets.last else { return }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation(.easeOut(duration: 0.30)) {
                                proxy.scrollTo(lastPreset.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Add preset section
            VStack(alignment: .center, spacing: 0) {
                Divider()
                
                if isAddingPreset {
                    inlinePresetEditor
                        .padding(8)
                        .transition(.opacity)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAddingPreset = true
                            newPresetName = ""
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add preset")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .padding(16)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .transition(.opacity)
                }
            }
            .onChange(of: isAddingPreset) { _, isAdding in
                if isAdding {
                    Task { @MainActor in
                        await Task.yield()
                        isTextFieldFocused = true
                    }
                }
            }
        }
        .frame(width: 300)
    }
    
    private var inlinePresetEditor: some View {
        PresetItemView(
            configuration: vm.currentConfiguration,
            name: $newPresetName,
            isEditing: true,
            backgroundColor: Color.accentColor.opacity(0.10),
            trailingButtons: {
                AnyView(
                    HStack(spacing: 0) {
                        HoverIconButton(
                            systemName: "xmark",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAddingPreset = false
                                    newPresetName = ""
                                }
                            },
                            iconWeight: .medium,
                            cornerRadius: 6
                        )
                        .help("Cancel")
                        
                        HoverIconButton(
                            systemName: "checkmark",
                            action: saveNewPreset,
                            iconWeight: .bold,
                            cornerRadius: 6
                        )
                        .help("Save preset")
                    }
                )
            },
            isFocused: $isTextFieldFocused,
            onSubmit: saveNewPreset
        )
    }
    
    private func saveNewPreset() {
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        vm.savePreset(name: trimmedName.isEmpty ? nil : trimmedName)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isAddingPreset = false
            newPresetName = ""
        }
    }
}

