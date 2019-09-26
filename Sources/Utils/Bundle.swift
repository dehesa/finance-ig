import Foundation

/// Basic information for IG framework.
public enum Bundle {
    /// The framework name.
    static var name: String { String(cString: IGFramework.name) }
    /// The reverse domain identifier for the framework.
    static var identifier: String { String(cString: IGFramework.identifier) }
    /// The 3 version number (major, minor, bug).
    static var version: String { String(cString: IGFramework.version) }
    /// The version build number.
    static var build: UInt { UInt(IGFramework.build) }
}
