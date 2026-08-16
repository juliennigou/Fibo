import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DashboardStore
    @Environment(\.openURL) private var openURL
    @AppStorage(AppPreferenceKey.portfolioSplitEnabled) private var isPortfolioSplitEnabled = false
    @State private var showDisconnectConfirmation = false
    @State private var showPortfolioContributions = false

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

                        displaySection
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
            .sheet(isPresented: $showPortfolioContributions) {
                PortfolioContributionsView()
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

    private var displaySection: some View {
        settingsCard(title: "Affichage") {
            HStack(spacing: 13) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 35, height: 35)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Portefeuille partagé")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Swipe entre le total, ton père et toi")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Toggle("Portefeuille partagé", isOn: $isPortfolioSplitEnabled)
                    .labelsHidden()
                    .tint(AppTheme.primary)
            }
            .padding(.vertical, 9)

            if isPortfolioSplitEnabled {
                Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
                Button {
                    showPortfolioContributions = true
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 35, height: 35)
                            .background(AppTheme.primary.opacity(0.1))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Gérer les apports")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text("Montants et dates de versement")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPortfolioSplitEnabled)
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

private struct PortfolioContributionsView: View {
    @EnvironmentObject private var store: DashboardStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContribution: PortfolioContribution?
    @State private var isAddingContribution = false

    private var contributions: [PortfolioContribution] {
        store.portfolioContributions.sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.owner.rawValue < $1.owner.rawValue
            }
            return $0.date < $1.date
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Les gains de chaque journée sont répartis selon le capital de chacun présent à cette date.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                }

                Section("Historique") {
                    ForEach(contributions) { contribution in
                        Button {
                            selectedContribution = contribution
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: contribution.owner == .father ? "person.fill" : "person.crop.circle.fill")
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contribution.owner.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text(AppFormat.shortDate(contribution.date))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondary)
                                }
                                Spacer()
                                Text(AppFormat.currency(contribution.amount, code: store.account?.currency ?? "EUR"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                                    .sensitiveAmount()
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deletePortfolioContribution(id: contribution.id)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Apports de capital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingContribution = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingContribution) {
                PortfolioContributionEditor(contribution: nil)
            }
            .sheet(item: $selectedContribution) { contribution in
                PortfolioContributionEditor(contribution: contribution)
            }
        }
    }
}

private struct PortfolioContributionEditor: View {
    @EnvironmentObject private var store: DashboardStore
    @Environment(\.dismiss) private var dismiss

    let contribution: PortfolioContribution?
    @State private var owner: PortfolioOwner
    @State private var amount: Double
    @State private var date: Date

    init(contribution: PortfolioContribution?) {
        self.contribution = contribution
        _owner = State(initialValue: contribution?.owner ?? .personal)
        _amount = State(initialValue: contribution?.amount ?? 0)
        _date = State(initialValue: contribution?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Attribution") {
                    Picker("Propriétaire", selection: $owner) {
                        ForEach(PortfolioOwner.allCases) { owner in
                            Text(owner.title).tag(owner)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Apport") {
                    TextField(
                        "Montant",
                        value: $amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .sensitiveAmount()
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section {
                    Text("Cet apport participera aux gains à partir de la date choisie.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .navigationTitle(contribution == nil ? "Nouvel apport" : "Modifier l’apport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        if let contribution {
                            store.updatePortfolioContribution(
                                id: contribution.id,
                                owner: owner,
                                amount: amount,
                                date: date
                            )
                        } else {
                            store.addPortfolioContribution(owner: owner, amount: amount, date: date)
                        }
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}
