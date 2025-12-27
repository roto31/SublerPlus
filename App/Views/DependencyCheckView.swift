import SwiftUI
import SublerPlusCore

struct DependencyCheckView: View {
    @StateObject private var checker = DependencyCheckViewModel()
    @Environment(\.dismiss) private var dismiss
    let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Dependency Check")
                .font(.title2)
                .fontWeight(.bold)
            
            if checker.isChecking {
                ProgressView("Checking dependencies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if checker.result.allInstalled {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("All dependencies are installed and up-to-date!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Some dependencies are missing or outdated")
                                        .font(.headline)
                                    if checker.result.missingCount > 0 {
                                        Text("\(checker.result.missingCount) missing")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    if checker.result.outdatedCount > 0 {
                                        Text("\(checker.result.outdatedCount) outdated")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        ForEach(checker.result.dependencies) { dependency in
                            DependencyRowView(dependency: dependency, checker: checker)
                        }
                        
                        if !checker.result.allInstalled {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Affected Features")
                                    .font(.headline)
                                
                                let missingFeatures = checker.result.dependencies
                                    .filter { $0.status == .missing }
                                    .flatMap { $0.requiredFeatures }
                                
                                ForEach(Array(Set(missingFeatures)), id: \.self) { feature in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text(feature)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            HStack {
                if !checker.result.allInstalled {
                    Button("View Installation Instructions") {
                        checker.showInstallInstructions = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(checker.result.allInstalled ? "Continue" : "Continue Anyway") {
                    onDismiss?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $checker.showInstallInstructions) {
            InstallationInstructionsView(
                dependencies: checker.result.dependencies.filter { $0.status == .missing },
                checker: DependencyChecker.shared
            )
        }
    }
}

@MainActor
private class DependencyCheckViewModel: ObservableObject {
    @Published var isChecking = true
    @Published var result = DependencyCheckResult(dependencies: [])
    @Published var showInstallInstructions = false
    
    init() {
        Task {
            await checkDependencies()
        }
    }
    
    func checkDependencies() async {
        isChecking = true
        let checker = DependencyChecker.shared
        result = await checker.checkAllDependencies()
        isChecking = false
    }
}

private struct DependencyRowView: View {
    let dependency: DependencyInfo
    @ObservedObject var checker: DependencyCheckViewModel
    @State private var showDetails = false
    
    var statusColor: Color {
        switch dependency.status {
        case .installed: return .green
        case .outdated: return .yellow
        case .missing: return .red
        }
    }
    
    var statusIcon: String {
        switch dependency.status {
        case .installed: return "checkmark.circle.fill"
        case .outdated: return "exclamationmark.circle.fill"
        case .missing: return "xmark.circle.fill"
        }
    }
    
    var statusText: String {
        switch dependency.status {
        case .installed: return "Installed"
        case .outdated: return "Outdated"
        case .missing: return "Not Installed"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dependency.name)
                        .font(.headline)
                    Text(dependency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                    if let version = dependency.installedVersion {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if showDetails && dependency.status == .missing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Required for:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(dependency.requiredFeatures, id: \.self) { feature in
                        Text("• \(feature)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 32)
            }
            
            if dependency.status == .missing {
                Button(showDetails ? "Hide Details" : "Show Details") {
                    showDetails.toggle()
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

private struct InstallationInstructionsView: View {
    let dependencies: [DependencyInfo]
    let checker: DependencyChecker
    @Environment(\.dismiss) private var dismiss
    @State private var homebrewInstalled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Installation Instructions")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !homebrewInstalled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Install Homebrew First")
                                .font(.headline)
                            Text("Homebrew is the recommended way to install dependencies on macOS.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    ForEach(dependencies) { dependency in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dependency.name)
                                .font(.headline)
                            
                            Text(dependency.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Installation:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("Open Terminal and run:")
                                    .font(.caption)
                                
                                Text(dependency.installCommand)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                                    .textSelection(.enabled)
                                
                                if let url = dependency.installURL {
                                    Link("Or download from: \(url)", destination: URL(string: url)!)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .task {
            homebrewInstalled = await checker.isHomebrewInstalled()
        }
    }
}

