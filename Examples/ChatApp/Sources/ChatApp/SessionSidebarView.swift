import SwiftUI

/// Sidebar listant les sessions de conversation avec bouton de création
struct SessionSidebarView: View {

    var viewModel: ChatViewModel

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedSessionID },
            set: { newID in
                if let id = newID,
                   let session = viewModel.sessions.first(where: { $0.id == id }) {
                    viewModel.selectSession(session)
                }
            }
        )) {
            ForEach(viewModel.sessions) { session in
                SessionRowView(session: session)
                    .tag(session.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createNewSession()
                } label: {
                    Label("Nouveau chat", systemImage: "plus")
                }
                .help("Démarrer une nouvelle conversation")
            }
        }
    }
}

// MARK: - Ligne d'une session

private struct SessionRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(.callout)
                .lineLimit(2)
            Text(session.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
