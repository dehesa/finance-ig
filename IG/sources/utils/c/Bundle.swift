import Foundation

extension Bundle {
    /// Basic information for IG framework.
    public enum IG {
        /// The framework name.
        @_transparent public static var name: String { String(cString: IGBundle.name) }
        /// The reverse domain identifier for the framework.
        @_transparent public static var identifier: String { String(cString: IGBundle.identifier) }
        /// The 3 version number (major, minor, bug).
        @_transparent public static var version: String { String(cString: IGBundle.version) }
        /// The version build number.
        @_transparent public static var build: UInt { UInt(IGBundle.build) }
    }
}
