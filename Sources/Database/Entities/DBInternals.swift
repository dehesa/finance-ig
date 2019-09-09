import Foundation

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
    public enum Request {}
    /// Domain namespace retaining anything related to DB responses.
    public enum Response {}
}

// MARK: - Request types

extension IG.DB.Request {
    /// Request values that have been verified/validated.
    internal typealias Wrapper<T> = (database: IG.DB, values: T)
    
    /// List of typealias representing closures which generate a specific data type.
    internal enum Generator {
        /// Closure receiving a valid DB session and returning validated values.
        /// - parameter db: The DB instance from where credentials an other temporal priviledge information is being retrieved.
        /// - returns: The validated values.
        typealias Validation<T> = (_ database: IG.DB) throws -> T
        /// This closure receives a valid low-level database session, validated values to use on the database requests, and a function to query "from-time-to-time" whether the database interaction should continue or it should be stop as soon as possible.
        /// - parameter db: Low-level database session.
        /// - parameter values: Values that have been validated in a previous step.
        /// - parameter shallContinue: Small closure, that everytime is called returns a Boolean indicating whether you can continue fetching the database (`.continue`) or you should stop immediately (`.stop`).
        /// - returns: The result of the database interaction.
        typealias Interaction<T,R> = (_ database: IG.DB, _ values: T, _ shallContinue: ()->IG.DB.Response.Iteration) throws -> R
        /// This closure receives a valid low-level database session, validated values to use on the database requests, and a function to query "from-time-to-time" whether the database interaction should continue or it should be stop as soon as possible.
        /// - parameter db: Low-level database session.
        /// - parameter values: Values that have been validated in a previous step.
        /// - parameter shallContinue: Small closure, that everytime is called returns a Boolean indicating whether you can continue fetching the database (`.continue`) or you should stop immediately (`.stop`).
        /// - parameter continuousResult: This closure is called everytime you want to communicate further steps about intermediate results. As a convenience, it returns the value of `shallContinue` after sending values.
        /// - returns: The result of the database interaction.
        typealias ContinuousInteraction<T,R> = (_ database: IG.DB, _ values: T, _ shallContinue: ()->IG.DB.Response.Iteration, _ continuousResult: (R) -> IG.DB.Response.Iteration) throws -> Void
    }
}

// MARK: - Response types

extension IG.DB.Response {
    /// Indication of whether an operation should continue or stop.
    internal enum Iteration: Equatable {
        /// The operation shall continue.
        case `continue`
        /// The operation shall stop as soon as possible.
        case stop
    }
}
