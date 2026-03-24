import SwiftUI

// Point d'entrée principal de l'application de démonstration
@main
struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
    }
}
