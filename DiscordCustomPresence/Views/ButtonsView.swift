import SwiftUI

struct ButtonsView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.and.hand.point.up.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Buttons")
                .font(.title)
                .fontWeight(.semibold)

            Text("Configure buttons for your Discord presence.")
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .navigationTitle("Buttons")
    }
}
