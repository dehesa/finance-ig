import XCTest
import ReactiveSwift
@testable import IG

final class APIPositionTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testPositionRetrieval() {
        let endpoints = self.api.positions.getAll().on(value: {
            XCTAssertFalse($0.isEmpty)
        }).call(on: self.api) { (api, positions) -> SignalProducer<API.Position,API.Error> in
            let open = positions.first!
            return api.positions.get(identifier: open.identifier)
        }
        
        self.test("Position retrieval", endpoints, signingProcess: .oauth, timeout: 2)
    }
    
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let epic: Epic = "CS.D.EURUSD.MINI.IP"
        let currency: Currency = "USD"
        let direction: API.Position.Direction = .sell
        let order: API.Position.Order = .market
        let strategy: API.Position.Order.Strategy = .execute
        let size: Double = 1
        
        let endpoints = self.api.positions.create(epic: epic, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: nil, stop: nil).on(value: {
            print($0.rawValue)
        })
//            .call(on: self.api) { (api, reference) -> SignalProducer<V,API.Error> in
//            api.confirm
//        }

//        let endpoints = self.api.createPosition(.init(marketOrder: .execute, epic: epic, currency: currency, size: size, direction: direction)).on(value: { (reference) in
//            XCTAssertFalse(reference.isEmpty)
//            storedReference = reference
//        }).call(on: self.api) { (api, reference) in
//            api.confirmation(reference: reference)
//        }.on(value: { (confirmation) in
//            XCTAssertNotNil(confirmation.acceptedResponse)
//            XCTAssertEqual(confirmation.reference, storedReference)
//            XCTAssertFalse(confirmation.identifier.isEmpty)
//        }).call(on: self.api) { (api, confirmation) -> SignalProducer<String,API.Error> in
//            let position = confirmation.acceptedResponse!
//            return api.deletePositions(.init(.byIdentifier(position.identifier), marketOrder: .execute, size: size, direction: direction.oppossite))
//        }.on(value: { (reference) in
//            XCTAssertEqual(reference, storedReference)
//        })
//
        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}

//{
//    "epic": "CS.D.EURUSD.MINI.IP",
//    "instrumentName": "EUR/USD Mini",
//    "instrumentType": "CURRENCIES",
//    "expiry": "-",
//    "high": 1.12107,
//    "low": 1.11839,
//    "percentageChange": -0.15,
//    "netChange": -0.00164,
//    "updateTime": "09:58:46",
//    "updateTimeUTC": "07:58:46",
//    "bid": 1.11924,
//    "offer": 1.1193,
//    "delayTime": 0,
//    "streamingPricesAvailable": true,
//    "marketStatus": "TRADEABLE",
//    "scalingFactor": 10000
//}

//{
//    "instrument": {
//        "epic": "CS.D.EURUSD.MINI.IP",
//        "expiry": "-",
//        "name": "EUR/USD Mini",
//        "forceOpenAllowed": true,
//        "stopsLimitsAllowed": true,
//        "lotSize": 1.0,
//        "unit": "CONTRACTS",
//        "type": "CURRENCIES",
//        "controlledRiskAllowed": true,
//        "streamingPricesAvailable": true,
//        "marketId": "EURUSD",
//        "currencies": [ {
//            "code": "USD",
//            "symbol": "$",
//            "baseExchangeRate": 1.1142,
//            "exchangeRate": 0.66,
//            "isDefault": false
//            }
//        ],
//        "sprintMarketsMinimumExpiryTime": null,
//        "sprintMarketsMaximumExpiryTime": null,
//        "marginDepositBands": [
//            {"min": 0,"max": 115,"margin": 3.33,"currency": "USD"},
//            {"min": 115,"max": 1150,"margin": 3.33,"currency": "USD"},
//            {"min": 1150,"max": 1725,"margin": 3.33,"currency": "USD"},
//            {"min": 1725,"max": null,"margin": 15,"currency": "USD"}
//        ],
//        "marginFactor": 3.3300000000000000710542735760100185871124267578125,
//        "marginFactorUnit": "PERCENTAGE",
//        "slippageFactor": {
//            "unit": "pct",
//            "value": 50.0
//        },
//        "limitedRiskPremium": {
//            "value": 1.2,
//            "unit": "POINTS"
//        },
//        "openingHours": null,
//        "expiryDetails": null,
//        "rolloverDetails": null,
//        "newsCode": "EUR=",
//        "chartCode": "EURUSD",
//        "country": null,
//        "valueOfOnePip": "1.00",
//        "onePipMeans": "0.0001 USD/EUR",
//        "contractSize": "10000",
//        "specialInfo": ["DEFAULT KNOCK OUT LEVEL DISTANCE","MIN KNOCK OUT LEVEL DISTANCE","MAX KNOCK OUT LEVEL DISTANCE"]
//    },
//    "dealingRules": {
//        "minStepDistance": {
//            "unit": "POINTS",
//            "value": 5.0
//        },
//        "minDealSize": {
//            "unit": "POINTS",
//            "value": 1.0
//        },
//        "minControlledRiskStopDistance": {
//            "unit": "POINTS",
//            "value": 5.0
//        },
//        "minNormalStopOrLimitDistance": {
//            "unit": "POINTS",
//            "value": 2.0
//        },
//        "maxStopOrLimitDistance": {
//            "unit": "PERCENTAGE",
//            "value": 75.0
//        },
//        "marketOrderPreference": "AVAILABLE_DEFAULT_OFF",
//        "trailingStopsPreference": "AVAILABLE"
//    },
//    "snapshot": {
//        "marketStatus": "TRADEABLE",
//        "netChange": -0.00099,
//        "percentageChange": -0.09,
//        "updateTime": "09:46:31",
//        "delayTime": 0,
//        "bid": 1.11417,
//        "offer": 1.11423,
//        "high": 1.11565,
//        "low": 1.11263,
//        "binaryOdds": null,
//        "decimalPlacesFactor": 5,
//        "scalingFactor": 10000,
//        "controlledRiskExtraSpread": 2
//    }
//}
