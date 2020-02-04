import Foundation

extension Bundle {
    /// Basic information for IG framework.
    public enum IG {
        /// The framework name.
        public static var name: String { String(cString: IGBundle.name) }
        /// The reverse domain identifier for the framework.
        public static var identifier: String { String(cString: IGBundle.identifier) }
        /// The 3 version number (major, minor, bug).
        public static var version: String { String(cString: IGBundle.version) }
        /// The version build number.
        public static var build: UInt { UInt(IGBundle.build) }
    }
}
