import Foundation

extension Date {
    func relativeTimeString() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if Calendar.current.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else if Calendar.current.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: self))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none // No time for older dates
            return formatter.string(from: self)
        }
    }
    
    func dateGroupHeader() -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // e.g., "Tuesday"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }
}
