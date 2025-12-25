import SwiftUI
import SublerPlusCore

struct RootShellView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    var statusStream: StatusStream?
    @State private var sidebarSelection: SidebarItem? = .files
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
            } detail: {
                detailContent
                    .sheet(isPresented: bindingAmbiguitySheet) {
                        AmbiguitySheet(match: viewModel.pendingAmbiguity, onSelect: { choice in
                            if let pending = viewModel.pendingAmbiguity {
                                viewModel.resolveAmbiguity(choice: choice, for: pending)
                            }
                        })
                        .accessibilityLabel("Resolve Match Sheet")
                    }
            }
        } else {
            NavigationView {
                sidebar
                detailContent
                    .sheet(isPresented: bindingAmbiguitySheet) {
                        AmbiguitySheet(match: viewModel.pendingAmbiguity, onSelect: { choice in
                            if let pending = viewModel.pendingAmbiguity {
                                viewModel.resolveAmbiguity(choice: choice, for: pending)
                            }
                        })
                        .accessibilityLabel("Resolve Match Sheet")
                    }
            }
        }
    }

    private var bindingAmbiguitySheet: Binding<Bool> {
        Binding(
            get: { viewModel.showAmbiguitySheet && viewModel.pendingAmbiguity != nil },
            set: { newValue in
                if !newValue { viewModel.showAmbiguitySheet = false }
            }
        )
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("Library") {
                NavigationLink(destination: detailDestination(.files), tag: SidebarItem.files, selection: $sidebarSelection) {
                    Label("Files", systemImage: "film")
                        .accessibilityLabel("Files")
                }
            }
            Section("Actions") {
                NavigationLink(destination: detailDestination(.search), tag: SidebarItem.search, selection: $sidebarSelection) {
                    Label("Search", systemImage: "magnifyingglass")
                        .accessibilityLabel("Search")
                }
                NavigationLink(destination: detailDestination(.webui), tag: SidebarItem.webui, selection: $sidebarSelection) {
                    Label("Web UI", systemImage: "safari")
                        .accessibilityLabel("Web UI")
                }
                NavigationLink(destination: detailDestination(.settings), tag: SidebarItem.settings, selection: $sidebarSelection) {
                    Label("Settings", systemImage: "gearshape")
                        .accessibilityLabel("Settings")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Sidebar")
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(spacing: 0) {
            if viewModel.tokenMissing {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Web UI token not set")
                            .font(.headline)
                        Text("Set a token in Settings to reduce local misuse of Web UI/API.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") {
                        sidebarSelection = .settings
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.15))
            }
            detailDestination(sidebarSelection ?? .files)
        }
    }

    @ViewBuilder
    private func detailDestination(_ item: SidebarItem) -> some View {
        switch item {
        case .files:
            FileListView(viewModel: viewModel)
                .toolbar { fileToolbar }
        case .search:
            AdvancedSearchView(viewModel: viewModel)
                .toolbar { searchToolbar }
        case .settings:
            SettingsView(viewModel: settingsViewModel)
                .toolbar { settingsToolbar }
        case .webui:
            WebContentView()
        }
    }

    @ToolbarContentBuilder
    private var fileToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                viewModel.presentFilePicker()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityLabel("Add files")
            .accessibilityHint("Add one or more media files")
            Button {
                viewModel.enrichSelected()
            } label: {
                Label("Enrich", systemImage: "wand.and.stars")
            }
            .disabled(!viewModel.hasSelection)
            .keyboardShortcut("e", modifiers: [.command])
            .accessibilityLabel("Enrich selected file")
            .accessibilityHint("Apply metadata to the selected file")
        }
    }

    @ToolbarContentBuilder
    private var searchToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                viewModel.triggerSearch()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: [.command])
            .accessibilityLabel("Search metadata")
            .accessibilityHint("Search metadata providers")
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                viewModel.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])
            .accessibilityLabel("Open settings")
            .accessibilityHint("Open app settings")
        }
    }
}

private enum SidebarItem: Hashable {
    case files
    case search
    case settings
    case webui
}

