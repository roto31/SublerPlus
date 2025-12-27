import Foundation
import SwiftUI

@MainActor
public final class DependencyManager: ObservableObject {
    @Published public var showDependencyCheck = false
    @Published public var hasCheckedDependencies = false
    @Published public var dependencyStatus: DependencyCheckResult?
    
    private let defaults = UserDefaults.standard
    private let hasCheckedKey = "SublerPlus.HasCheckedDependencies"
    private let lastCheckKey = "SublerPlus.LastDependencyCheck"
    
    public init() {
        hasCheckedDependencies = defaults.bool(forKey: hasCheckedKey)
        loadLastCheck()
    }
    
    public func checkIfNeeded() {
        // Check on first launch or if it's been more than 7 days since last check
        let shouldCheck = !hasCheckedDependencies || shouldRecheck()
        
        if shouldCheck {
            Task {
                await performCheck()
            }
        }
    }
    
    private func shouldRecheck() -> Bool {
        guard let lastCheck = defaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        let daysSinceCheck = Calendar.current.dateComponents([.day], from: lastCheck, to: Date()).day ?? 0
        return daysSinceCheck >= 7
    }
    
    private func performCheck() async {
        let checker = DependencyChecker.shared
        let result = await checker.checkAllDependencies()
        dependencyStatus = result
        
        // Show dialog if dependencies are missing or outdated
        if !result.allInstalled {
            showDependencyCheck = true
        } else {
            // All good, just mark as checked
            hasCheckedDependencies = true
            defaults.set(true, forKey: hasCheckedKey)
            defaults.set(Date(), forKey: lastCheckKey)
        }
    }
    
    public func markAsChecked() {
        hasCheckedDependencies = true
        defaults.set(true, forKey: hasCheckedKey)
        defaults.set(Date(), forKey: lastCheckKey)
    }
    
    private func loadLastCheck() {
        // Load last check date if available
    }
    
    public func refreshCheck() async {
        await performCheck()
    }
}

