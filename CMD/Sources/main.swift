import IG
import Foundation

// As an example, lets stream and monitor the following markets:
let epics: [IG.Market.Epic] = [
    "CS.D.USDCAD.MINI.IP", "CS.D.GBPUSD.MINI.IP", "CS.D.EURUSD.MINI.IP", "CS.D.USDCHF.MINI.IP", "CS.D.USDJPY.MINI.IP", "CS.D.AUDUSD.MINI.IP", "CS.D.NZDUSD.MINI.IP",
    "CS.D.GBPCAD.MINI.IP", "CS.D.EURCAD.MINI.IP", "CS.D.CADCHF.MINI.IP", "CS.D.CADJPY.MINI.IP", "CS.D.AUDCAD.MINI.IP", "CS.D.NZDCAD.MINI.IP",
    "CS.D.GBPEUR.MINI.IP", "CS.D.GBPCHF.MINI.IP", "CS.D.GBPJPY.MINI.IP", "CS.D.AUDGBP.MINI.IP", "CS.D.NZDGBP.MINI.IP",
    "CS.D.EURCHF.MINI.IP", "CS.D.EURJPY.MINI.IP", "CS.D.EURAUD.MINI.IP", "CS.D.EURNZD.MINI.IP",
    "CS.D.CHFJPY.MINI.IP", "CS.D.AUDCHF.MINI.IP", "CS.D.NZDCHF.MINI.IP",
    "CS.D.AUDJPY.MINI.IP", "CS.D.NZDJPY.MINI.IP",
    "CS.D.AUDNZD.MINI.IP",
]

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

Services.make(serverURL: config.serverURL, databaseURL: config.databaseURL, key: config.apiKey, user: config.user).result {
    switch $0 {
    case .success(let services):
        app = App(loop: runloop, queue: .main, services: services)
        return app!.runMarketCache(epics: epics)
    case .failure(let error):
        Console.print(error: error)
    case nil:
        Console.print(error: "An unknown error occurred while initializing the platform services")
    }
    exit(EXIT_FAILURE)
}

runloop.run()

app = nil
exit(EXIT_SUCCESS)
