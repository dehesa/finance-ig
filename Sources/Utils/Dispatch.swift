import Foundation

/// Returns the module's bundle identifier.
internal func bundleIdentifier() -> String {
    guard let identifier = Bundle(for: IG.Services.self).bundleIdentifier else {
        fatalError("The module's bundle identifier hasn't been set")
    }
    return identifier
}
