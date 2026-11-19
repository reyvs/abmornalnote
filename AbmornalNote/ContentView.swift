
import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(
                red: 17.0 / 255.0,
                green: 17.0 / 255.0,
                blue: 17.0 / 255.0
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("abmornal : note")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        Color(
                            red: 196.0 / 255.0,
                            green: 246.0 / 255.0,
                            blue: 77.0 / 255.0
                        )
                    )

                Text("Make room for your thoughts.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

#Preview {
    ContentView()
}
