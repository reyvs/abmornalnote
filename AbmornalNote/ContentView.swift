
import SwiftUI
import SwiftData

struct ContentView: View {
    
    // MARK: - Navigation State
    
    @State private var selectedPage: AppPage = .jots
    @State private var activeSheet: AppSheet?
    
    @AppStorage("appAppearance")
    private var appearance = "system"
    
    @Environment(\.colorScheme)
    private var systemColorScheme
    
    private enum AppSheet: String, Identifiable {
        case settings
        case capture
        
        var id: String { rawValue }
    }
    
    // MARK: - Appearance
    
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    private var activeScheme: ColorScheme {
        preferredScheme ?? systemColorScheme
    }
    
    // MARK: - Main View
    
    var body: some View {
        VStack(spacing: 0) {
            
            header
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pageContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background {
            AppTheme.background(activeScheme)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingNavigation(
                selection: $selectedPage,
                onCapture: {
                    activeSheet = .capture
                }
            )
            .padding(.bottom, 8)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                settingsSheet
            case .capture:
                captureSheet
            }
        }
        .preferredColorScheme(preferredScheme)
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("abmornal : note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    AppTheme.secondaryText(activeScheme)
                )
            
            Spacer()
            
            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.text(activeScheme))
                    .frame(width: 44, height: 44)
                    .glassEffect(
                        .regular.interactive(),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }
    
    // MARK: - Page Routing
    
    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .jots:
            dailyJotsPage
        case .day:
            placeholderPage(
                title: "Your day.",
                subtitle: "Make today count.",
                icon: "sunrise",
                message: "Your daily overview will appear here."
            )
        case .calendar:
            placeholderPage(
                title: "Calendar.",
                subtitle: "Your time, your way.",
                icon: "calendar",
                message: "Your schedule will appear here."
            )
        case .spaces:
            placeholderPage(
                title: "Spaces.",
                subtitle: "A space for every part of life.",
                icon: "square.stack",
                message: "Your workspaces will appear here."
            )
        }
    }
    

    // MARK: - Daily Jots
    
    private var dailyJotsPage: some View {
        DailyJotsView()
    }

    
    // MARK: - Temporary Pages
    
    private func placeholderPage(
        title: String,
        subtitle: String,
        icon: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            pageTitle(title)
            
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(
                    AppTheme.secondaryText(activeScheme)
                )
            
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(
                        AppTheme.text(activeScheme)
                    )
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(
                        AppTheme.secondaryText(activeScheme)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background {
                RoundedRectangle(
                    cornerRadius: AppTheme.cardRadius
                )
                .fill(AppTheme.surface(activeScheme))
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Reusable Title
    
    private func pageTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(
                size: 42,
                weight: .medium,
                design: .default
            ))
            .tracking(-1.8)
            .foregroundStyle(AppTheme.text(activeScheme))
            .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Settings Sheet
    
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker(
                        "Theme",
                        selection: $appearance
                    ) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("About") {
                    LabeledContent(
                        "Application",
                        value: "abmornal : note"
                    )
                    
                    LabeledContent(
                        "Version",
                        value: "0.2.0"
                    )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Capture Sheet
    
    private var captureSheet: some View {
        NavigationStack {
            List {
                Section("Capture anything") {
                    captureRow(
                        "Quick jot",
                        icon: "square.and.pencil"
                    )
                    
                    captureRow(
                        "Organize with AI",
                        icon: "sparkles"
                    )
                    
                    captureRow(
                        "New task",
                        icon: "checklist"
                    )
                    
                    captureRow(
                        "New event",
                        icon: "calendar.badge.plus"
                    )
                    
                    captureRow(
                        "New note",
                        icon: "doc.text"
                    )
                }
                
                Section {
                    Text(
                        "Capture features will be enabled in the next development phases."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Quick capture.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func captureRow(
        _ title: String,
        icon: String
    ) -> some View {
        Label(title, systemImage: icon)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: DailyJot.self,
            inMemory: true
        )
}
