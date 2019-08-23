import ReactiveSwift

extension SignalProducer {
    /// Everytime a value is received, the `generating` closure is executed with the option to pass along the value, modify it, or do anything else with the result generator.
    ///
    /// Errors and interruptions are forwarded inmediately. Completion events from the receiving producer are  ignored.
    /// - attention: Be sure to send a complete event with the closure generator, or the signal won't finish.
    internal func remake<NewValue>(generating: @escaping (_ received: Value, _ generator: Signal<NewValue,Error>.Observer, _ lifetime: Lifetime)->Void) -> SignalProducer<NewValue,Error> {
        return .init { [source = self] (resultGenerator, resultLifetime) in
            resultLifetime += source.start { (event) in
                switch event {
                case .value(let v):  return generating(v, resultGenerator, resultLifetime)
                case .completed:     return
                case .failed(let e): return resultGenerator.send(error: e)
                case .interrupted:   return resultGenerator.sendInterrupted()
                }
            }
        }
    }
    
    /// Everytime a value is received, the `generating` closure is executed with the option to pass along the value, modify it, or do anything else with the result generator.
    ///
    /// Errors and interruptions are forwarded inmediately. Completion events from the receiving producer are  ignored.
    /// - attention: Be sure to send a complete event with the closure generator, or the signal won't finish.
    internal func remake<NewValue,NewError>(error: @escaping (Error)->NewError, generating: @escaping (_ received: Value, _ generator: Signal<NewValue,NewError>.Observer, _ lifetime: Lifetime)->Void) -> SignalProducer<NewValue,NewError> {
        return .init { [source = self] (resultGenerator, resultLifetime) in
            resultLifetime += source.start { (event) in
                switch event {
                case .value(let v):  return generating(v, resultGenerator, resultLifetime)
                case .completed:     return
                case .failed(let e): return resultGenerator.send(error: error(e))
                case .interrupted:   return resultGenerator.sendInterrupted()
                }
            }
        }
    }
}

extension SignalProducer {
    /// `shouldIgnore` gets executed for every value received and when it returns `true`, the value is not forwarded.
    /// - parameter shouldIgnore: Closure indicating whether the received value should be ignore.
    internal func ignore(_ shouldIgnore: @escaping(_ received: Value)->Bool) -> SignalProducer<Value,Error> {
        return .init { [source = self] (resultGenerator, resultLifetime) in
            resultLifetime += source.start { (event) in
                if case .value(let v) = event, shouldIgnore(v) { return }
                resultGenerator.send(event)
            }
        }
    }
}
