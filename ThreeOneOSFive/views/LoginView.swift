import SwiftUI

struct LoginView: View {
    @ObservedObject var session: IOSKeySession
    @State private var keyInput = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                VStack(spacing: 6) {
                    Text("EXTERNAL")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.75), Color(white: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .white.opacity(0.25), radius: 12)

                    Text("SYSTEM")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.75), Color(white: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .white.opacity(0.25), radius: 12)

                    Text("BY LEVI")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(4)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.top, 2)
                }
                .padding(.bottom, 48)

                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))

                    TextField("", text: $keyInput, prompt: Text("PROXY–XXXX–XXX").foregroundColor(Color.white.opacity(0.35)))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($keyFocused)
                        .submitLabel(.go)
                        .onSubmit { session.submit(keyInput) }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 28)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("iOS \(UIDevice.current.systemVersion) soportado")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.top, 14)

                Button {
                    session.submit(keyInput)
                } label: {
                    HStack(spacing: 8) {
                        if session.isChecking {
                            ProgressView().tint(.black)
                        }
                        Text(session.isChecking ? "Verificando…" : "Continuar")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.35), radius: 16)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .disabled(session.isChecking || keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(session.isChecking || keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 14)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("SOPORTADO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.35))

                    Text("iOS 17.0–17.7 · 18.0–18.7.1 · 26.0–26.6.1 · 27 betas 1–4")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
    }
}
