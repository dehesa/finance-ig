import XCTest
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIActivityTests: APITestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        let components = DateComponents().set {
            $0.timeZone = TimeZone.current
            ($0.year, $0.month, $0.day) = (2019, 1, 1)
            ($0.hour, $0.minute) = (0, 0)
        }
        
        print()
        
        let date = Calendar(identifier: .gregorian).date(from: components)!
        
        var counter = 0
        let endpoint = self.api.activity.get(from: date, detailed: true, pageSize: 500).on(completed: {
            XCTAssertGreaterThan(counter, 0)
        }, value: { (activities) in
            counter += activities.count
            for activity in activities {
                guard let details = activity.details else { continue }
                let level = details.level.map { "\($0)" } ?? "nil"
                print("level: \(level)\t\t\(activity.title)")
            }
        }).on(completed: {
            print()
        })
        
        self.test("Activities (history)", endpoint, signingProcess: .oauth, timeout: 3)
    }
}
