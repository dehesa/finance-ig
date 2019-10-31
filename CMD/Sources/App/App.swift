import IG
import Foundation

/// Describes one of the programs within an app.
protocol Program {
    /// Removes any temporary variables and shut down any oingoing connection.
    func reset()
}

final class App {
    /// The command-line application run loop.
    private let runloop: RunLoop
    /// The command-line main dispatch queue.
    private let queue: DispatchQueue
    /// The IG services in charge of retrieving/emitting all information.
    private let services: IG.Services
    /// App programs being run at the moment.
    private(set) var programs: [Program]
    
    /// Designated initializer setting all properties to its default.
    init(loop: RunLoop, queue: DispatchQueue, services: IG.Services) {
        self.runloop = loop
        self.queue = queue
        self.services = services
        self.programs = .init()
    }
    
    /// Convenience function running a targeted set of programs.
    /// - epics: The market identifiers to be monitored.
    func run(monitorEpics epics: Set<IG.Market.Epic>) {
        self.updatePrices(epics: epics) { [unowned self] (result) in
            guard case .success = result else { return }
            Console.print("Success updating prices")
            self.subscribe(epics: epics)
        }
    }
}

extension App {
    /// Epics referencing the major Forex markets.
    static var defaultEpics: Set<IG.Market.Epic> = [
        "CS.D.USDCAD.MINI.IP", "CS.D.GBPUSD.MINI.IP", "CS.D.EURUSD.MINI.IP", "CS.D.USDCHF.MINI.IP", "CS.D.USDJPY.MINI.IP", "CS.D.AUDUSD.MINI.IP", "CS.D.NZDUSD.MINI.IP",
        "CS.D.GBPCAD.MINI.IP", "CS.D.EURCAD.MINI.IP", "CS.D.CADCHF.MINI.IP", "CS.D.CADJPY.MINI.IP", "CS.D.AUDCAD.MINI.IP", "CS.D.NZDCAD.MINI.IP",
        "CS.D.GBPEUR.MINI.IP", "CS.D.GBPCHF.MINI.IP", "CS.D.GBPJPY.MINI.IP", "CS.D.AUDGBP.MINI.IP", "CS.D.NZDGBP.MINI.IP",
        "CS.D.EURCHF.MINI.IP", "CS.D.EURJPY.MINI.IP", "CS.D.EURAUD.MINI.IP", "CS.D.EURNZD.MINI.IP",
        "CS.D.CHFJPY.MINI.IP", "CS.D.AUDCHF.MINI.IP", "CS.D.NZDCHF.MINI.IP",
        "CS.D.AUDJPY.MINI.IP", "CS.D.NZDJPY.MINI.IP",
        "CS.D.AUDNZD.MINI.IP",
    ]
    
    /// Refreshes the price information of the the given markets.
    func updatePrices(epics: Set<IG.Market.Epic>, handler: @escaping (Result<Void,Swift.Error>)->Void) {
        guard !epics.isEmpty else { return }
        
        Console.print("Updating \(epics.count) markets. Input scrapped credentials:\n")
        var cst = String()
        while true {
            Console.print("\tCertificate: ")
            cst = Console.read()
            guard cst.isEmpty else { break }
        }
        
        var securityHeader = String()
        while true {
            Console.print("\tSecurity: ")
            securityHeader = Console.read()
            guard securityHeader.isEmpty else { break }
        }
        
        let program = App.BatchUpdate(queue: self.queue, services: self.services)
        guard case .none = self.programs.first(where: { $0 is App.BatchUpdate }) else {
            return Console.print("Bach update failed! There is already an ongoing update operation. Please wait and retry.")
        }
        self.programs.append(program)
        
        program.update(epics: epics, scrappedCredentials: (cst, securityHeader)) { [unowned self] (result) in
            if let index = self.programs.firstIndex(where: { $0 is App.BatchUpdate }) {
                self.programs.remove(at: index)
            }
            
            handler(result)
        }
    }
    
    /// Runs a program which subscribe (via the lightstreamer protocol) to the given markets.
    func subscribe(epics: Set<IG.Market.Epic>) {
        guard !epics.isEmpty else { return }
        
        let program: App.Subscription
        if let runningProgram = self.programs.first(where: { $0 is App.Subscription }) {
            program = runningProgram as! Subscription
        } else {
            program = App.Subscription(queue: self.queue, services: self.services)
            self.programs.append(program)
        }
        program.monitor(epics: epics)
    }
}
