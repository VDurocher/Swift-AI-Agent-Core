# ChatApp Demo

App macOS de démonstration de **Swift-AI-Agent-Core**.

## Prérequis

- macOS 14 (Sonoma) ou supérieur
- Xcode 15+ ou Swift 5.9+
- Une clé API OpenAI (`platform.openai.com`) ou Anthropic (`console.anthropic.com`)

## Lancer l'application

```bash
cd Examples/ChatApp
swift run
```

## Fonctionnalités démontrées

- **Envoi classique** — appel `send(messages:)` avec réponse complète
- **Streaming** — appel `stream(messages:)` avec affichage token par token
- **Multi-sessions** — gestion de plusieurs conversations simultanées
- **Deux providers** — OpenAI (GPT-4o, GPT-4 Turbo…) et Anthropic (Claude Sonnet 4.6, Claude 3.5…)
- **Rendu Markdown** — les réponses avec code ou mise en forme s'affichent correctement

## Architecture

```
Sources/ChatApp/
├── ChatApp.swift           # Point d'entrée @main
├── ChatSession.swift       # Modèle de session
├── ChatViewModel.swift     # @Observable @MainActor ViewModel principal
├── ContentView.swift       # NavigationSplitView racine
├── SessionSidebarView.swift # Sidebar des conversations
├── ChatView.swift          # Vue principale du chat
├── MessageBubble.swift     # Composant bulle de message
├── SettingsView.swift      # Sheet de configuration
└── TypingIndicator.swift   # Animation de typing
```

## Pattern Swift 6

Ce projet utilise Swift 6 avec concurrence stricte (`SWIFT_STRICT_CONCURRENCY = complete`) :

- `@Observable` au lieu de `ObservableObject`
- `@MainActor` sur le ViewModel
- `AsyncThrowingStream` pour le streaming
- `.task` au lieu de `.onAppear` pour les appels async
