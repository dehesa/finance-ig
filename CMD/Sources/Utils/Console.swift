import Foundation

enum Console {
    /// Represents the consoles standard error.
    struct StandardOutput: TextOutputStream {
        mutating func write(_ string: String) {
            fputs(string, stdout)
        }
    }
    
    /// Represents the consoles standard error.
    struct StandardError: TextOutputStream {
        mutating func write(_ string: String) {
            fputs(string, stderr)
        }
    }
}

extension Console {
    /// Waits for the user to input some data.
    static func read() -> String {
        let inputData = FileHandle.standardInput.availableData
        return String(decoding: inputData, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
    
    /// Prints the given `String` in the console.
    ///
    /// This function doesn't add a new line at the end of the line.
    static func print(_ string: String) {
        fputs(string, stdout)
    }
    
    /// Prints the given error in the console.
    static func print(error: Swift.Error, prefix: String? = nil) {
        var string = prefix ?? ""
        string.append(String(describing: error))
        string.append("\n")
        fputs(string, stderr)
    }
    
    /// Prints the given error in the console.
    static func print(error string: String) {
        fputs(string, stderr)
    }
}
