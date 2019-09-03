import GRDB
import ReactiveSwift
import Foundation

extension SignalProducer where Value==IG.DB.Request.Wrapper<Void>, Error==IG.DB.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed DB session has expired.
    /// - attention: This initializer creates a weak bond with the  DB instance passed as argument. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter db: The DB session where the actual database request will be performed.
    /// - Returns: The DB instance and completes inmediately.
    internal init(database: IG.DB) {
        self.init { [weak database] (input, _) in
            guard let database = database else {
                return input.send(error: .sessionExpired())
            }
            
            input.send(value: (database, ()))
            input.sendCompleted()
        }
    }
}

extension SignalProducer where Error==IG.DB.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed API session has expired. It will also execute the `validating` closure and pass those values to the following step.
    /// - attention: This function makes a weak bond with the receiving API instance. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter api: The API session where API calls will be performed.
    /// - parameter validating: Closure validating some values that will pass with the signal event to the following step.
    internal init<T>(database: IG.DB, validating: @escaping IG.DB.Request.Generator.Validation<T>) where Value==IG.DB.Request.Wrapper<T> {
        self.init { [weak database] (input, _) in
            guard let database = database else {
                return input.send(error: .sessionExpired())
            }
            
            let values: T
            do {
                values = try validating(database)
            } catch let error as Self.Error {
                return input.send(error: error)
            } catch let underlyingError {
                let error: Self.Error = .invalidRequest("The request validation failed.", underlying: underlyingError, suggestion: Self.Error.Suggestion.readDocumentation)
                return input.send(error: error)
            }
            
            input.send(value: (database, values))
            input.sendCompleted()
        }
    }
    
    /// Sends one or several read commands to the database grouped in a transaction. The results are then returned as a value.
    /// - parameter interaction: Closure were the read database commands are specified.
    internal func read<T,R>(_ interaction: @escaping IG.DB.Request.Generator.Interaction<T,R>) -> SignalProducer<R,Self.Error> where Value==IG.DB.Request.Wrapper<T> {
        return self.remake { (input, generator, lifetime) in
            /// This value turns to `.stop` when the hosting signal has been disposed.
            var permission: IG.DB.Response.Iteration = .continue
            /// This detacher holds the disposable to stop observing the hosting signal lifetime.
            let detacher = lifetime.observeEnded {
                permission = .stop
            }
            
            input.database.channel.asyncRead { (result) in
                do {
                    let db = try result.get()
                    let values = try interaction(db, input.values) { permission }
                    
                    generator.send(value: values)
                    generator.sendCompleted()
                } catch let error as Self.Error {
                    generator.send(error: error)
                } catch let error {
                    var result: Self.Error = .callFailed("An asynchronous database read failed.", underlying: error, suggestion: Self.Error.Suggestion.reviewError)
                    result.context.append(("Input values", input.values))
                    generator.send(error: result)
                }
                
                // Triggering `detacher` removes the signal lifetime observation.
                detacher?.dispose()
            }
        }
    }
    
    /// Sends one or several read commands to the database grouped in a transaction. The results are then returned as a stream of values.
    /// - parameter interaction: Closure were the read database commands are specified. When the closure returns, the signal completes.
    /// - important: Liberate the receiving `DispatchQueue` as soon as possible.
    internal func readContinuously<T,R>(_ interaction: @escaping IG.DB.Request.Generator.ContinuousInteraction<T,R>) -> SignalProducer<R,Self.Error> where Value==IG.DB.Request.Wrapper<T> {
        return self.remake { (input, generator, lifetime) in
            /// This value turns to `.stop` when the hosting signal has been disposed.
            var permission: IG.DB.Response.Iteration = .continue
            /// This detacher holds the disposable to stop observing the hosting signal lifetime.
            let detacher = lifetime.observeEnded {
                permission = .stop
            }

            input.database.channel.asyncRead { (result) in
                do {
                    let db = try result.get()
                    let shallContinue = { permission }
                    try interaction(db, input.values, shallContinue) { (values: R) in
                        generator.send(value: values)
                        return shallContinue()
                    }
                    
                    generator.sendCompleted()
                } catch let error as Self.Error {
                    generator.send(error: error)
                } catch let error {
                    var result: Self.Error = .callFailed("An asynchronous database read failed.", underlying: error, suggestion: Self.Error.Suggestion.reviewError)
                    result.context.append(("Input values", input.values))
                    generator.send(error: result)
                }
                
                // Triggering `detacher` removes the signal lifetime observation.
                detacher?.dispose()
            }
        }
    }
    
    /// Sends one or several read/write commands to the database grouped in a transaction. The results are then returned as a value.
    /// - parameter interaction: Closure were the read/write database commands are specified.
    internal func write<T,R>(_ interaction: @escaping IG.DB.Request.Generator.Interaction<T,R>) -> SignalProducer<R,Self.Error> where Value==IG.DB.Request.Wrapper<T> {
        return self.remake { (input, generator, lifetime) in
            /// This value turns to `.stop` when the hosting signal has been disposed.
            var permission: IG.DB.Response.Iteration = .continue
            /// This detacher holds the disposable to stop observing the hosting signal lifetime.
            let detacher = lifetime.observeEnded {
                permission = .stop
            }
            
            input.database.channel.asyncWrite({ (db) -> R in
                try interaction(db, input.values) { permission }
            }) { (db, result) in
                // Triggering `detacher` removes the signal lifetime observation.
                detacher?.dispose()
                
                switch result {
                case .success(let value):
                    generator.send(value: value)
                    generator.sendCompleted()
                case .failure(let error):
                    if let error = error as? Self.Error {
                        generator.send(error: error)
                    } else {
                        var result: Self.Error = .callFailed("An asynchronous database write failed.", underlying: error, suggestion: Self.Error.Suggestion.reviewError)
                        result.context.append(("Input values", input.values))
                        generator.send(error: result)
                    }
                }
            }
            
        }
    }
}
