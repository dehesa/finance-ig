import Foundation
import IG

/// Holds the configurations for this terminal run.
let config: Configuration
do {
    config = try Arguments.parse(path: CommandLine.arguments[0], arguments: .init(CommandLine.arguments.dropFirst()))
} catch let error {
    Console.print(error: error)
    exit(EXIT_FAILURE)
}

print(config)

/// The runloop handling the API, Streamer, and DB events.
let runloop = RunLoop.current
var app: App? = nil

//Services.make(serverURL: config.serverURL, databaseURL: config.databaseURL, key: config.apiKey, user: config.user).result {
//    switch $0 {
//    case .success(let services):
//        app = App(loop: runloop, queue: .main, services: services)
//    case .failure(let error):
//        Console.print(error: error)
//    case nil:
//        Console.print(error: "An unknown error occurred while initializing the platform services")
//    }
//    exit(EXIT_FAILURE)
//}

//runloop.run()

app = nil
exit(EXIT_SUCCESS)
