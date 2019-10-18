import IG
import Foundation

final class App {
    private let runloop: RunLoop
    private let queue: DispatchQueue
    private let services: IG.Services
    
    init(loop: RunLoop, queue: DispatchQueue, services: IG.Services) {
        self.runloop = loop
        self.queue = queue
        self.services = services
    }
}
