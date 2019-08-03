import ReactiveSwift

extension Signal.Event where Error == Never {
    /// Transforms an event without errors in one with errors.
    internal func promoteError<E:Swift.Error>(_: E.Type) -> Signal<Value,E>.Event {
        switch self {
        case let .value(v): return .value(v)
        case .completed:    return .completed
        case .interrupted:  return .interrupted
        case .failed:       fatalError("Never is impossible to construct")
        }
    }
}
