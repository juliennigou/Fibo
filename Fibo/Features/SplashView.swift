import SwiftUI

/// Écran de chargement : fond violet primaire, la spirale du logo Fibo se dessine
/// comme le serpent du jeu Snake, puis se referme sur le logo complet.
struct SplashView: View {
    /// Les données sont prêtes : la vue joue son final puis appelle `onFinished`.
    var isReady: Bool
    var onFinished: () -> Void

    /// Durée minimale d'affichage, pour que l'animation soit lisible.
    private let minimumDuration: TimeInterval = 1.9
    /// Durée du final (la spirale se dessine entièrement).
    private let finaleDuration: TimeInterval = 0.9
    /// Durée d'un tour complet du serpent.
    private let lapDuration: TimeInterval = 2.4
    /// Longueur du serpent, en fraction de la spirale.
    private let bodyLength: Double = 0.26

    @State private var startDate = Date()
    @State private var finaleStart: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSince(startDate)
            let finale = finaleProgress(at: now)

            ZStack {
                background

                SnakeSpiral(
                    phase: elapsed / lapDuration,
                    bodyLength: bodyLength,
                    finale: finale
                )
                .padding(40)
                .frame(maxWidth: 260, maxHeight: 260)
                .scaleEffect(1 + 0.06 * finale * (1 - finale) * 4)

                VStack {
                    Spacer()
                    Text("Fibo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .tracking(6)
                    Text("Synchronisation du portefeuille…")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 6)
                        .opacity(1 - finale)
                        .padding(.bottom, 54)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: isReady) { _, ready in
            if ready { scheduleFinale() }
        }
        .onAppear {
            startDate = Date()
            if isReady { scheduleFinale() }
        }
    }

    private var background: some View {
        ZStack {
            AppTheme.primary
            RadialGradient(
                colors: [AppTheme.primary.opacity(0.0), AppTheme.primaryDeep.opacity(0.85)],
                center: .center,
                startRadius: 90,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    /// 0 → serpent en boucle, 1 → spirale entièrement dessinée.
    private func finaleProgress(at date: Date) -> Double {
        guard let finaleStart else { return 0 }
        let t = date.timeIntervalSince(finaleStart) / finaleDuration
        return min(max(t, 0), 1)
    }

    private func scheduleFinale() {
        guard finaleStart == nil else { return }
        let remaining = max(0, minimumDuration - Date().timeIntervalSince(startDate))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard finaleStart == nil else { return }
            finaleStart = Date()
            try? await Task.sleep(nanoseconds: UInt64((finaleDuration + 0.15) * 1_000_000_000))
            onFinished()
        }
    }
}

/// Dessine la spirale du logo : une piste discrète, un serpent lumineux qui la
/// parcourt, et sa tête. `finale` ramène le serpent à la spirale complète.
private struct SnakeSpiral: View {
    var phase: Double
    var bodyLength: Double
    var finale: Double

    var body: some View {
        Canvas { context, size in
            let path = FiboSpiral.path(in: CGRect(origin: .zero, size: size))
            let lineWidth = min(size.width, size.height) * 0.065

            // Piste : la spirale complète, en filigrane.
            context.stroke(
                path,
                with: .color(AppTheme.lime.opacity(0.13 + 0.87 * finale)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            guard finale < 1 else { return }

            let head = phase.truncatingRemainder(dividingBy: 1)
            // Le corps s'étire jusqu'à couvrir toute la spirale pendant le final.
            let length = bodyLength + (1 - bodyLength) * finale
            let tail = head - length

            var body = Path()
            if tail < 0 {
                body.addPath(path.trimmedPath(from: 0, to: head))
                body.addPath(path.trimmedPath(from: max(0, 1 + tail), to: 1))
            } else {
                body.addPath(path.trimmedPath(from: tail, to: head))
            }

            // Halo puis corps du serpent.
            context.stroke(
                body,
                with: .color(AppTheme.lime.opacity(0.28 * (1 - finale))),
                style: StrokeStyle(lineWidth: lineWidth * 2.1, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                body,
                with: .color(AppTheme.lime),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            // Tête du serpent.
            if let headPoint = path.trimmedPath(from: max(0, head - 0.004), to: max(0.004, head)).currentPoint {
                let side = lineWidth * (1.45 - 0.45 * finale)
                let rect = CGRect(
                    x: headPoint.x - side / 2,
                    y: headPoint.y - side / 2,
                    width: side,
                    height: side
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: side * 0.34, style: .continuous),
                    with: .color(AppTheme.lime)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .drawingGroup()
    }
}

/// Spirale logarithmique reprenant le tracé du logo Fibo.
enum FiboSpiral {
    static let turns: Double = 2.5
    /// Rapport entre le rayon extérieur et le rayon du premier tour visible.
    static let growth: Double = 40

    static func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let thetaMax = turns * 2 * .pi
        let k = log(growth) / thetaMax
        let a = outerRadius / exp(k * thetaMax)
        // L'extrémité extérieure pointe vers le haut à droite, comme sur le logo.
        let phase0 = -Double.pi / 4 - thetaMax

        var path = Path()
        let steps = 700
        for step in 0...steps {
            let theta = thetaMax * Double(step) / Double(steps)
            let radius = a * exp(k * theta)
            let angle = phase0 + theta
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

#Preview {
    SplashView(isReady: false, onFinished: {})
}
