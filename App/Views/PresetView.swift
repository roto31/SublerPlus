import SwiftUI
import SublerPlusCore

/// UI for managing and applying muxing presets
public struct PresetView: View {
    @State private var presetManager: PresetManager?
    @State private var selectedPreset: Preset?
    @State private var showingEditSheet = false
    @State private var editingPreset: Preset?
    @Binding var selectedPresetID: UUID?
    
    public init(selectedPresetID: Binding<UUID?>) {
        self._selectedPresetID = selectedPresetID
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muxing Presets")
                .font(.headline)
            
            // Preset list
            List(selection: $selectedPresetID) {
                Section("Built-in Presets") {
                    ForEach(BuiltInPreset.allCases) { builtIn in
                        let preset = builtIn.createPreset()
                        PresetRow(preset: preset)
                            .tag(preset.id)
                    }
                }
                
                Section("Custom Presets") {
                    ForEach(customPresets) { preset in
                        PresetRow(preset: preset)
                            .tag(preset.id)
                            .contextMenu {
                                Button("Edit") {
                                    editingPreset = preset
                                    showingEditSheet = true
                                }
                                Button("Delete", role: .destructive) {
                                    Task {
                                        await presetManager?.deletePreset(id: preset.id)
                                        await loadPresets()
                                    }
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            
            // Action buttons
            HStack {
                Button("New Preset") {
                    editingPreset = nil
                    showingEditSheet = true
                }
                
                Spacer()
                
                if selectedPresetID != nil {
                    Button("Apply") {
                        // Apply preset action would be handled by parent
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingEditSheet) {
            if let editing = editingPreset {
                PresetEditView(preset: editing) { updatedPreset in
                    Task {
                        await presetManager?.savePreset(updatedPreset)
                        await loadPresets()
                    }
                }
            } else {
                PresetEditView(preset: nil) { newPreset in
                    Task {
                        await presetManager?.savePreset(newPreset)
                        await loadPresets()
                    }
                }
            }
        }
        .task {
            presetManager = PresetManager()
            await loadPresets()
        }
        .onChange(of: selectedPresetID) { newID in
            if let id = newID {
                Task {
                    selectedPreset = await presetManager?.getPreset(id: id)
                }
            }
        }
    }
    
    @State private var allPresets: [Preset] = []
    
    private var customPresets: [Preset] {
        let builtInIds = Set(BuiltInPreset.allCases.map { $0.createPreset().id })
        return allPresets.filter { !builtInIds.contains($0.id) }
    }
    
    private func loadPresets() async {
        guard let manager = presetManager else { return }
        allPresets = await manager.getAllPresets()
    }
}

struct PresetRow: View {
    let preset: Preset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name)
                .font(.body)
            if let description = preset.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label(preset.outputFormat.rawValue.uppercased(), systemImage: "doc")
                if preset.optimize {
                    Label("Optimized", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct PresetEditView: View {
    let initialPreset: Preset?
    let onSave: (Preset) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var outputFormat: MP4BrandHandler.OutputFormat
    @State private var optimize: Bool
    
    init(preset: Preset?, onSave: @escaping (Preset) -> Void) {
        self.initialPreset = preset
        self.onSave = onSave
        _name = State(initialValue: preset?.name ?? "")
        _description = State(initialValue: preset?.description ?? "")
        _outputFormat = State(initialValue: preset?.outputFormat ?? .mp4)
        _optimize = State(initialValue: preset?.optimize ?? false)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Settings") {
                    TextField("Preset Name", text: $name)
                    if #available(macOS 13.0, *) {
                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        TextField("Description", text: $description)
                    }
                }
                
                Section("Output Format") {
                    Picker("Format", selection: $outputFormat) {
                        ForEach([MP4BrandHandler.OutputFormat.mp4, .m4v, .m4a, .m4b, .m4r], id: \.self) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Optimize", isOn: $optimize)
                }
            }
            .navigationTitle(initialPreset == nil ? "New Preset" : "Edit Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let preset = Preset(
                            id: initialPreset?.id ?? UUID(),
                            name: name,
                            description: description.isEmpty ? nil : description,
                            outputFormat: outputFormat,
                            optimize: optimize
                        )
                        onSave(preset)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
