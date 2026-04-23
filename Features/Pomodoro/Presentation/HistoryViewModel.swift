import Foundation

struct HistoryDaySummary: Identifiable {
    let date: Date
    let tasks: [TimerSession]

    var id: Date { Calendar.current.startOfDay(for: date) }

    var completedCount: Int {
        tasks.filter(\.isDone).count
    }

    var totalCount: Int { tasks.count }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var sessions: [TimerSession] = []

    private let timerSessionStore: TimerSessionStoreProtocol
    private var observerID: UUID?

    init(timerSessionStore: TimerSessionStoreProtocol) {
        self.timerSessionStore = timerSessionStore
        observerID = timerSessionStore.addObserver { [weak self] sessions in
            self?.sessions = sessions
        }
    }

    deinit {
        if let observerID {
            Task { @MainActor [timerSessionStore] in
                timerSessionStore.removeObserver(observerID)
            }
        }
    }

    var daySummaries: [HistoryDaySummary] {
        let grouped = Dictionary(grouping: sessions) {
            Calendar.current.startOfDay(for: $0.plannedDate)
        }
        return grouped
            .map { HistoryDaySummary(date: $0.key, tasks: $0.value.sorted(by: { $0.createdAt > $1.createdAt })) }
            .sorted(by: { $0.date > $1.date })
    }
}
