import Foundation

extension URLSession {
    static var safeSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60.0   
        configuration.timeoutIntervalForResource = 120.0  
        
        return URLSession(configuration: configuration)
    }
}
