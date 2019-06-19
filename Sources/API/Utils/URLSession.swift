import Foundation

/// Completion handler called when a load request is complete.
/// - parameter data: The data returned by the server.
/// - parameter response: An object that provides response metadata, such as HTTP headers and status code. If you are making an HTTP or HTTPS request, the returned object is actually an `HTTPURLResponse` object.
/// - parameter error: An error object that indicates why the request failed, or nil if the request was successful.
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

extension URLSessionDataTask: URLMockableSessionDataTask {
    
}

extension URLSession: URLMockableSession {
    /// Data task convenience methods.
    ///
    /// These methods create tasks that bypass the normal delegate calls for response and data delivery, and provide a simple cancelable asynchronous interface to receiving data.  Errors will be returned in the NSURLErrorDomain,
    /// The delegate, if any, will still be called for authentication challenges.
    /// - seealso: Foundation.NSURLError
    public  func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskResult)  -> URLMockableSessionDataTask {
        return self.dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask
    }
}
