import IG
import XCTest

final class TestMemoryLayout: XCTestCase {
    /// Helper test printing the type memory layout.
    func testPrintMemoryLayout() throws {
        print("\nCacheline size: \(cachelineSize())\n")
        layout(from: Database.Price.self)
    }
}

/// Print the memory layout of the given type
fileprivate func layout<T>(from type: T.Type) -> Void {
    print("""
        \(T.self):
            align:     \(MemoryLayout<T>.alignment) B  \t\(MemoryLayout<T>.alignment * 8) b
            size:      \(MemoryLayout<T>.size) B  \t\(MemoryLayout<T>.size * 8) b
            stride:    \(MemoryLayout<T>.stride) B  \t\(MemoryLayout<T>.stride * 8) b
        
        """)
}

/// Returns the cacheline size (in Bytes).
fileprivate func cachelineSize() -> Int {
    var query = [CTL_HW, HW_CACHELINE]
    var result: CInt = 0
    var resultSize = MemoryLayout.size(ofValue: result)
    let r = sysctl(&query, CUnsignedInt(query.count), &result, &resultSize, nil, 0)
    precondition(r == 0, "Cannot query cache line size")
    return Int(result)
}
