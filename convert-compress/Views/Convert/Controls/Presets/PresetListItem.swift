import SwiftUI

struct PresetListItem: View {
    let preset: Preset
    let index: Int
    @EnvironmentObject private var vm: ImageToolsViewModel
    @Binding var isPresented: Bool
    
    @State private var isHovered = false
    @State private var isBeingDragged = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        PresetItemView(
            configuration: preset.configuration,
            name: isEditing ? $editedName : .constant(preset.displayName),
            isEditing: isEditing,
            backgroundColor: isHovered ? Color.primary.opacity(0.10) : Color.clear,
            trailingButtons: {
                AnyView(
                    Group {
                        if isEditing {
                            editingButtons
                        } else if isHovered {
                            displayButtons
                        }
                    }
                )
            },
            isFocused: $isTextFieldFocused,
            onSubmit: saveEdit
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            vm.applyPreset(preset)
            isPresented = false
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDrag {
            isBeingDragged = true
            return NSItemProvider(object: preset.id.uuidString as NSString)
        } preview: {
            Color.clear.frame(width: 1, height: 1)
        }
        .onDrop(of: [.text], delegate: PresetDropDelegate(
            preset: preset,
            index: index,
            vm: vm,
            isBeingDragged: $isBeingDragged
        ))
        .onChange(of: isEditing) { _, editing in
            if editing {
                Task { @MainActor in
                    await Task.yield()
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private var displayButtons: some View {
        HStack(spacing: 0) {
            HoverIconButton(
                systemName: "pencil",
                action: {
                    editedName = preset.name ?? ""
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = true
                    }
                },
                iconWeight: .bold,
                cornerRadius: 6
            )
            .help("Edit preset name")
            
            HoverIconButton(
                systemName: "trash.fill",
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.7)) {
                        vm.deletePreset(preset)
                    }
                },
                destructive: true,
                iconWeight: .medium,
                cornerRadius: 6
            )
            .help("Delete preset")
        }
        .transition(.opacity)
    }
    
    private var editingButtons: some View {
        HStack(spacing: 0) {
            HoverIconButton(
                systemName: "xmark",
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                        editedName = ""
                    }
                },
                iconWeight: .medium,
                cornerRadius: 6
            )
            .help("Cancel")
            
            HoverIconButton(
                systemName: "checkmark",
                action: saveEdit,
                iconWeight: .bold,
                cornerRadius: 6
            )
            .help("Save preset name")
        }
    }
    
    private func saveEdit() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedPreset = Preset(
            id: preset.id,
            name: trimmedName.isEmpty ? nil : trimmedName,
            configuration: preset.configuration
        )
        vm.updatePreset(updatedPreset)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
    }
}

// MARK: - Drop Delegate

struct PresetDropDelegate: DropDelegate {
    let preset: Preset
    let index: Int
    let vm: ImageToolsViewModel
    @Binding var isBeingDragged: Bool
    
    
    func performDrop(info: DropInfo) -> Bool {
        isBeingDragged = false
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let items = info.itemProviders(for: [.text]).first else { return }
        
        items.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedIDString = String(data: data, encoding: .utf8),
                  let draggedID = UUID(uuidString: draggedIDString) else {
                return
            }
            
            DispatchQueue.main.async {
                guard let sourceIndex = vm.presets.firstIndex(where: { $0.id == draggedID }),
                      sourceIndex != index else {
                    return
                }
                
                withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                    vm.reorderPresets(from: sourceIndex, to: index)
                }
            }
        }
    }
    
    func dropExited(info: DropInfo) {
        isBeingDragged = false
    }
}

