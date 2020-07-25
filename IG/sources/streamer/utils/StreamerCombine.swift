import Combine

extension Publisher where Failure==Swift.Error {
    /// Converts the generic Swift error type from the upstream publisher into an `IG.Error`.
    internal func mapStreamError<F>(item: String, fields: Set<F>) -> Publishers.MapError<Self,IG.Error> where F:RawRepresentable, F.RawValue==String {
        self.mapError {
            switch $0 {
            case let error as IG.Error:
                error.errorUserInfo["Item"] = item
                error.errorUserInfo["Fields"] = fields
                return error
            case let error:
                return IG.Error._unableToDecode(item: item, fields: fields, error: error)
            }
        }
    }
}

private extension IG.Error {
    /// Error raised when the response cannot be decoded.
    static func _unableToDecode(item: String, fields: Any, error: Swift.Error) -> Self {
        Self(.streamer(.invalidResponse), "Unable to parse response.", help: "Review the error and contact the repo maintainer.", underlying: error, info: ["Item": item, "Fields": fields])
    }
}
