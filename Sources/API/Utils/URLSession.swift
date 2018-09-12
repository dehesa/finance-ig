import Foundation

public typealias DataTaskResult = (Data?, URLResponse?, Error?) -> Swift.Void

/// Protocol for the URL API session, allowing it to be mocked from the test framework.
internal protocol URLMockableSession: class {
    /// Cancels all outstanding tasks and then invalidates the session.
    func invalidateAndCancel()
    /// Creates a task that retrieves the contents of a URL based on the specified URL request object, and calls a handler upon completion.
    func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskResult)  -> URLMockableSessionDataTask
}

/// Procotol for the response of a URL Session data taks, allowing it to be mocked from the test framework.
public protocol URLMockableSessionDataTask: class {
    /// Resume the task.
    func resume()
    /// Suspend the task.
    func suspend()
    /// Returns immediately, but marks a task as being canceled.
    func cancel()
}

extension URLSessionDataTask: URLMockableSessionDataTask {}
extension URLSession: URLMockableSession {
    public  func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskResult)  -> URLMockableSessionDataTask {
        return self.dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask
    }
}
