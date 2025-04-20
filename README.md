# PostlogAnalytics

A lightweight analytics library for SwiftUI applications that sends events to the Postlog analytics backend.

## Features

- 🔑 Simple API key authentication
- 👤 User identification with custom properties
- 📊 Event tracking with custom metadata
- 📱 Works on iOS, macOS, watchOS, and tvOS
- 🧵 Thread-safe asynchronous operations
- ⚡️ Lightweight with no external dependencies

## Requirements

- iOS 14.0+ / macOS 11.0+ / watchOS 7.0+ / tvOS 14.0+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/yourusername/PostlogAnalytics.git", from: "1.0.0")
```

Or add it directly in Xcode:

1. File > Swift Packages > Add Package Dependency
2. Enter the repository URL: `https://github.com/yourusername/PostlogAnalytics.git`
3. Follow the prompts to add the package

## Usage

### Initialization

Initialize PostlogAnalytics with your API token at application startup:

```swift
import PostlogAnalytics

@main
struct MyApp: App {
    init() {
        PostlogAnalytics.shared.initialize(token: "YOUR_API_TOKEN")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### User Identification

Identify a user with custom properties:

```swift
Task {
    do {
        try await PostlogAnalytics.shared.identify(
            userId: "user123",
            project: "household",
            properties: [
                "username": "johndoe",
                "plan": "pro",
                "age": 30,
                "isPremium": true
            ]
        ).value
        
        print("User identified successfully")
    } catch {
        print("Failed to identify user: \(error)")
    }
}
```

### Event Tracking

Track events with custom metadata:

```swift
Task {
    do {
        try await PostlogAnalytics.shared.track(
            name: "purchase_completed",
            channel: "transactions",
            project: "household",
            userId: "user123",
            icon: "💰",
            description: "User completed a purchase",
            tags: [
                "product": "premium_subscription",
                "price": 9.99,
                "quantity": 1,
                "currency": "USD"
            ]
        ).value
        
        print("Event tracked successfully")
    } catch {
        print("Failed to track event: \(error)")
    }
}
```

## Error Handling

PostlogAnalytics provides detailed error information:

```swift
do {
    try await PostlogAnalytics.shared.track(...)
} catch PostlogError.notInitialized {
    print("Please initialize PostlogAnalytics with a token first")
} catch PostlogError.invalidProperties {
    print("The properties contain invalid value types")
} catch PostlogError.requestFailed(let statusCode) {
    print("Request failed with status code: \(statusCode)")
} catch {
    print("An unknown error occurred: \(error)")
}
```

## Advanced Usage

### Handling Network Connectivity

For offline-first applications, you can implement a queue to store events when offline:

```swift
// Check connectivity before sending events
if NetworkMonitor.shared.isConnected {
    // Send event
} else {
    // Save event to local storage
    EventQueue.shared.enqueue(event)
}
```

### Batch Processing

For high-volume applications, you might want to batch events:

```swift
// Collect events
EventBatcher.shared.add(event)

// Send batched events periodically
EventBatcher.shared.sendBatchIfNeeded()
```

## License

PostlogAnalytics is available under the MIT license. See the LICENSE file for more information.
