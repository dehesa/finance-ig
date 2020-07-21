import Combine

extension Publisher where Failure==Swift.Error {
    /// Converts the generic Swift error type from the upstream publisher into an `IG.Error`.
    internal func mapStreamError<F>(item: String, fields: Set<F>) -> Publishers.MapError<Self,IG.Error> where F:RawRepresentable, F.RawValue==String {
        self.mapError { (error) -> IG.Error in
            switch error {
            case let result as IG.Error:
                result.errorUserInfo["Item"] = item
                result.errorUserInfo["Fields"] = fields
                return result
            case let underlyingError:
                return IG.Error(.streamer(.invalidResponse), "Unable to parse response.", help: "Review the error and contact the repo maintainer.", underlying: underlyingError, info: ["Item": item, "Fields": fields])
            }
        }
    }
}
