import Foundation

/// Basic information for IG framework.
public enum Bundle {
    /// The framework name.
    public static var name: String { String(cString: IGFramework.name) }
    /// The reverse domain identifier for the framework.
    public static var identifier: String { String(cString: IGFramework.identifier) }
    /// The 3 version number (major, minor, bug).
    public static var version: String { String(cString: IGFramework.version) }
    /// The version build number.
    public static var build: UInt { UInt(IGFramework.build) }
}
