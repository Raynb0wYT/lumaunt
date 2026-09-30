import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        MainView(appState: appState)
    }
}

#Preview {
    ContentView()
}
