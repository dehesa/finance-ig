import IG
import Combine
import Foundation

/// Holds the configurations for this terminal run.
let config: Configuration
do {
    config = try Arguments.parse(path: CommandLine.arguments[0], arguments: .init(CommandLine.arguments.dropFirst()))
} catch let error {
    Console.print(error: error)
    exit(EXIT_FAILURE)
}

Console.print("""
Configuration:
\tdatabase: \(config.databaseURL?.path ?? "in-memory")
\tserver: \(config.serverURL)
\tapi key: \(config.apiKey)
\tusername: \(config.user.name)
\n
""")

/// The runloop handling the API, Streamer, and DB events.
let runloop = RunLoop.current
var app: App! = nil

var cancellable: AnyCancellable? = nil
cancellable = Services.make(serverURL: config.serverURL, databaseURL: config.databaseURL, key: config.apiKey, user: config.user).result {
    guard case .success(let services) = $0 else {
        Console.print(error: "There was an error initializing the IG services")
        exit(EXIT_FAILURE)
    }
    
    cancellable = nil
    app = App(loop: runloop, queue: .main, services: services)
    app.run(monitorEpics: App.defaultEpics)
}

runloop.run()
