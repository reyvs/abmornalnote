
import SwiftUI
import SwiftData
import UIKit

// MARK: - Daily Jots Page

struct DailyJotsView: View {
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.scenePhase)
    private var scenePhase
    
    @Environment(\.modelContext)
    private var modelContext

    private let historyDayKey: String?
    private let onEditingChanged: (Bool) -> Void

    @State private var dayKey: String
    @State private var showHistory = false
    @State private var saveError: String?

   
    init(
        historyDayKey: String? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.historyDayKey = historyDayKey
        self.onEditingChanged = onEditingChanged

        _dayKey = State(
            initialValue: historyDayKey ?? JotDay.key()
        )
    }


    // MARK: - Main View

    var body: some View {

        DailyJotEditor(
            dayKey: dayKey,

            onSave: {
                _ = saveChanges()
            },

            onEditingChanged: onEditingChanged,

            header: {
                pageHeader
            },

            saveStatus: {
                saveStatusView
            }
        )
        .id(dayKey)
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

    // MARK: - Page Header

    private var pageHeader: some View {

        VStack(alignment: .leading, spacing: 16) {

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
                            .frame(
                                width: 44,
                                height: 44
                            )
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
        }
    }

    // MARK: - Save Status

    @ViewBuilder
    private var saveStatusView: some View {

        if let saveError {

            VStack(alignment: .leading, spacing: 8) {

                Label(
                    "Unable to save changes",
                    systemImage: "exclamationmark.circle"
                )
                .font(.system(
                    size: 13,
                    weight: .medium
                ))
                .foregroundStyle(.red)

                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Retry saving") {
                    _ = saveChanges()
                }
                .font(.system(
                    size: 14,
                    weight: .medium
                ))
            }
            .padding(12)
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

private struct DailyJotEditor<
    Header: View,
    SaveStatus: View
>: View {
    
    @Environment(\.modelContext)
    private var modelContext
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Query private var jots: [DailyJot]
    
    // MARK: - Focus Management
    
    private enum EditorFocus: Hashable {
        case draft
        case jot(UUID)
    }
    
    @FocusState private var focusedField: EditorFocus?
    
    // MARK: - Draft State
    
    @State private var draftContent = ""
    @State private var draftJot: DailyJot?
    
    
    // MARK: - Selection State
    
    private struct JotSwipe: Equatable {
        
        var jotID: UUID? = nil
        var distance: CGFloat = 0
    }
    
    @GestureState(
        resetTransaction: Transaction(
            animation: .spring(
                response: 0.32,
                dampingFraction: 0.78
            )
        )
    )
    private var activeSwipe = JotSwipe()
    
    
    @State private var selectedJotIDs: Set<UUID> = []
    
    @State private var didCopySelection = false
    
    private var selectableJots: [DailyJot] {
        jots.filter { jot in
            !jot.isDeleted &&
            !isEmpty(jot.content)
        }
    }
    
    private var selectedJots: [DailyJot] {
        selectableJots.filter { jot in
            selectedJotIDs.contains(jot.id)
        }
    }
    
    private var allJotsSelected: Bool {
        !selectableJots.isEmpty &&
        selectableJots.allSatisfy { jot in
            selectedJotIDs.contains(jot.id)
        }
    }
    
    // MARK: - Delete State
    
    @State private var jotToDelete: DailyJot?
    @State private var showDeleteAlert = false
    
    let dayKey: String
    let onSave: () -> Void
    let onEditingChanged: (Bool) -> Void
    
    let header: Header
    let saveStatus: SaveStatus
    
    @State private var scrollRequest = 0
    
    
    // MARK: - Initialization
    
    init(
        dayKey: String,
        onSave: @escaping () -> Void,
        onEditingChanged: @escaping (Bool) -> Void,
        @ViewBuilder header: () -> Header,
        @ViewBuilder saveStatus: () -> SaveStatus
    ) {
        self.dayKey = dayKey
        self.onSave = onSave
        self.onEditingChanged = onEditingChanged
        
        self.header = header()
        self.saveStatus = saveStatus()
        
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
    
    
    // MARK: - Data Helpers
    
    private func isEmpty(_ text: String) -> Bool {
        text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }
    
    private var visibleJots: [DailyJot] {
        jots.filter { jot in
            
            // The active draft has its own TextField.
            
            guard jot.id != draftJot?.id else {
                return false
            }
            
            return !isEmpty(jot.content) ||
            focusedField == .jot(jot.id)
        }
    }
    
    private var jotCount: Int {
        jots.filter {
            !isEmpty($0.content)
        }.count
    }
    
    
    
    // MARK: - Main View
    
    // MARK: - Main View
    
    var body: some View {
        
        ScrollViewReader { proxy in
            
            ScrollView {
                
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    
                    header
                    
                    if visibleJots.isEmpty &&
                        draftJot == nil {
                        
                        Text("Make room for your thoughts.")
                            .font(.system(size: 15))
                            .foregroundStyle(
                                AppTheme.secondaryText(
                                    colorScheme
                                )
                            )
                    }
                    
                    // Existing Jots
                    
                    ForEach(
                        visibleJots,
                        id: \.id
                    ) { jot in
                        
                        jotRow(jot)
                            .id(
                                EditorFocus.jot(jot.id)
                            )
                    }
                    
                    // Permanent Draft
                    
                    draftRow
                        .id(EditorFocus.draft)
                    
                    Spacer(minLength: 24)
                    
                    if jotCount > 0 {
                        
                        Text(
                            "\(jotCount) " +
                            (
                                jotCount == 1
                                ? "jot"
                                : "jots"
                            )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(
                            AppTheme.secondaryText(
                                colorScheme
                            )
                        )
                    }
                    
                    saveStatus
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(
                    .horizontal,
                    AppTheme.screenPadding
                )
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            
            // MARK: Sticky Bottom Controls
            
            .safeAreaInset(
                edge: .bottom,
                spacing: 0
            ) {
                
                if focusedField != nil {
                    
                    writingAccessory
                        .padding(
                            .horizontal,
                            AppTheme.screenPadding
                        )
                        .padding(.vertical, 6)
                        .transition(.opacity)
                    
                } else if !selectedJots.isEmpty {
                    
                    selectionActions
                        .padding(
                            .horizontal,
                            AppTheme.screenPadding
                        )
                        .padding(.vertical, 8)
                        .transition(
                            .move(edge: .bottom)
                            .combined(with: .opacity)
                        )
                }
            }
            
            // MARK: Follow Active Field
            
            .onChange(of: focusedField) {
                _, newValue in
                
                guard let target = newValue else {
                    return
                }
                
                Task { @MainActor in
                    
                    await Task.yield()
                    
                    guard focusedField == target else {
                        return
                    }
                    
                    withAnimation(
                        .easeOut(duration: 0.25)
                    ) {
                        proxy.scrollTo(
                            target,
                            anchor: .bottom
                        )
                    }
                }
            }
            
            // MARK: Follow New Draft
            
            .onChange(of: scrollRequest) { _, _ in
                
                Task { @MainActor in
                    
                    await Task.yield()
                    
                    guard focusedField == .draft else {
                        return
                    }
                    
                    withAnimation(
                        .easeOut(duration: 0.25)
                    ) {
                        proxy.scrollTo(
                            EditorFocus.draft,
                            anchor: .bottom
                        )
                    }
                }
            }
        }
        
        // MARK: Existing Lifecycle
        
        .onAppear {
            removeEmptyJots()
        }
        
        .onChange(of: focusedField) {
            oldValue, newValue in
            
            if oldValue == .draft &&
                newValue != .draft {
                
                finishDraft()
            }
            
            removeEmptyJots()
            
            onEditingChanged(
                newValue != nil
            )
        }
        
        .onChange(
            of: selectableJots.map(\.id)
        ) { _, newIDs in
            
            selectedJotIDs.formIntersection(
                Set(newIDs)
            )
        }
        
        .onChange(of: selectedJotIDs) { _, _ in
            didCopySelection = false
        }
        
        .onDisappear {
            
            focusedField = nil
            
            finishDraft()
            
            removeEmptyJots()
            
            endSelection()
            
            onEditingChanged(false)
        }
        
        .sensoryFeedback(
            .selection,
            trigger: selectedJotIDs
        )
        
        .animation(
            .spring(
                response: 0.35,
                dampingFraction: 0.85
            ),
            value: selectedJots.isEmpty
        )
        
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
    
    
    // MARK: - Contextual AI Bar
    
    private var selectionActions: some View {
        
        HStack(spacing: 12) {
            
            
            // MARK: Selection Counter
            
            Menu {
                
                Button(
                    "Copy selected",
                    systemImage: "doc.on.doc"
                ) {
                    copySelectedJots()
                }
                
                Button(
                    allJotsSelected
                    ? "Deselect all"
                    : "Select all",
                    systemImage: "checklist"
                ) {
                    toggleSelectAll()
                }
                
            } label: {
                
                HStack(spacing: 8) {
                    
                    VStack(
                        alignment: .center,
                        spacing: 3
                    ) {
                        
                        Text("\(selectedJots.count)")
                            .font(.system(
                                size: 24,
                                weight: .semibold
                            ))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(
                                colorScheme == .dark
                                ? AppTheme.lime
                                : Color(hex: 0x527000)
                            )
                        
                        Text(
                            didCopySelection
                            ? "Copied"
                            : "Selected"
                        )
                        .font(.system(
                            size: 11,
                            weight: .medium
                        ))
                        .foregroundStyle(
                            AppTheme.secondaryText(
                                colorScheme
                            )
                        )
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(
                            size: 9,
                            weight: .medium
                        ))
                        .foregroundStyle(
                            AppTheme.secondaryText(
                                colorScheme
                            )
                        )
                }
                .frame(width: 76)
                .frame(minHeight: 48)
                .padding(.leading, 12)
            }
            .buttonStyle(.plain)
            
            
            // MARK: Primary AI Action
            
            Button {
                
                // Gemini integration in Phase 5.
                
            } label: {
                
                HStack(spacing: 8) {
                    
                    Image(systemName: "sparkles")
                        .font(.system(
                            size: 17,
                            weight: .medium
                        ))
                    
                    Text("Organize with AI")
                        .font(.system(
                            size: 14,
                            weight: .semibold
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(AppTheme.obsidian)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    AppTheme.lilac,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.8)
            .accessibilityHint(
                "AI organization is coming soon."
            )
            
            // MARK: Close Button
            
            Button {
                
                endSelection()
                
            } label: {
                
                Image(systemName: "xmark")
                    .font(.system(
                        size: 12,
                        weight: .semibold
                    ))
                    .foregroundStyle(
                        AppTheme.text(
                            colorScheme
                        )
                    )
                    .frame(
                        width: 36,
                        height: 36
                    )
                    .background {
                        
                        Circle()
                            .fill(
                                AppTheme.secondaryText(
                                    colorScheme
                                )
                                .opacity(0.13)
                            )
                    }
                    .frame(
                        width: 44,
                        height: 44
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Clear selection"
            )
        }
        .padding(12)
        .glassEffect(
            .regular,
            in: Capsule()
        )
    }
    
    // MARK: - Permanent Draft Row
    
    private var draftRow: some View {
        HStack(alignment: .top, spacing: 12) {
            
            Circle()
                .fill(
                    focusedField == .draft
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
                        draftContent
                    },
                    set: { newValue in
                        handleDraftInput(newValue)
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
                $focusedField,
                equals: .draft
            )
            .submitLabel(.next)
            .onSubmit {
                advanceToNextJot()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .accessibilityLabel("Write a thought")
        }
        .frame(
            minHeight: 30,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .draft
        }
    }
    
    
    
    // MARK: - Existing Jot Row
    
    private func jotRow(
        _ jot: DailyJot
    ) -> some View {
        
        let isSelected =
        selectedJotIDs.contains(jot.id)
        
        let isFocused =
        focusedField == .jot(jot.id)
        
        // MARK: Swipe Animation Values
        
        let swipeDistance =
        activeSwipe.jotID == jot.id
        ? activeSwipe.distance
        : 0
        
        let swipeProgress = min(
            swipeDistance / 45,
            1
        )
        
        let rowOffset = min(
            swipeDistance * 0.65,
            38
        )
        
        let previewSelected =
        swipeDistance >= 45
        ? !isSelected
        : isSelected
        
        let bulletSize: CGFloat =
        isSelected
        ? 10 - (5 * swipeProgress)
        : 5 + (5 * swipeProgress)
        
        return HStack(
            alignment: .top,
            spacing: 12
        ) {
            
            // MARK: Animated Bullet
            
            Color.clear
                .frame(width: 5, height: 5)
                .overlay {
                    
                    Circle()
                        .fill(
                            previewSelected
                            ? AppTheme.lime
                            : isFocused
                            ? AppTheme.lilac
                            : AppTheme.secondaryText(
                                colorScheme
                            )
                            .opacity(0.35)
                        )
                        .frame(
                            width: bulletSize,
                            height: bulletSize
                        )
                        .animation(
                            .spring(
                                response: 0.25,
                                dampingFraction: 0.72
                            ),
                            value: isSelected
                        )
                }
                .padding(.top, 10)
            
            // MARK: Existing TextField
            
            TextField(
                "",
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
                $focusedField,
                equals: .jot(jot.id)
            )
            
            // MARK: Contextual Menu
            
            Menu {
                
                Button(
                    isSelected
                    ? "Deselect jot"
                    : "Select jot",
                    
                    systemImage:
                        isSelected
                    ? "circle"
                    : "checkmark.circle"
                ) {
                    
                    toggleSelection(jot.id)
                }
                .disabled(
                    isEmpty(jot.content)
                )
                
                Divider()
                
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
                        AppTheme.secondaryText(
                            colorScheme
                        )
                    )
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .opacity(
                1 - Double(swipeProgress) * 0.85
            )
            .accessibilityLabel("Jot options")
        }
        
        // MARK: Interactive Row Offset
        
        .offset(x: rowOffset)
        .contentShape(Rectangle())
        
        // MARK: Swipe Gesture
        
        .simultaneousGesture(
            
            DragGesture(
                minimumDistance: 24,
                coordinateSpace: .global
            )
            .updating($activeSwipe) {
                value, state, transaction in
                
                let horizontal =
                value.translation.width
                
                let vertical =
                abs(value.translation.height)
                
                transaction.animation = nil
                
                guard horizontal > 0,
                      horizontal > vertical * 1.5,
                      !isEmpty(jot.content)
                else {
                    
                    state = JotSwipe()
                    
                    return
                }
                
                state = JotSwipe(
                    jotID: jot.id,
                    distance: horizontal
                )
            }
                .onEnded { value in
                    
                    let horizontal =
                    value.translation.width
                    
                    let vertical =
                    abs(value.translation.height)
                    
                    guard horizontal >= 45,
                          horizontal > vertical * 1.5,
                          !isEmpty(jot.content)
                    else {
                        return
                    }
                    
                    toggleSelection(jot.id)
                }
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }
    
    
    
    // MARK: - Selection Logic
    
    private func toggleSelection(
        _ jotID: UUID
    ) {
        
        guard selectableJots.contains(
            where: { $0.id == jotID }
        ) else {
            return
        }
        
        // Close an active keyboard.
        
        if focusedField != nil {
            
            focusedField = nil
            
            finishDraft()
            
            removeEmptyJots()
        }
        
        if selectedJotIDs.contains(jotID) {
            
            selectedJotIDs.remove(jotID)
            
        } else {
            
            selectedJotIDs.insert(jotID)
        }
    }
    
    private func endSelection() {
        
        selectedJotIDs.removeAll()
        
        didCopySelection = false
    }
    
    private func toggleSelectAll() {
        
        if allJotsSelected {
            
            selectedJotIDs.removeAll()
            
        } else {
            
            selectedJotIDs = Set(
                selectableJots.map(\.id)
            )
        }
    }
    
    // MARK: - Copy Selected Jots
    
    private func copySelectedJots() {
        
        guard !selectedJots.isEmpty else {
            return
        }
        
        let combinedText = selectedJots
            .map(\.content)
            .joined(separator: "\n\n")
        
        UIPasteboard.general.string = combinedText
        
        didCopySelection = true
    }
    
    
    // MARK: - Continuous Writing
    
    private func handleDraftInput(
        _ newValue: String
    ) {
        
        // Return appended to the current thought.
        
        if newValue == draftContent + "\n" {
            
            if !isEmpty(draftContent) {
                
                advanceToNextJot()
                
            }
            
            return
        }
        
        // Normal typing and multiline paste.
        
        updateDraft(newValue)
    }
    
    private func advanceToNextJot() {
        
        guard focusedField == .draft,
              !isEmpty(draftContent) else {
            return
        }
        
        // The current thought is already persisted
        // through updateDraft().
        
        onSave()
        
        // Move the current draft into the Jot list.
        
        finishDraft()
        
        // Keep the same TextField focused.
        
        focusedField = .draft
        
        // Follow the new input position.
        
        scrollRequest += 1
    }
    
    // MARK: - Draft Persistence
    
    private func updateDraft(_ newValue: String) {
        
        draftContent = newValue
        
        // Never create an empty database record.
        
        if isEmpty(newValue) {
            
            if let existingDraft = draftJot {
                
                draftJot = nil
                
                modelContext.delete(existingDraft)
                
                onSave()
            }
            
            return
        }
        
        // Update the existing draft record.
        
        if let existingDraft = draftJot {
            
            existingDraft.content = newValue
            existingDraft.updatedAt = .now
            
            onSave()
            
            return
        }
        
        // Create a record on the first non-empty input.
        
        let nextPosition = (
            jots.map(\.position).max() ?? -1
        ) + 1
        
        let newJot = DailyJot(
            dayKey: dayKey,
            content: newValue,
            position: nextPosition
        )
        
        draftJot = newJot
        
        modelContext.insert(newJot)
        
        onSave()
    }
    
    // MARK: - Finish Draft
    
    private func finishDraft() {
        
        // Content is already persisted.
        // Reset only the temporary editor state.
        
        draftContent = ""
        draftJot = nil
    }
    
    // MARK: - Empty Record Cleanup
    
    private func removeEmptyJots() {
        
        let emptyJots = jots.filter { jot in
            
            isEmpty(jot.content) &&
            focusedField != .jot(jot.id) &&
            jot.id != draftJot?.id &&
            !jot.isDeleted
        }
        
        guard !emptyJots.isEmpty else {
            return
        }
        
        for jot in emptyJots {
            modelContext.delete(jot)
        }
        
        onSave()
    }
    
    // MARK: - Delete Jot
    
    private func deleteJot(_ jot: DailyJot) {
        
        if focusedField == .jot(jot.id) {
            focusedField = nil
        }
        
        modelContext.delete(jot)
        
        jotToDelete = nil
        
        onSave()
    }
    
    // MARK: - Footer
    
    
    // MARK: - Keyboard Accessory
    
    private var writingAccessory: some View {
        
        HStack(spacing: 12) {
            
            HStack(spacing: 6) {
                
                Image(systemName: "checkmark")
                    .font(.system(
                        size: 11,
                        weight: .medium
                    ))
                
                Text(
                    "\(jotCount) " +
                    (jotCount == 1 ? "jot" : "jots")
                )
                .font(.system(
                    size: 13,
                    weight: .medium
                ))
            }
            .foregroundStyle(
                AppTheme.secondaryText(
                    colorScheme
                )
            )
            .padding(.leading, 12)
            
            Spacer()
            
            Button {
                
                focusedField = nil
                
                finishDraft()
                
                removeEmptyJots()
                
                onSave()
                
            } label: {
                
                HStack(spacing: 8) {
                    
                    Image(
                        systemName:
                            "keyboard.chevron.compact.down"
                    )
                    .font(.system(
                        size: 15,
                        weight: .medium
                    ))
                    
                    Text("Done")
                        .font(.system(
                            size: 14,
                            weight: .semibold
                        ))
                }
                .foregroundStyle(AppTheme.obsidian)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(
                    AppTheme.lime,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done writing")
        }
        .padding(6)
        .glassEffect(
            .regular,
            in: Capsule()
        )
    }
}
#Preview {
    DailyJotsView()
        .modelContainer(
            for: DailyJot.self,
            inMemory: true
        )
}
