
import SwiftUI
import SwiftData

// MARK: - Daily Jots Page

struct DailyJotsView: View {
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.scenePhase)
    private var scenePhase
    
    @Environment(\.modelContext)
    private var modelContext

    private let historyDayKey: String?

    @State private var dayKey: String
    @State private var showHistory = false
    @State private var saveError: String?

    init(historyDayKey: String? = nil) {
        self.historyDayKey = historyDayKey

        _dayKey = State(
            initialValue: historyDayKey ?? JotDay.key()
        )
    }

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Page Title
            
            Text("Daily jots.")
                .font(.system(
                    size: 42,
                    weight: .medium
                ))
                .tracking(-1.8)
                .foregroundStyle(
                    AppTheme.text(colorScheme)
                )
                .accessibilityAddTraits(.isHeader)
            
            // MARK: - Current Date

            HStack {
                Text(
                    JotDay.date(for: dayKey),
                    format: .dateTime
                        .weekday(.wide)
                        .month(.wide)
                        .day()
                        .year()
                )
                .font(.system(size: 14))
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )

                Spacer()

                if historyDayKey == nil {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(
                                size: 17,
                                weight: .medium
                            ))
                            .foregroundStyle(
                                AppTheme.text(colorScheme)
                            )
                            .frame(width: 44, height: 44)
                            .glassEffect(
                                .regular.interactive(),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jot history")
                }
            }

            
            Divider()
                .padding(.vertical, 8)
            
            // Daily Editor
            
            DailyJotEditor(
                dayKey: dayKey,
                onSave: {
                    _ = saveChanges()
                }
            )
            .id(dayKey)
            
            // Save Error State
            
            if let saveError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Unable to save changes",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Retry saving") {
                        _ = saveChanges()
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .padding(12)
            }
        }
        .sheet(isPresented: $showHistory) {
            JotHistoryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task(id: scenePhase) {

            guard scenePhase == .active,
                  historyDayKey == nil else {
                return
            }
            
            // Detect date changes while the app is active.
            
            while !Task.isCancelled {
                
                refreshCurrentDay()
                
                do {
                    try await Task.sleep(
                        for: .seconds(1)
                    )
                } catch {
                    break
                }
            }
        }
    }
    
    // MARK: - Date Rollover
    
    private func refreshCurrentDay() {
        
        let today = JotDay.key()
        
        guard today != dayKey else {
            return
        }
        
        // Save pending changes before switching days.
        
        guard saveChanges() else {
            return
        }
        
        dayKey = today
    }
    
    // MARK: - Persistence
    
    @discardableResult
    private func saveChanges() -> Bool {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }
            
            saveError = nil
            return true
            
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}

// MARK: - Daily Jot Editor

private struct DailyJotEditor: View {
    
    @Environment(\.modelContext)
    private var modelContext
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Query private var jots: [DailyJot]
    
    @FocusState private var focusedJotID: UUID?
    
    @State private var pendingFocusID: UUID?
    
    @State private var jotToDelete: DailyJot?
    
    @State private var showDeleteAlert = false
    
    let dayKey: String
    
    let onSave: () -> Void
    
    init(
        dayKey: String,
        onSave: @escaping () -> Void
    ) {
        self.dayKey = dayKey
        self.onSave = onSave
        
        let selectedDay = dayKey
        
        _jots = Query(
            filter: #Predicate<DailyJot> { jot in
                jot.dayKey == selectedDay
            },
            sort: [
                SortDescriptor(\DailyJot.position),
                SortDescriptor(\DailyJot.createdAt)
            ]
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            if jots.isEmpty {
                emptyState
            } else {
                
                ForEach(jots, id: \.id) { jot in
                    jotRow(jot)
                }
                
                if let lastJot = jots.last,
                   !lastJot.content.trimmingCharacters(
                        in: .whitespacesAndNewlines
                   ).isEmpty {
                    
                    addJotButton
                }
            }

            
            Spacer(minLength: 80)
            
            if !jots.isEmpty {
                footer
            }
        }
        .alert(
            "Delete this jot?",
            isPresented: $showDeleteAlert,
            presenting: jotToDelete
        ) { jot in
            
            Button("Delete", role: .destructive) {
                deleteJot(jot)
            }
            
            Button("Cancel", role: .cancel) {
                jotToDelete = nil
            }
            
        } message: { _ in
            Text(
                "This thought will be permanently removed."
            )
        }
    }
    

    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            Text("Make room for your thoughts.")
                .font(.system(size: 15))
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
            
            addJotButton
        }
    }

    
    // MARK: - Individual Jot
    
    private func jotRow(
        _ jot: DailyJot
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            
            Circle()
                .fill(
                    focusedJotID == jot.id
                    ? AppTheme.lilac
                    : AppTheme.secondaryText(colorScheme)
                        .opacity(0.35)
                )
                .frame(width: 5, height: 5)
                .padding(.top, 10)
            
            TextField(
                "Write a thought...",
                text: Binding(
                    get: {
                        jot.content
                    },
                    set: { newValue in
                        jot.content = newValue
                        jot.updatedAt = .now
                        onSave()
                    }
                ),
                axis: .vertical
            )
            .font(.system(size: 17))
            .foregroundStyle(
                AppTheme.text(colorScheme)
            )
            .tint(
                colorScheme == .dark
                ? AppTheme.lime
                : AppTheme.forestBlack
            )
            .textFieldStyle(.plain)
            .lineSpacing(5)
            .focused(
                $focusedJotID,
                equals: jot.id
            )
            .onAppear {
                if pendingFocusID == jot.id {
                    focusedJotID = jot.id
                    pendingFocusID = nil
                }
            }
            
            Menu {
                Button(
                    "Delete jot",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    jotToDelete = jot
                    showDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Jot options")
        }
    }
    

    // MARK: - Add Button
    
    private var addJotButton: some View {
        Button {
            addJot()
        } label: {
            HStack(spacing: 12) {
                
                Circle()
                    .fill(
                        AppTheme.secondaryText(colorScheme)
                            .opacity(0.35)
                    )
                    .frame(width: 5, height: 5)
                
                Text("Write a thought...")
                    .font(.system(size: 17))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                            .opacity(0.7)
                    )
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 44,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Write a new thought")
    }

    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            
            let count = jots.filter {
                !$0.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }.count
            
            Text("\(count) \(count == 1 ? "jot" : "jots")")
            
            Spacer()
            
            if focusedJotID != nil {
                Button {
                    focusedJotID = nil
                    onSave()
                } label: {
                    Label(
                        "Done",
                        systemImage: "keyboard.chevron.compact.down"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(
            AppTheme.secondaryText(colorScheme)
        )
    }
    
    // MARK: - Create Jot
    
    private func addJot() {
        
        // Reuse the last empty jot, if available.
        
        if let lastJot = jots.last,
           lastJot.content.trimmingCharacters(
                in: .whitespacesAndNewlines
           ).isEmpty {
            
            focusedJotID = lastJot.id
            return
        }
        
        let nextPosition = (
            jots.map(\.position).max() ?? -1
        ) + 1
        
        let jot = DailyJot(
            dayKey: dayKey,
            position: nextPosition
        )
        
        pendingFocusID = jot.id
        
        modelContext.insert(jot)
        onSave()
    }
    
    // MARK: - Delete Jot
    
    private func deleteJot(_ jot: DailyJot) {
        
        if focusedJotID == jot.id {
            focusedJotID = nil
        }
        
        modelContext.delete(jot)
        
        jotToDelete = nil
        
        onSave()
    }
}

#Preview {
    ScrollView {
        DailyJotsView()
            .padding(24)
    }
    .modelContainer(
        for: DailyJot.self,
        inMemory: true
    )
}
