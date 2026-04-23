import Foundation

@MainActor
protocol TimerSessionStoreProtocol: AnyObject {
    typealias TimerSessionsObserver = ([TimerSession]) -> Void

    func currentSessions() -> [TimerSession]
    @discardableResult
    func createTask(
        title: String,
        details: String,
        assignee: String,
        priority: TaskPriority,
        plannedDate: Date
    ) -> UUID
    func updateTask(_ task: TimerSession)
    func setTaskDone(id: UUID, isDone: Bool, completedAt: Date?)
    func deleteTask(id: UUID)
    @discardableResult
    func addObserver(_ observer: @escaping TimerSessionsObserver) -> UUID
    func removeObserver(_ observerID: UUID)
}
