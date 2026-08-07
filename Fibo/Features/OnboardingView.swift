import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canConnect: Bool {
        email.contains("@") && password.count >= 4 && store.state != .connecting
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    brand
                    hero
                    connectionCard
                    privacyNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            brandIcon
            Text("FIBO")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(1.2)
                .foregroundStyle(AppTheme.ink)
        }
    }

    private var brandIcon: some View {
        BrandMark(size: 46)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tes performances,\nsans le bruit.")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .tracking(-1.2)
            Text("Connecte Myfxbook pour suivre ton portefeuille, tes positions et ton historique depuis une seule app.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppTheme.secondary)
                .lineSpacing(3)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Connexion Myfxbook")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("Utilise les identifiants de ton compte Myfxbook.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
            }

            VStack(spacing: 12) {
                fieldContainer {
                    Image(systemName: "envelope")
                        .foregroundStyle(AppTheme.secondary)
                    TextField("Adresse e-mail", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldContainer {
                    Image(systemName: "lock")
                        .foregroundStyle(AppTheme.secondary)
                    Group {
                        if showPassword {
                            TextField("Mot de passe", text: $password)
                        } else {
                            SecureField("Mot de passe", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canConnect { connect() } }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.negative)
            }

            Button(action: connect) {
                HStack {
                    if store.state == .connecting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Connecter mon portefeuille")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(canConnect ? AppTheme.primary : AppTheme.primary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .disabled(!canConnect)
        }
        .appCard(padding: 20)
    }

    private var privacyNote: some View {
        Label {
            Text("Tes identifiants sont chiffrés dans le Keychain de l’iPhone. L’app est uniquement destinée à la consultation.")
        } icon: {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(AppTheme.positive)
        }
        .font(.caption)
        .foregroundStyle(AppTheme.secondary)
    }

    private func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) { content() }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            }
    }

    private func connect() {
        focusedField = nil
        Task { _ = await store.connect(email: email, password: password) }
    }
}
