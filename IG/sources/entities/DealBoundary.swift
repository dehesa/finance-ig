import Decimals

extension Deal {
    /// The limit at which the user is taking profit.
    public enum Boundary: Hashable {
        /// Specifies the limit as a given absolute level.
        case level(Decimal64)
        /// Relative limit over an undisclosed reference level.
        /// - parameter _: The relative value where the limit will be set.
        case distance(Decimal64)
    }
    
    /// The level/price at which the user doesn't want to incur more lose.
    public enum Stop {}
}

extension Deal.Stop {
    /// Defines the amount of risk being exposed while closing the stop loss.
    public enum Risk: Hashable {
        /// An exposed (or non-guaranteed) stop may expose the trade to slippage when exiting it.
        case exposed
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        case limited
    }

    /// Defines the amount of risk being exposed while closing the stop loss.
    public enum RiskData: Hashable {
        /// An exposed (or non-guaranteed) stop may expose the trade to slippage when exiting it.
        case exposed
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        /// - parameter premium: The number of pips that are being charged for your limited risk (i.e. guaranteed stop).
        case limited(premium: Decimal64)
    }
    
    /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
    public enum Trailing {
        /// A static (non-movable) stop.
        case `static`
        /// A dynamic (trailing) stop.
        /// - parameter distance: The distance from the  market price.
        /// - parameter increment: The stop level increment step in pips.
        case `dynamic`
    }
    
    /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
    public enum TrailingData {
        /// A static (non-movable) stop.
        case `static`
        /// A dynamic (trailing) stop.
        /// - parameter distance: The distance from the  market price.
        /// - parameter increment: The stop level increment step in pips.
        case `dynamic`(distance: Decimal64, increment: Decimal64)
    }
}
