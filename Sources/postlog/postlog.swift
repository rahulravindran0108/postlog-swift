import Foundation

/// A lightweight analytics library for SwiftUI applications
/// that sends events to Postlog analytics backend
public class PostlogAnalytics {
    // MARK: - Properties
    
    /// The shared instance for the analytics client
    public static let shared = PostlogAnalytics()
    
    /// Base URL for API requests
    private let baseURL = "https://api.postlog.app/v1"
    
    /// Authentication token for API requests
    private var token: String?
    
    /// Internal queue for processing analytics events
    private let queue = DispatchQueue(label: "com.postlog.analytics", qos: .utility)
    
    /// Completion queue for callbacks (defaults to main)
    private let completionQueue = DispatchQueue.main
    
    /// Internal operation queue for managing network requests
    private let operationQueue: OperationQueue
    
    /// Session configuration
    private let session: URLSession
    
    /// Flag to enable debug logging
    public var debugLoggingEnabled = false
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .utility
        
        session = URLSession(configuration: config)
    }
    
    /// Initializer with custom URL session for testing
    internal init(session: URLSession) {
        self.session = session
        
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .utility
    }
    
    // MARK: - Public Methods
    
    /// Initialize the analytics client with an API token
    /// - Parameter token: Your Postlog API token
    /// - Parameter completion: Optional completion handler called when initialization is complete
    public func initialize(token: String, completion: ((Error?) -> Void)? = nil) {
        self.token = token
        debugLog("Postlog Analytics initialized with token")
        
        // Call completion handler if provided
        if let completion = completion {
            completionQueue.async {
                completion(nil)
            }
        }
    }
    
    /// Identify a user with custom properties
    /// - Parameters:
    ///   - userId: The unique identifier for the user
    ///   - project: The project name
    ///   - properties: A dictionary of user properties (values must be String, Int, Double, or Bool)
    ///   - completion: Optional completion handler (called on main thread)
    public func identify(
        userId: String,
        project: String,
        properties: [String: Any],
        completion: ((Error?) -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Verify the token is set
            guard let token = self.token else {
                self.debugLog("Error: Analytics not initialized with token")
                self.handleCompletion(PostlogError.notInitialized, completion: completion)
                return
            }
            
            // Validate properties
            guard self.validateProperties(properties) else {
                self.debugLog("Error: Invalid property types in identify call")
                self.handleCompletion(PostlogError.invalidProperties, completion: completion)
                return
            }
            
            // Create the identification payload
            let payload: [String: Any] = [
                "user_id": userId,
                "project": project,
                "properties": properties
            ]
            
            // Send the request
            self.sendRequest(endpoint: "/user/identify", payload: payload, token: token, completion: completion)
        }
    }
    
    /// Track an event
    /// - Parameters:
    ///   - name: The name of the event
    ///   - channel: The channel for the event
    ///   - project: The project name
    ///   - userId: The unique identifier for the user
    ///   - icon: An emoji icon for the event
    ///   - description: A description of the event
    ///   - tags: Additional tags for the event (values must be String, Int, Double, or Bool)
    ///   - completion: Optional completion handler (called on main thread)
    public func track(
        name: String,
        channel: String,
        project: String,
        userId: String,
        icon: String = "",
        description: String = "",
        tags: [String: Any] = [:],
        completion: ((Error?) -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Verify the token is set
            guard let token = self.token else {
                self.debugLog("Error: Analytics not initialized with token")
                self.handleCompletion(PostlogError.notInitialized, completion: completion)
                return
            }
            
            // Validate tags
            guard self.validateProperties(tags) else {
                self.debugLog("Error: Invalid tag types in track call")
                self.handleCompletion(PostlogError.invalidProperties, completion: completion)
                return
            }
            
            // Create the event payload
            let payload: [String: Any] = [
                "name": name,
                "channel": channel,
                "project": project,
                "user_id": userId,
                "icon": icon,
                "description": description,
                "tags": tags,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            
            // Send the request
            self.sendRequest(endpoint: "/log", payload: payload, token: token, completion: completion)
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates that properties only contain allowed value types
    /// - Parameter properties: The properties to validate
    /// - Returns: Whether the properties are valid
    private func validateProperties(_ properties: [String: Any]) -> Bool {
        for (_, value) in properties {
            if !(value is String || value is Int || value is Double || value is Bool) {
                return false
            }
        }
        return true
    }
    
    /// Sends a request to the Postlog API
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - payload: The request payload
    ///   - token: The authentication token
    ///   - completion: Optional completion handler
    private func sendRequest(
        endpoint: String,
        payload: [String: Any],
        token: String,
        completion: ((Error?) -> Void)?
    ) {
        // Create the URL
        guard let url = URL(string: baseURL + endpoint) else {
            debugLog("Error: Invalid URL for endpoint \(endpoint)")
            handleCompletion(PostlogError.invalidURL, completion: completion)
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Serialize the payload to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            debugLog("Error: Failed to serialize JSON: \(error)")
            handleCompletion(PostlogError.serializationFailed, completion: completion)
            return
        }
        
        // Create and add operation to queue for background processing
        let operation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            var requestError: Error?
            
            let task = self.session.dataTask(with: request) { _, response, error in
                defer { semaphore.signal() }
                
                if let error = error {
                    self.debugLog("Error: Network request failed: \(error)")
                    requestError = error
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.debugLog("Error: Invalid response")
                    requestError = PostlogError.invalidResponse
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    self.debugLog("Error: Request failed with status code \(httpResponse.statusCode)")
                    requestError = PostlogError.requestFailed(statusCode: httpResponse.statusCode)
                    return
                }
                
                self.debugLog("Request succeeded")
            }
            
            task.resume()
            
            // Wait for task to complete (with timeout)
            // This is inside a background operation, so blocking is acceptable
            _ = semaphore.wait(timeout: .now() + 30)
            
            // Handle completion on the main thread
            self.handleCompletion(requestError, completion: completion)
        }
        
        operationQueue.addOperation(operation)
    }
    
    /// Handles calling the completion handler on the main thread
    /// - Parameters:
    ///   - error: Optional error to pass to the completion handler
    ///   - completion: The completion handler to call
    private func handleCompletion(_ error: Error?, completion: ((Error?) -> Void)?) {
        guard let completion = completion else { return }
        
        completionQueue.async {
            completion(error)
        }
    }
    
    /// Logs debug messages if debug logging is enabled
    /// - Parameter message: The message to log
    private func debugLog(_ message: String) {
        if debugLoggingEnabled {
            print("[PostlogAnalytics] \(message)")
        }
    }
}

/// Errors that can occur during analytics operations
public enum PostlogError: Error, Equatable {
    /// The analytics client has not been initialized
    case notInitialized
    
    /// The provided properties contain invalid value types
    case invalidProperties
    
    /// The URL is invalid
    case invalidURL
    
    /// JSON serialization failed
    case serializationFailed
    
    /// The response is invalid
    case invalidResponse
    
    /// The request failed with the given status code
    case requestFailed(statusCode: Int)
    
    /// Implement Equatable conformance
    public static func == (lhs: PostlogError, rhs: PostlogError) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized),
             (.invalidProperties, .invalidProperties),
             (.invalidURL, .invalidURL),
             (.serializationFailed, .serializationFailed),
             (.invalidResponse, .invalidResponse):
            return true
        case (.requestFailed(let lhsCode), .requestFailed(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}
