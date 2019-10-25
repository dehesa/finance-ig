import IG
import Foundation

final class App {
    private let runloop: RunLoop
    private let queue: DispatchQueue
    private let services: IG.Services
    private(set) var programs: [Program]
    
    init(loop: RunLoop, queue: DispatchQueue, services: IG.Services) {
        self.runloop = loop
        self.queue = queue
        self.services = services
        self.programs = .init()
    }
    
    func runMarketCache(epics: [IG.Market.Epic]) {
        guard !epics.isEmpty else { return }
        
        let program: App.MarketCache
        if let runningProgram = self.programs.first(where: { $0 is MarketCache }) {
            program = runningProgram as! MarketCache
        } else {
            program = App.MarketCache(queue: self.queue, services: self.services)
            self.programs.append(program)
        }
        program.monitor(epics: epics)
    }
}

protocol Program {
    /// Removes any temporary variables and shut down any connections.
    func shutdown()
}
