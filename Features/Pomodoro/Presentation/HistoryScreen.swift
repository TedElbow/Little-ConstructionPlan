import SwiftUI

struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            GameThemePalette.skyBackgroundGradient
                .ignoresSafeArea()
            List(viewModel.daySummaries) { summary in
                NavigationLink {
                    DayDetailsScreen(summary: summary)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                        Text("\(summary.completedCount) of \(summary.totalCount) completed")
                            .font(.subheadline)
                    }
                    .foregroundStyle(GameThemePalette.chickenTextPrimary)
                    .padding(8)
                }
                .listRowBackground(GameThemePalette.elevatedCardSurfaceBackground)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("History")
    }
}

private struct DayDetailsScreen: View {
    let summary: HistoryDaySummary

    var body: some View {
        List(summary.tasks) { task in
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isDone)
                Text(task.details)
                    .font(.subheadline)
                Text("Owner: \(task.assignee)")
                    .font(.footnote)
                Text("Priority: \(task.priority.title) • Status: \(task.isDone ? "Done" : "Pending")")
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .foregroundStyle(GameThemePalette.chickenTextPrimary)
            .listRowBackground(task.isDone ? GameThemePalette.elevatedCardSurfaceBackground : GameThemePalette.cardSurfaceBackground)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background(GameThemePalette.skyBackgroundGradient.ignoresSafeArea())
        .navigationTitle(summary.date.formatted(date: .abbreviated, time: .omitted))
    }
}
