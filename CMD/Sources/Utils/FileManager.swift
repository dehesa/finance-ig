import Foundation

extension FileManager {
    /// Parses a file path into a proper file URL.
    /// - parameter filePath: A `String` value representing a file URL (relative or absolute).
    func parse(filePath: String, relativeTo basePath: String? = nil) -> URL {
        let url: URL
        
        if filePath.hasPrefix("~") {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            
            var relativePath = filePath.dropFirst()
            guard !relativePath.isEmpty else { return homeURL }
            
            if relativePath.hasPrefix("/") { relativePath = relativePath.dropFirst() }
            url = .init(fileURLWithPath: .init(relativePath), relativeTo: homeURL)
        } else if filePath.hasPrefix("/") {
            url = .init(fileURLWithPath: filePath)
        } else {
            let rootPath = basePath ?? self.currentDirectoryPath
            url = .init(fileURLWithPath: filePath, relativeTo: .init(fileURLWithPath: rootPath))
        }
        
        return url.standardizedFileURL
    }
}
