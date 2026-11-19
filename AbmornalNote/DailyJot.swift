
import Foundation
import SwiftData

// MARK: - Daily Jot Model

@Model
final class DailyJot {
    
    var id: UUID = UUID()
    var dayKey: String = ""
    var content: String = ""
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        dayKey: String,
        content: String = "",
        position: Int = 0
    ) {
        self.id = UUID()
        self.dayKey = dayKey
        self.content = content
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Local Date Helper

enum JotDay {
    
    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        
        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        
        return formatter
    }
    
    static func key(for date: Date = .now) -> String {
        formatter().string(from: date)
    }
    
    static func date(for key: String) -> Date {
        formatter().date(from: key) ?? .now
    }
}
