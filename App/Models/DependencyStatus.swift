import Foundation

public enum DependencyStatus: String, Codable, Sendable {
    case installed = "installed"      // Green dot - installed and up-to-date
    case outdated = "outdated"        // Yellow dot - installed but not current version
    case missing = "missing"          // Red dot - not installed
}

public struct DependencyInfo: Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let installCommand: String
    public let installURL: String?
    public let versionCommand: [String]
    public let versionPattern: String?
    public let requiredFeatures: [String]
    public var status: DependencyStatus
    public var installedVersion: String?
    public var requiredVersion: String?
    
    public init(
        id: String,
        name: String,
        description: String,
        installCommand: String,
        installURL: String? = nil,
        versionCommand: [String],
        versionPattern: String? = nil,
        requiredFeatures: [String],
        status: DependencyStatus = .missing,
        installedVersion: String? = nil,
        requiredVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.installCommand = installCommand
        self.installURL = installURL
        self.versionCommand = versionCommand
        self.versionPattern = versionPattern
        self.requiredFeatures = requiredFeatures
        self.status = status
        self.installedVersion = installedVersion
        self.requiredVersion = requiredVersion
    }
}

public struct DependencyCheckResult: Sendable {
    public let dependencies: [DependencyInfo]
    public let allInstalled: Bool
    public let missingCount: Int
    public let outdatedCount: Int
    
    public init(dependencies: [DependencyInfo]) {
        self.dependencies = dependencies
        self.missingCount = dependencies.filter { $0.status == .missing }.count
        self.outdatedCount = dependencies.filter { $0.status == .outdated }.count
        self.allInstalled = missingCount == 0 && outdatedCount == 0
    }
}

