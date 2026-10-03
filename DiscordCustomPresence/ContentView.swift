import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        MainView(
            appState: appState
        )
    }
}
