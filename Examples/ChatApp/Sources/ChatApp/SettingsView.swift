import SwiftUI
import SwiftAIAgentCore

/// Sheet de configuration : provider, clé API et modèle
struct SettingsView: View {

    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var configurationError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Sélection du provider
                Section("Provider") {
                    Picker("Provider IA", selection: $viewModel.selectedProvider) {
                        Text("OpenAI").tag(AIProvider.openai)
                        Text("Anthropic").tag(AIProvider.anthropic)
                    }
                    .pickerStyle(.segmented)
                    // Réinitialise le modèle lors du changement de provider
                    .onChange(of: viewModel.selectedProvider) {
                        viewModel.selectedModel = viewModel.availableModels[0]
                    }
                }

                // Clé API
                Section("Authentification") {
                    SecureField("Clé API", text: $viewModel.apiKey)
                        .textContentType(.password)

                    if viewModel.selectedProvider == .openai {
                        Text("Obtenez votre clé sur platform.openai.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Obtenez votre clé sur console.anthropic.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Sélection du modèle
                Section("Modèle") {
                    Picker("Modèle", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.name) { model in
                            Text(model.name)
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)

                    // Infos sur le modèle sélectionné
                    HStack {
                        Label("Contexte max", systemImage: "text.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.selectedModel.maxTokens / 1000)k tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Affichage de l'erreur de configuration
                if let error = configurationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Configurer") {
                        applyConfiguration()
                    }
                    .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 380)
    }

    // MARK: - Actions

    private func applyConfiguration() {
        configurationError = nil
        viewModel.configure()

        if let error = viewModel.errorMessage {
            // L'erreur vient du ViewModel — on l'affiche localement dans la sheet
            configurationError = error
            viewModel.errorMessage = nil
        } else {
            dismiss()
        }
    }
}
