import Foundation

/// Simple performance timing utility for debugging
struct PerformanceTimer {
    private let startTime: Date
    private let label: String

    /// Create and start a timer with a label
    init(_ label: String) {
        self.label = label
        self.startTime = Date()
    }

    /// Print elapsed time since timer creation
    func end() {
        let elapsed = Date().timeIntervalSince(startTime)
        print("⏱️ [\(label)] completed in \(String(format: "%.2f", elapsed))s")
    }

    /// Measure a synchronous operation
    static func measure<T>(_ label: String, operation: () -> T) -> T {
        let timer = PerformanceTimer(label)
        let result = operation()
        timer.end()
        return result
    }

    /// Measure an async operation
    static func measure<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        let timer = PerformanceTimer(label)
        let result = try await operation()
        timer.end()
        return result
    }
}
