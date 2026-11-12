import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var externalStore: ExternalPatchStore
    @EnvironmentObject private var keySession: IOSKeySession
    @AppStorage("external.selectedGame") private var selectedGameRaw: String = ""
    @State private var hasPassedCalculator = false
    @State private var selectedGame: SelectedGame?

    var body: some View {
        Group {
            if !hasPassedCalculator {
                CalculadoraIPhoneView(onContinue: {
                    hasPassedCalculator = true
                    keySession.passCalculatorGate()
                })
            } else if !keySession.isAuthenticated {
                LoginView(session: keySession)
            } else if selectedGame == nil {
                GameSelectView(selectedGame: Binding(
                    get: { selectedGame },
                    set: { newValue in
                        selectedGame = newValue
                        if let g = newValue {
                            selectedGameRaw = g.rawValue
                        }
                    }
                ))
            } else {
                ExternalPatchesView()
                    .environmentObject(externalStore)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let g = SelectedGame(rawValue: selectedGameRaw) {
                selectedGame = g
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .externalKeyCleared)) { _ in
            keySession.logout()
            selectedGame = nil
            selectedGameRaw = ""
        }
    }
}
