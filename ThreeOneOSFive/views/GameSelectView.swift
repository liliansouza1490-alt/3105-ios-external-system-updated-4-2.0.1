import SwiftUI

enum SelectedGame: String, CaseIterable {
    case freeFire = "FF NORMAL"
    case freeFireMax = "FF MAX"

    var assetName: String {
        switch self {
        case .freeFire: return "FreeFireNormal"
        case .freeFireMax: return "FreeFireMax"
        }
    }

    var subtitle: String {
        switch self {
        case .freeFire: return "Free Fire clássico"
        case .freeFireMax: return "Free Fire Max"
        }
    }
}

struct GameSelectView: View {
    @Binding var selectedGame: SelectedGame?
    @State private var highlight: SelectedGame = .freeFire

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("EXTERNAL SYSTEM")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Selecione o jogo")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.top, 40)

                VStack(spacing: 14) {
                    ForEach(SelectedGame.allCases, id: \.self) { game in
                        Button {
                            highlight = game
                        } label: {
                            HStack(spacing: 14) {
                                Image(game.assetName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(game.subtitle)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }

                                Spacer()

                                Image(systemName: highlight == game ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(highlight == game ? .white : Color.white.opacity(0.25))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(white: highlight == game ? 0.14 : 0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        highlight == game ? Color.white.opacity(0.35) : Color.white.opacity(0.06),
                                        lineWidth: highlight == game ? 1.2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)

                Spacer()

                Button {
                    selectedGame = highlight
                } label: {
                    Text("Continuar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.25), radius: 14, x: 0, y: 0)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
    }
}
