
import SwiftUI
import SwiftData

struct QuickJotCaptureView: View {

    // MARK: - Environment

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.modelContext)
    private var modelContext

    // MARK: - State

    @State private var content = ""
    @State private var saveError: String?
    @State private var showSaveError = false

    @FocusState private var isWriting: Bool

    let onClose: () -> Void

    private var cleanContent: String {
        content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSave: Bool {
        !cleanContent.isEmpty
    }

    // MARK: - Main View

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Page Title

            Text("Quick jot.")
                .font(.system(
                    size: 42,
                    weight: .medium
                ))
                .tracking(-1.8)
                .foregroundStyle(
                    AppTheme.text(colorScheme)
                )

            // Destination

            HStack(spacing: 8) {

                Image(systemName: "calendar")

                Text("Saving to today's jots")
            }
            .font(.system(size: 14))
            .foregroundStyle(
                AppTheme.secondaryText(colorScheme)
            )

            Divider()

            // Writing Area

            ZStack(alignment: .topLeading) {

                if content.isEmpty {

                    Text("What's on your mind?")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            AppTheme.secondaryText(
                                colorScheme
                            )
                            .opacity(0.7)
                        )
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $content)
                    .font(.system(size: 18))
                    .lineSpacing(5)
                    .foregroundStyle(
                        AppTheme.text(colorScheme)
                    )
                    .tint(
                        colorScheme == .dark
                        ? AppTheme.lime
                        : AppTheme.forestBlack
                    )
                    .scrollContentBackground(.hidden)
                    .focused($isWriting)
                    .accessibilityLabel("Quick jot content")
            }
            .frame(maxHeight: .infinity)

            // Save Button

            saveButton
        }
        .padding(AppTheme.screenPadding)
        .background {
            AppTheme.background(colorScheme)
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .confirmationAction
            ) {
                Button("Cancel") {
                    onClose()
                }
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
            }
        }
        .onAppear {
            isWriting = true
        }
        .alert(
            "Unable to save jot",
            isPresented: $showSaveError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                saveError ?? "Please try again."
            )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveJot()
        } label: {

            HStack(spacing: 10) {

                Image(systemName: "checkmark")
                    .font(.system(
                        size: 15,
                        weight: .semibold
                    ))

                Text("Save jot")
                    .font(.system(
                        size: 16,
                        weight: .semibold
                    ))
            }
            .foregroundStyle(
                AppTheme.obsidian
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                AppTheme.lime,
                in: Capsule()
            )
            .opacity(canSave ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: - Save to SwiftData

    private func saveJot() {

        guard canSave else {
            return
        }

        let todayKey = JotDay.key()

        var descriptor = FetchDescriptor<DailyJot>(
            predicate: #Predicate<DailyJot> { jot in
                jot.dayKey == todayKey
            },
            sortBy: [
                SortDescriptor(
                    \DailyJot.position,
                    order: .reverse
                )
            ]
        )

        descriptor.fetchLimit = 1

        do {

            let latestJots = try modelContext.fetch(
                descriptor
            )


            // Reuse the last empty jot if available.

            if let lastJot = latestJots.first,
               lastJot.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {

                let previousContent = lastJot.content
                let previousUpdatedAt = lastJot.updatedAt

                lastJot.content = cleanContent
                lastJot.updatedAt = .now

                do {
                    try modelContext.save()
                } catch {
                    lastJot.content = previousContent
                    lastJot.updatedAt = previousUpdatedAt
                    throw error
                }

            } else {

                // Create a new jot only when needed.

                let nextPosition =
                    (latestJots.first?.position ?? -1) + 1

                let jot = DailyJot(
                    dayKey: todayKey,
                    content: cleanContent,
                    position: nextPosition
                )

                modelContext.insert(jot)

                do {
                    try modelContext.save()
                } catch {
                    modelContext.delete(jot)
                    throw error
                }
            }


            isWriting = false

            onClose()

        } catch {

            saveError = error.localizedDescription

            showSaveError = true
        }
    }
}

#Preview {
    NavigationStack {
        QuickJotCaptureView(
            onClose: {}
        )
    }
    .modelContainer(
        for: DailyJot.self,
        inMemory: true
    )
}
