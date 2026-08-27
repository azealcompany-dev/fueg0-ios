import SwiftUI

struct CustomGoalsView: View {
    @State private var goals: [DailyGoal] = []
    @State private var showEditor = false
    @State private var editing: DailyGoal?
    @State private var message: String?

    private var checkable: [DailyGoal] {
        goals.count > 1 ? Array(goals.dropLast()) : goals
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(checkable.enumerated()), id: \.element.id) { index, goal in
                    Button {
                        editing = goal
                        showEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            if !goal.description.isEmpty {
                                Text(goal.description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.textMuted)
                            }
                        }
                    }
                    .fueg0RowSurface()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Daily laws")
            } footer: {
                Text("The lock goal stays last. Swipe a law to remove it.")
            }

            if let lock = goals.last, goals.count > 1 {
                Section("Lock") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lock.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.ember)
                        Text(lock.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    .fueg0RowSurface()
                }
            }
        }
        .fueg0ListChrome()
        .navigationTitle("My Daily Goals")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { resetDefaults() }
                    .foregroundStyle(Palette.ember)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add goal")
            }
        }
        .onAppear { goals = GoalsService().loadGoals() }
        .sheet(isPresented: $showEditor) {
            GoalEditorSheet(existing: editing) { saved in
                upsert(saved, replacing: editing)
            }
        }
        .alert("Daily laws", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func upsert(_ goal: DailyGoal, replacing: DailyGoal?) {
        if let replacing, let index = goals.firstIndex(where: { $0.id == replacing.id }) {
            goals[index] = goal
        } else {
            let insert = max(0, goals.count - 1)
            goals.insert(goal, at: insert)
        }
        GoalsService().saveGoals(goals)
    }

    private func delete(at index: Int) {
        guard goals.count > 2 else {
            message = "Keep at least 2 goals (including your lock goal)."
            return
        }
        goals.remove(at: index)
        GoalsService().saveGoals(goals)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func resetDefaults() {
        GoalsService().resetToDefaults()
        goals = GoalsService().loadGoals()
        message = "Default 6 Daily Laws restored."
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

private struct GoalEditorSheet: View {
    var existing: DailyGoal?
    var onSave: (DailyGoal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.characters)
                    TextField("Description", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Add Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let goal = DailyGoal(
                            id: existing?.id ?? GoalsService().generateId(),
                            title: trimmed.uppercased(),
                            description: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: existing?.createdAt ?? ISO8601DateFormatter().string(from: Date())
                        )
                        onSave(goal)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            title = existing?.title ?? ""
            detail = existing?.description ?? ""
        }
    }
}
