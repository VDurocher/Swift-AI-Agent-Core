import SwiftUI

/// Vue racine de l'application — NavigationSplitView avec sidebar de sessions et détail du chat
struct ContentView: View {

    @State private var viewModel = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SessionSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            ChatView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Paramètres", systemImage: "gear")
                }
                .help("Configurer la clé API et le modèle")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        // Indicateur visuel si l'agent n'est pas encore configuré
        .overlay(alignment: .top) {
            if !viewModel.isConfigured {
                ConfigurationBannerView {
                    showSettings = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.isConfigured)
            }
        }
    }
}

// MARK: - Bannière d'invitation à configurer

private struct ConfigurationBannerView: View {
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
            Text("Configurez votre clé API pour commencer")
                .font(.callout)
            Spacer()
            Button("Configurer", action: onTap)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
