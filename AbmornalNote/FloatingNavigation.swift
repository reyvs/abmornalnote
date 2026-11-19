
import SwiftUI

// MARK: - App Pages

enum AppPage: String, CaseIterable {
    case jots = "Jots"
    case day = "Day"
    case calendar = "Calendar"
    case spaces = "Spaces"
    
    var icon: String {
        switch self {
        case .jots:
            return "square.and.pencil"
        case .day:
            return "sunrise"
        case .calendar:
            return "calendar"
        case .spaces:
            return "square.stack"
        }
    }
}

// MARK: - Floating Navigation

struct FloatingNavigation: View {
    
    @Binding var selection: AppPage
    
    var onCapture: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            
            tabButton(.jots)
            
            tabButton(.day)
            
            captureButton
            
            tabButton(.calendar)
            
            tabButton(.spaces)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 16)
        .sensoryFeedback(.selection, trigger: selection)
    }
    
    // MARK: - Navigation Button
    
    private func tabButton(_ page: AppPage) -> some View {
        
        let isSelected = selection == page
        
        return Button {
            withAnimation(.spring(
                response: 0.35,
                dampingFraction: 0.75
            )) {
                selection = page
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: page.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(
                        isSelected ? AppTheme.obsidian : Color.primary
                    )
                    .frame(width: 40, height: 38)
                    .background {
                        Capsule()
                            .fill(
                                isSelected
                                ? AppTheme.lime
                                : Color.clear
                            )
                    }
                
                Text(page.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isSelected ? Color.primary : Color.secondary
                    )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.rawValue)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }
    
    // MARK: - Capture Button
    
    private var captureButton: some View {
        Button(action: onCapture) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.obsidian)
                    .frame(width: 44, height: 38)
                    .background(AppTheme.lilac, in: Capsule())
                
                Text("Capture")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick capture")
    }
}
