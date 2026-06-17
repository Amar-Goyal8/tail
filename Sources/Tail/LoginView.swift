import SwiftUI
import Supabase

// Switches between the login screen and the app based on auth state.
struct RootView: View {
    @ObservedObject var auth = AuthManager.shared
    let model: AppModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if auth.loading {
                ProgressView().controlSize(.large).tint(Theme.accent)
            } else if auth.signedIn {
                MainWindowView(model: model)
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct LoginView: View {
    @ObservedObject var auth = AuthManager.shared
    @State private var email = ""
    @State private var sent = false
    @State private var busy = false
    @State private var err: String?

    var body: some View {
        ZStack {
            Theme.bgGrad.ignoresSafeArea()
            VStack(spacing: 20) {
                ReticleMark(size: 56)
                Text("TAIL").font(Theme.display(28)).foregroundStyle(Theme.text).tracking(4)
                Text("Sign in to capture, organize and share your clips.")
                    .font(Theme.ui(13)).foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center).frame(width: 300)

                VStack(spacing: 10) {
                    provider("Continue with Discord", "bubble.left.fill", .discord)
                    provider("Continue with Google", "globe", .google)
                }.frame(width: 300)

                HStack {
                    Rectangle().fill(Theme.stroke).frame(height: 1)
                    Text("OR").font(Theme.mono(10)).foregroundStyle(Theme.textFaint)
                    Rectangle().fill(Theme.stroke).frame(height: 1)
                }.frame(width: 300)

                VStack(spacing: 10) {
                    if sent {
                        Label("Check your email for the sign-in link", systemImage: "envelope.badge")
                            .font(Theme.ui(12)).foregroundStyle(Theme.accent)
                    } else {
                        TextField("you@email.com", text: $email)
                            .textFieldStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.text)
                            .padding(11).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.R.sm))
                            .overlay(RoundedRectangle(cornerRadius: Theme.R.sm).stroke(Theme.stroke))
                        Button {
                            busy = true; err = nil
                            Task {
                                do { try await auth.signInEmail(email); sent = true }
                                catch { err = error.localizedDescription }
                                busy = false
                            }
                        } label: { Text(busy ? "Sending…" : "Email me a magic link").frame(maxWidth: .infinity) }
                        .buttonStyle(TailButtonStyle(kind: .ghost, full: true))
                        .disabled(busy || email.isEmpty)
                    }
                }.frame(width: 300)

                if let err { Text(err).font(Theme.ui(11)).foregroundStyle(Theme.live).frame(width: 300) }
            }
        }
    }

    private func provider(_ title: String, _ icon: String, _ p: Provider) -> some View {
        Button {
            Task { try? await auth.signIn(p) }
        } label: {
            HStack { Image(systemName: icon); Text(title); Spacer() }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TailButtonStyle(kind: .primary, full: true))
    }
}
