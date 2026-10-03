import SwiftUI

struct ImagePrivacyView: View {
    @Bindable var appState: AppState
    @AppStorage("allowHostedImageUploads") private var allowUploads = false
    @AppStorage("hostedImageRetentionDays") private var retentionDays = 30
    @State private var store = HostedImageStore.shared
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Image Privacy", systemImage: "hand.raised")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Toggle("Allow local images to be uploaded when I apply a presence", isOn: $allowUploads)
            Text("Discord needs a public image URL. Anyone with that URL can view the image. Selecting or pasting an image keeps it on this Mac until you apply it. Turning uploads off does not delete existing uploads.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Delete new uploads after", selection: $retentionDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }
            Text("Expiry starts when an image is uploaded; daily cleanup deletes it within 24 hours of expiry. This choice applies to new uploads. An expired image can disappear from Discord; apply your local image again to upload a fresh copy. Other services may keep copies of public images.")
                .font(.caption).foregroundStyle(.secondary)
            if !store.images.isEmpty {
                Text("\(store.images.count) managed upload(s). Earliest expiry: \(store.images.map(\.expiresAt).min()!.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
            }
            Button("Delete My Hosted Images…", role: .destructive) { confirmDelete = true }
                .disabled(store.images.isEmpty || store.isDeleting || appState.isApplyingPresence)
            if store.isDeleting { ProgressView("Deleting hosted images…") }
            if let message = store.message { Text(message).font(.caption).textSelection(.enabled) }
            Text("Deletion controls cover uploads made with this version on this Mac. Older uploads and images hosted elsewhere cannot be deleted here.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
        .alert("Delete Your Hosted Images?", isPresented: $confirmDelete) {
            Button("Delete Images", role: .destructive) {
                Task {
                    let deleted = await store.deleteAll().map(\.absoluteString)
                    if !deleted.isEmpty && appState.discord.hasActivePresence {
                        appState.clearPresence()
                    }
                    if deleted.contains(appState.presence.largeImage) { appState.presence.largeImage = "" }
                    if deleted.contains(appState.presence.smallImage) { appState.presence.smallImage = "" }
                    appState.refreshStorageInformation()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently delete \(store.images.count) uploaded image(s) owned by this installation. Your active presence will be disabled. Local originals stay on this Mac.")
        }
    }
}
