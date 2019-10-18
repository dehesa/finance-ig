import IG
import Foundation

struct Configuration {
    /// The folder path for the running command-line app.
    let runURL: URL
    /// The address for the API rootURL.
    let serverURL: URL
    /// The url for the database where the info will be stored.
    let databaseURL: URL?
    
    /// The API development key used for identification on the IG platform.
    let apiKey: IG.API.Key
    /// The user credentials.
    let user: IG.API.User
}

extension Configuration: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        Command-Line configuration:
            run path: \(self.runURL.path)
            server URL: \(self.serverURL.absoluteString)
            database: \(self.databaseURL?.path ?? "in-memory")
            API key: \(self.apiKey)
            username: \(self.user.name)
        """
    }
}
