import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var tasks: [TimerSession] = []

    private let timerSessionStore: TimerSessionStoreProtocol
    private var observerID: UUID?

    init(timerSessionStore: TimerSessionStoreProtocol) {
        self.timerSessionStore = timerSessionStore
        observerID = timerSessionStore.addObserver { [weak self] sessions in
            self?.tasks = sessions.sorted(by: { $0.plannedDate > $1.plannedDate })
        }
    }

    deinit {
        if let observerID {
            Task { @MainActor [timerSessionStore] in
                timerSessionStore.removeObserver(observerID)
            }
        }
    }

    var todaysTasks: [TimerSession] {
        let today = Date()
        return tasks
            .filter { Calendar.current.isDate($0.plannedDate, inSameDayAs: today) && !$0.isDone }
            .sorted(by: prioritySort)
    }

    var completedTodayTasks: [TimerSession] {
        let today = Date()
        return tasks
            .filter { Calendar.current.isDate($0.plannedDate, inSameDayAs: today) && $0.isDone }
            .sorted(by: prioritySort)
    }

    var overdueTasks: [TimerSession] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks
            .filter { !$0.isDone && $0.plannedDate < startOfToday }
            .sorted(by: { $0.plannedDate > $1.plannedDate })
    }

    var progressFraction: Double {
        let total = todaysTasks.count + completedTodayTasks.count
        guard total > 0 else { return 0 }
        return Double(completedTodayTasks.count) / Double(total)
    }

    var progressPercentText: String {
        "\(Int((progressFraction * 100).rounded()))%"
    }

    func addTask(
        title: String,
        details: String,
        assignee: String,
        priority: TaskPriority,
        plannedDate: Date
    ) {
        _ = timerSessionStore.createTask(
            title: title,
            details: details,
            assignee: assignee,
            priority: priority,
            plannedDate: plannedDate
        )
    }

    func toggleDone(for taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        timerSessionStore.setTaskDone(
            id: taskID,
            isDone: !task.isDone,
            completedAt: task.isDone ? nil : Date()
        )
    }

    func deleteTask(id: UUID) {
        timerSessionStore.deleteTask(id: id)
    }

    func updateTask(_ task: TimerSession) {
        timerSessionStore.updateTask(task)
    }

    private func prioritySort(_ lhs: TimerSession, _ rhs: TimerSession) -> Bool {
        priorityWeight(lhs.priority) > priorityWeight(rhs.priority)
    }

    private func priorityWeight(_ priority: TaskPriority) -> Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}
