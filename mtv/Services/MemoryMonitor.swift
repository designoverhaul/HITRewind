import UIKit
import Foundation

class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    private init() {}
    
    // Get current memory usage in MB
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return -1
        }
    }
    
    // Print memory usage with a label
    func printMemoryUsage(label: String) {
        let memoryUsage = getCurrentMemoryUsage()
        if memoryUsage >= 0 {
            print("🔍 MEMORY [\(label)]: \(String(format: "%.1f", memoryUsage)) MB")
        } else {
            print("🔍 MEMORY [\(label)]: Unable to get memory info")
        }
    }
    
    // Check if memory usage is high (over 200MB)
    func isMemoryUsageHigh() -> Bool {
        let usage = getCurrentMemoryUsage()
        return usage > 200.0
    }
    
    // Log image loading impact
    func logImageLoadingImpact(imageSize: CGSize, beforeMemory: Double) {
        let afterMemory = getCurrentMemoryUsage()
        let memoryDelta = afterMemory - beforeMemory
        print("🖼️ IMAGE IMPACT: \(imageSize) | Memory: \(String(format: "%.1f", beforeMemory))MB -> \(String(format: "%.1f", afterMemory))MB (Δ\(String(format: "%.1f", memoryDelta))MB)")
    }
} 