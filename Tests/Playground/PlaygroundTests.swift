@testable import IG
import ReactiveSwift
import SQLite3
import XCTest

final class PlaygroundTests: XCTestCase {
    func testPlay() {
        let url: URL =  URL(string: "https://www.meneame.net")!
        print(url)
    }
}

// e.g. API Error (Invalid HTTP response)
// e.g. |-- Error message: Invalid trailing stop setting
// e.g. |-- Suggestions: Review the returned error and try to fix the problem
// e.g. |-- Request: POST https://api.ig.com/gateway/deal/positions/otc
// e.g. |   |-- Headers: [Server:HAProxy, Access-Control-Allow-Methods:POST, GET, PUT, DELETE, OPTIONS...]
// e.g. |-- Response: 200
// e.g. |   |-- Headers: [Server:HAProxy, Access-Control-Allow-Methods:POST, GET, PUT, DELETE, OPTIONS...]
// e.g. |   |-- Server code: Service bean method[disableApplication] failure: 404 Not Found
// e.g. |   |-- Data: { "errorCode": "Service bean method[disableApplication] failure: 404 Not Found" }
// e.g. |-- Context:
// e.g. |   |-- Stop level: 125.234
// e.g. |-- Underlying error: API error (Invalid HTTP response)
// e.g. |   |-- Error message: Invalid trailing stop setting
// e.g. |   |-- Suggestions: Review the returned error and try to fix the problem
// e.g. |   |-- Request: POST https://api.ig.com/gateway/deal/positions/otc
// e.g. |   |   |-- Headers: [Server:HAProxy, Access-Control-Allow-Methods:POST, GET, PUT, DELETE, OPTIONS...]
// e.g. |   |   |-- Server code: Service bean method[disableApplication] failure: 404 Not Found
// e.g. |   |-- Context:
// e.g. |   |   |-- Stop level: 125.234
// e.g. |   |-- Underlying error:
// e.g. |       |--
