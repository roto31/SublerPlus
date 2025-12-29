import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .accessibilityLabel("SublerPlus application icon")
            } else {
                Image(systemName: "app.badge")
                    .font(.system(size: 128))
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("SublerPlus application icon")
            }
            
            // App Name
            Text(appName)
                .font(.system(size: 24, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            
            // Version
            Text("Version \(appVersion)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // Copyright
            Text(copyright)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
                .padding(.horizontal)
            
            // Credits/Acknowledgments
            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Built on Subler by Damiano Galassi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Metadata providers: TMDB, TVDB, TPDB, OpenSubtitles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Spacer()
            
            // Close button
            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Close About window")
        }
        .padding(30)
        .frame(width: 400, height: 500)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About SublerPlus")
    }
    
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SublerPlus"
    }
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if version == build {
            return version
        }
        return "\(version) (\(build))"
    }
    
    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? 
        "Copyright © 2025"
    }
}

#Preview {
    AboutView()
}

