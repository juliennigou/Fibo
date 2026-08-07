import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DashboardStore
    @Environment(\.openURL) private var openURL
    @State private var showDisconnectConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 20) {
                        AppHeader(title: "Réglages", subtitle: "Connexion et confidentialité")

                        if let account = store.account {
                            accountCard(account)
                        }

                        if store.accounts.count > 1 {
                            accountPicker
                        }

                        dataSection
                        securitySection
                        aboutSection

                        Button(role: .destructive) {
                            showDisconnectConfirmation = true
                        } label: {
                            Label("Déconnecter Myfxbook", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppTheme.negative.opacity(0.09))
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Déconnecter le portefeuille ?",
                isPresented: $showDisconnectConfirmation,
                titleVisibility: .visible
            ) {
                Button("Déconnecter et effacer les données locales", role: .destructive) {
                    Task { await store.disconnect() }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les identifiants du Keychain et le cache hors ligne seront supprimés de cet iPhone.")
            }
        }
    }

    private func accountCard(_ account: TradingAccount) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.primarySoft)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.name.isEmpty ? "Compte Myfxbook" : account.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Compte \(account.accountNumber) · \(account.currency)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                StatusPill(
                    text: account.isDemo ? "Démo" : "Live",
                    color: account.isDemo ? AppTheme.warning : AppTheme.positive,
                    symbol: "circle.fill"
                )
            }

            Divider().overlay(AppTheme.cardLine)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Serveur").font(.caption).foregroundStyle(AppTheme.secondary)
                    Text(account.broker).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Dernière donnée").font(.caption).foregroundStyle(AppTheme.secondary)
                    Text(account.lastUpdate.map(AppFormat.relativeDate) ?? "Inconnue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .appCard()
    }

    private var accountPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Compte affiché")
            ForEach(store.accounts) { account in
                Button {
                    Task { await store.selectAccount(account.id) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.name).font(.subheadline.weight(.semibold))
                            Text("\(account.accountNumber)").font(.caption).foregroundStyle(AppTheme.secondary)
                        }
                        Spacer()
                        if account.id == store.account?.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.primary)
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .appCard()
    }

    private var dataSection: some View {
        settingsCard(title: "Données") {
            settingsRow(symbol: "arrow.clockwise", tint: AppTheme.primary, title: "Synchroniser maintenant") {
                Task { await store.refresh() }
            }
            Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
            settingsRow(symbol: "safari.fill", tint: AppTheme.primary, title: "Ouvrir Myfxbook") {
                if let url = URL(string: "https://www.myfxbook.com") { openURL(url) }
            }
            Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
            HStack(spacing: 13) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundStyle(AppTheme.positive)
                    .frame(width: 35, height: 35)
                    .background(AppTheme.positive.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Actualisation automatique")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("À l’ouverture et périodiquement selon iOS")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Image(systemName: "checkmark").foregroundStyle(AppTheme.positive)
            }
            .padding(.vertical, 10)
        }
    }

    private var securitySection: some View {
        settingsCard(title: "Sécurité") {
            infoRow(
                symbol: "key.fill",
                tint: AppTheme.positive,
                title: "Identifiants protégés",
                detail: "Keychain · cet iPhone uniquement"
            )
            Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
            infoRow(
                symbol: "eye.fill",
                tint: AppTheme.primary,
                title: "Consultation uniquement",
                detail: "Aucune fonction de passage d’ordre"
            )
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "À propos") {
            infoRow(
                symbol: "chart.xyaxis.line",
                tint: AppTheme.primary,
                title: "Fibo Dashboard",
                detail: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
            )
            Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
            infoRow(
                symbol: "network",
                tint: AppTheme.warning,
                title: "Source",
                detail: "API personnelle Myfxbook"
            )
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondary)
                .padding(.horizontal, 8)
            VStack(spacing: 0) { content() }
                .appCard(padding: 10)
        }
    }

    private func settingsRow(symbol: String, tint: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 35, height: 35)
                    .background(tint.opacity(0.1))
                    .clipShape(Circle())
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.secondary)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 35, height: 35)
                .background(tint.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                Text(detail).font(.caption).foregroundStyle(AppTheme.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 9)
    }
}
