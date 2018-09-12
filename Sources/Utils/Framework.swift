import Foundation

/// List of framework related functionality.
public class Framework {
    /// This class shan't be initialized.
    private init() { fatalError() }
    
    /// The framework product identifier.
    public static let identifier = Bundle(for: Framework.self).bundleIdentifier!
}
