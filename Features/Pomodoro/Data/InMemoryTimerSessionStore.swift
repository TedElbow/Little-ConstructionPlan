import Foundation

@MainActor
final class InMemoryTimerSessionStore: ObservableObject, TimerSessionStoreProtocol {
    private enum StorageKeys {
        static let tasks = "construction.tasks.v1"
    }

    private var sessions: [TimerSession] = []
    private var observers: [UUID: TimerSessionsObserver] = [:]
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.sessions = Self.loadSessions(from: userDefaults)
    }

    func currentSessions() -> [TimerSession] {
        sessions.sorted(by: { $0.plannedDate > $1.plannedDate })
    }

    @discardableResult
    func createTask(
        title: String,
        details: String,
        assignee: String,
        priority: TaskPriority,
        plannedDate: Date
    ) -> UUID {
        let sessionID = UUID()
        let session = TimerSession(
            id: sessionID,
            title: title,
            details: details,
            assignee: assignee,
            priority: priority,
            plannedDate: plannedDate,
            isDone: false,
            completedAt: nil,
            createdAt: Date()
        )
        sessions.append(session)
        persistAndNotifyObservers()
        return sessionID
    }

    func updateTask(_ task: TimerSession) {
        guard let index = sessions.firstIndex(where: { $0.id == task.id }) else { return }
        sessions[index] = task
        persistAndNotifyObservers()
    }

    func setTaskDone(id: UUID, isDone: Bool, completedAt: Date?) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].isDone = isDone
        sessions[index].completedAt = completedAt
        persistAndNotifyObservers()
    }

    func deleteTask(id: UUID) {
        sessions.removeAll { $0.id == id }
        persistAndNotifyObservers()
    }

    @discardableResult
    func addObserver(_ observer: @escaping TimerSessionsObserver) -> UUID {
        let observerID = UUID()
        observers[observerID] = observer
        observer(currentSessions())
        return observerID
    }

    func removeObserver(_ observerID: UUID) {
        observers.removeValue(forKey: observerID)
    }

    private func persistAndNotifyObservers() {
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: StorageKeys.tasks)
        }
        notifyObservers()
    }

    private func notifyObservers() {
        let orderedSessions = currentSessions()
        for observer in observers.values {
            observer(orderedSessions)
        }
    }

    private static func loadSessions(from userDefaults: UserDefaults) -> [TimerSession] {
        guard let data = userDefaults.data(forKey: StorageKeys.tasks),
              let decoded = try? JSONDecoder().decode([TimerSession].self, from: data) else {
            return []
        }
        return decoded
    }
}
