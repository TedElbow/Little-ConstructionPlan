import Foundation

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

struct TimerSession: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var details: String
    var assignee: String
    var priority: TaskPriority
    var plannedDate: Date
    var isDone: Bool
    var completedAt: Date?
    var createdAt: Date
}
