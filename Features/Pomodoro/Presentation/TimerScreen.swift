import SwiftUI

struct TimerScreen: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var editorDraft = TaskEditorDraft()
    @State private var editingTaskID: UUID?
    @State private var isEditorPresented = false

    init(viewModel: TimerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            GameThemePalette.skyBackgroundGradient
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(Date.now.formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .foregroundStyle(GameThemePalette.chickenTextPrimary)
                        Spacer()
                        Button {
                            editorDraft = TaskEditorDraft()
                            editingTaskID = nil
                            isEditorPresented = true
                        } label: {
                            Label("Add Task", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GameThemePalette.chickenGoldenYellow)
                    }

                    progressCard

                    if viewModel.todaysTasks.isEmpty && viewModel.completedTodayTasks.isEmpty {
                        Text("No tasks for today yet. Add one to start tracking your progress.")
                            .foregroundStyle(GameThemePalette.chickenTextPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GameThemePalette.cardSurfaceBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        taskSection(title: "Today", tasks: viewModel.todaysTasks)
                        taskSection(title: "Completed Today", tasks: viewModel.completedTodayTasks)
                    }

                    if !viewModel.overdueTasks.isEmpty {
                        taskSection(title: "Overdue", tasks: viewModel.overdueTasks, overdue: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationTitle("Today")
        .sheet(isPresented: $isEditorPresented) {
            editorView
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Progress: \(viewModel.progressPercentText)")
            ProgressView(value: viewModel.progressFraction)
                .tint(GameThemePalette.chickenGoldenYellow)
        }
        .font(.headline)
        .foregroundStyle(GameThemePalette.chickenTextPrimary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameThemePalette.elevatedCardSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func taskSection(title: String, tasks: [TimerSession], overdue: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(GameThemePalette.chickenTextPrimary)
            ForEach(tasks) { task in
                taskRow(task, overdue: overdue)
            }
        }
    }

    private func taskRow(_ task: TimerSession, overdue: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isDone)
                Spacer()
                Text(task.priority.title)
                    .font(.caption.weight(.semibold))
            }
            Text(task.details)
                .font(.subheadline)
                .strikethrough(task.isDone)
            Text("Owner: \(task.assignee)")
                .font(.footnote)
            HStack {
                Button(task.isDone ? "Undo" : "Done") {
                    viewModel.toggleDone(for: task.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(GameThemePalette.chickenGoldenYellow)
                Spacer()
                Button("Edit") {
                    editorDraft = TaskEditorDraft(task: task)
                    editingTaskID = task.id
                    isEditorPresented = true
                }
                .buttonStyle(.bordered)
                Button("Delete", role: .destructive) {
                    viewModel.deleteTask(id: task.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(GameThemePalette.chickenTextPrimary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackgroundColor(task: task, overdue: overdue))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var editorView: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $editorDraft.title)
                TextField("Description", text: $editorDraft.details)
                TextField("Assignee", text: $editorDraft.assignee)
                DatePicker("Date", selection: $editorDraft.plannedDate, displayedComponents: .date)
                Picker("Priority", selection: $editorDraft.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
            }
            .navigationTitle(editingTaskID == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isEditorPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEditorTask()
                        isEditorPresented = false
                    }
                    .disabled(editorDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveEditorTask() {
        if let editingTaskID,
           let originalTask = (viewModel.todaysTasks + viewModel.completedTodayTasks + viewModel.overdueTasks)
            .first(where: { $0.id == editingTaskID }) {
            var updated = originalTask
            updated.title = editorDraft.title
            updated.details = editorDraft.details
            updated.assignee = editorDraft.assignee
            updated.priority = editorDraft.priority
            updated.plannedDate = editorDraft.plannedDate
            viewModel.updateTask(updated)
        } else {
            viewModel.addTask(
                title: editorDraft.title,
                details: editorDraft.details,
                assignee: editorDraft.assignee,
                priority: editorDraft.priority,
                plannedDate: editorDraft.plannedDate
            )
        }
    }

    private func rowBackgroundColor(task: TimerSession, overdue: Bool) -> Color {
        if task.isDone { return GameThemePalette.elevatedCardSurfaceBackground }
        if overdue { return GameThemePalette.destructiveSurfaceBackground }
        return GameThemePalette.cardSurfaceBackground
    }
}

private struct TaskEditorDraft {
    var title: String = ""
    var details: String = ""
    var assignee: String = ""
    var priority: TaskPriority = .medium
    var plannedDate: Date = Date()

    init() {}

    init(task: TimerSession) {
        title = task.title
        details = task.details
        assignee = task.assignee
        priority = task.priority
        plannedDate = task.plannedDate
    }
}
