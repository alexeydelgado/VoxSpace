import SwiftUI
import AppKit

// MARK: - Enums

enum Emotion: String, CaseIterable, Codable {
    case frio = "Frío"
    case cercano = "Cálido"
    case tenso = "Tenso"
    case vacio = "Vacío"
}

enum Role: String, CaseIterable, Codable {
    case lead = "Principal"
    case back = "Coros"
    case adlib = "Adlibs"
    case textura = "Textura"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spanish:
            return "Español"
        case .english:
            return "English"
        }
    }
}

// MARK: - Modelo

struct HistoryItem: Identifiable, Equatable, Codable {
    let id: UUID
    let bpm: Double
    let multiplier: Double
    let mode: String
    let emotion: Emotion
    let role: Role
    let preDelay: Int
    let decay: Int
    let decayVal: String
    let send: String
    let eq: String
    let note: String

    init(
        id: UUID = UUID(),
        bpm: Double,
        multiplier: Double,
        mode: String,
        emotion: Emotion,
        role: Role,
        preDelay: Int,
        decay: Int,
        decayVal: String,
        send: String,
        eq: String,
        note: String
    ) {
        self.id = id
        self.bpm = bpm
        self.multiplier = multiplier
        self.mode = mode
        self.emotion = emotion
        self.role = role
        self.preDelay = preDelay
        self.decay = decay
        self.decayVal = decayVal
        self.send = send
        self.eq = eq
        self.note = note
    }
}

private struct RootContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollInteractionObserver: NSViewRepresentable {
    let onUserScroll: () -> Void
    let onOverflowChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserScroll: onUserScroll, onOverflowChange: onOverflowChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onAttach = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.attach(to: view)
        }
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onUserScroll = onUserScroll
        context.coordinator.onOverflowChange = onOverflowChange
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class TrackingNSView: NSView {
        var onAttach: (() -> Void)?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            onAttach?()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onAttach?()
        }
    }

    final class Coordinator {
        var onUserScroll: () -> Void
        var onOverflowChange: (Bool) -> Void
        private weak var observedScrollView: NSScrollView?
        private weak var observedView: NSView?
        private var localMonitor: Any?
        private var boundsObserver: NSObjectProtocol?
        private var frameObserver: NSObjectProtocol?

        init(onUserScroll: @escaping () -> Void, onOverflowChange: @escaping (Bool) -> Void) {
            self.onUserScroll = onUserScroll
            self.onOverflowChange = onOverflowChange
        }

        func attach(to view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                let scrollView = view.enclosingScrollView
                    ?? sequence(first: view.superview, next: { $0?.superview })
                        .compactMap { $0 as? NSScrollView }
                        .first

                guard observedScrollView !== scrollView else { return }

                detach()
                observedScrollView = scrollView
                observedView = view

                guard scrollView != nil else { return }
                let clipView = scrollView!.contentView
                clipView.postsBoundsChangedNotifications = true
                scrollView!.documentView?.postsFrameChangedNotifications = true

                boundsObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    self?.reportOverflow()
                }

                frameObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: scrollView!.documentView,
                    queue: .main
                ) { [weak self] _ in
                    self?.reportOverflow()
                }

                reportOverflow()

                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    guard let self else { return event }
                    guard
                        let observedView = self.observedView,
                        let observedScrollView = self.observedScrollView,
                        let window = observedView.window,
                        event.window === window
                    else {
                        return event
                    }

                    let locationInWindow = event.locationInWindow
                    let locationInScrollView = observedScrollView.convert(locationInWindow, from: nil)
                    guard observedScrollView.bounds.contains(locationInScrollView) else {
                        return event
                    }

                    self.onUserScroll()
                    return event
                }
            }
        }

        private func reportOverflow() {
            guard let scrollView = observedScrollView else { return }
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let viewportHeight = scrollView.contentView.bounds.height
            onOverflowChange(documentHeight > viewportHeight)
        }

        func detach() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
                self.boundsObserver = nil
            }
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
                self.frameObserver = nil
            }
            observedView = nil
            observedScrollView = nil
        }

        deinit {
            detach()
        }
    }
}

// MARK: - Motor

fileprivate func generarReverbInteligente(
    bpm: Double,
    size: String,
    emotion: Emotion,
    role: Role
) -> (preDelay: Double, decay: Double, send: String, eq: String, note: String) {

    let quarter = 60000 / bpm

    // Modo clásico: fórmula directa del usuario
    if size == "Modo clásico" {
        let baseDecayMs = quarter / 2
        let pre = baseDecayMs / 6
        let decay = baseDecayMs / 1000
        
        let send = "-15 dB"
        let eq = "Flat"
        let note = "Modo clásico (tempo directo)"
        
        return (pre, decay, send, eq, note)
    }

    let pre: Double
    switch size {
    case "Voz íntima": pre = max(20, quarter / 64)
    case "Natural", "Normal": pre = quarter / 32
    case "Grande": pre = quarter / 16
    default: pre = quarter / 32
    }

    // Tiempo base musical
    let bar = quarter * 4 // 1 compás en ms

    // Subdivisión según tamaño
    let sizeSubdivision: Double
    switch size {
    case "Voz íntima": sizeSubdivision = 0.25   // 1/4 compás
    case "Natural", "Normal": sizeSubdivision = 0.5        // 1/2 compás
    case "Grande": sizeSubdivision = 1.0        // 1 compás
    default: sizeSubdivision = 0.5
    }

    // Ajuste emocional (multiplicador sutil)
    let emotionFactor: Double
    switch emotion {
    case .frio: emotionFactor = 0.95
    case .cercano: emotionFactor = 0.98
    case .tenso: emotionFactor = 1.1
    case .vacio: emotionFactor = 1.25
    }

    // Decay final en segundos (musical)
    let decay = (bar * sizeSubdivision * emotionFactor) / 1000

    let send: String
    switch role {
    case .lead: send = "-18 dB"
    case .back: send = "-15 dB"
    case .adlib: send = "-12 dB"
    case .textura: send = "-9 dB"
    }

    let eq: String
    switch emotion {
    case .frio: eq = "HPF 180Hz / shelf +2dB @ 7kHz"
    case .cercano: eq = "HPF 120Hz / shelf -2dB @ 8kHz"
    case .tenso: eq = "HPF 200Hz / peak +2dB @ 2.5kHz"
    case .vacio: eq = "HPF 250Hz / LPF 6kHz"
    }

    let note: String
    switch role {
    case .lead: note = "Separación clara con pre-delay"
    case .back: note = "Abrir en estéreo"
    case .adlib: note = "Automatizar envío"
    case .textura: note = "No priorizar claridad"
    }

    return (pre, decay, send, eq, note)
}

// MARK: - UI

struct ContentView: View {
    private struct PersistedSelection: Codable {
        let bpm: String
        let bpmMultiplier: Double
        let mode: String
        let emotion: Emotion
        let role: Role
        let isHistoryExpanded: Bool
    }

    private enum StorageKey {
        static let history = "voxspace.history"
        static let selection = "voxspace.selection"
    }
    
    enum CopyField {
        case pre, decay, send
    }
    @State private var copiedField: CopyField?
    @State private var copyResetWorkItem: DispatchWorkItem?
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = AppLanguage.spanish.rawValue
    
    @State private var bpm: String = "120"
    @State private var lastValidBPM: String = "120"
    @State private var bpmMultiplier: Double = 1.0
    @State private var mode: String = "Voz íntima"
    
    @State private var emotion: Emotion = .frio
    @State private var role: Role = .lead
    
    @State private var preDelay: Double = 0
    @State private var decay: Int = 0
    @State private var decayVal: String = ""
    @State private var sendLevel: String = ""
    @State private var eqText: String = ""
    @State private var noteText: String = ""
    
    @State private var history: [HistoryItem] = []
    @State private var selectedHistory: UUID?
    @State private var hoveredHistory: UUID?
    @State private var historyHasOverflow: Bool = false
    @State private var hasUserScrolled: Bool = false
    @State private var colorSchemeOverride: ColorScheme? = nil
    @State private var observedSystemScheme: ColorScheme = .light
    @State private var appearanceObservation: NSKeyValueObservation?
    @State private var isHistoryExpanded: Bool = true
    @State private var displayedModeHelpText: String = ""
    @State private var isModeHelpTransitioning: Bool = false
    @State private var measuredContentHeight: CGFloat = 0
    @State private var hasLoadedPersistedState = false

    // Hover feedback states for Emotion and Role menus
    @State private var hoveredEmotion: Bool = false
    @State private var hoveredRole: Bool = false
    @State private var hoveredSaveButton: Bool = false
    
    let modes = ["Modo clásico", "Voz íntima", "Natural", "Grande"]

    private var language: AppLanguage {
        AppLanguage(rawValue: selectedLanguageCode) ?? .spanish
    }

    private enum Layout {
        static let windowWidth: CGFloat = 420
        static let minimumInterfaceHeight: CGFloat = 595
        static let minimumHeightWithHistoryHeader: CGFloat = 682
        static let expandedHistoryHeight: CGFloat = 731
        static let outerPadding: CGFloat = 12
        static let realtimeStatusHeight: CGFloat = 42
        static let actionButtonWidth: CGFloat = 144
        static let windowHeightSafetyInset: CGFloat = 92
        static let selectorIconWidth: CGFloat = 16
        static let selectorHeight: CGFloat = 34
        static let emotionControlWidth: CGFloat = 112
        static let roleControlWidth: CGFloat = 140
    }

    private var modeHelpText: String {
        switch mode {
        case "Modo clásico":
            return localizedText(
                "Calcula una reverb base solo con el BPM. Ideal como punto de partida rápido y equilibrado.",
                "Calculates a base reverb using only BPM. Useful as a quick, balanced starting point without adjusting emotion or role."
            )
        case "Voz íntima":
            return localizedText(
                "Mantiene la voz cerca y definida, con una sensación más seca y controlada para mezclas íntimas.",
                "Keeps the vocal close and defined, with a drier and more controlled feel for intimate mixes."
            )
        case "Natural", "Normal":
            return localizedText(
                "Ofrece un equilibrio natural entre cercanía y espacio. Suele funcionar bien como ajuste general.",
                "Offers a natural balance between closeness and space. Usually works well as an all-purpose setting."
            )
        case "Grande":
            return localizedText(
                "Abre más el ambiente y alarga la cola de la reverb. Encaja mejor en momentos amplios o atmosféricos.",
                "Opens up the ambience and lengthens the reverb tail. Best for wide or atmospheric moments."
            )
        default:
            return ""
        }
    }

    private func localizedText(_ spanish: String, _ english: String) -> String {
        language == .spanish ? spanish : english
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "Modo clásico":
            return localizedText("Modo clásico", "Classic mode")
        case "Voz íntima":
            return localizedText("Voz íntima", "Intimate")
        case "Natural", "Normal":
            return localizedText("Natural", "Natural")
        case "Grande":
            return localizedText("Grande", "Large")
        default:
            return mode
        }
    }

    private func emotionLabel(_ emotion: Emotion) -> String {
        switch emotion {
        case .frio:
            return localizedText("Frío", "Cold")
        case .cercano:
            return localizedText("Cálido", "Warm")
        case .tenso:
            return localizedText("Tenso", "Tense")
        case .vacio:
            return localizedText("Vacío", "Hollow")
        }
    }

    private func roleLabel(_ role: Role) -> String {
        switch role {
        case .lead:
            return localizedText("Principal", "Lead")
        case .back:
            return localizedText("Coros", "Backing")
        case .adlib:
            return "Adlibs"
        case .textura:
            return localizedText("Textura", "Texture")
        }
    }

    private func localizedEQ(_ text: String) -> String {
        switch text {
        case "HPF 180Hz / shelf +2dB @ 7kHz":
            return "HPF 180Hz / shelf +2dB @ 7kHz"
        case "HPF 120Hz / shelf -2dB @ 8kHz":
            return "HPF 120Hz / shelf -2dB @ 8kHz"
        case "HPF 200Hz / peak +2dB @ 2.5kHz":
            return "HPF 200Hz / peak +2dB @ 2.5kHz"
        case "HPF 250Hz / LPF 6kHz":
            return "HPF 250Hz / LPF 6kHz"
        case "Flat":
            return localizedText("Flat", "Flat")
        default:
            return text
        }
    }

    private func localizedNote(_ text: String) -> String {
        switch text {
        case "Modo clásico (tempo directo)":
            return localizedText("Modo clásico (tempo directo)", "Classic mode (direct BPM)")
        case "Separación clara con pre-delay":
            return localizedText("Separación clara con pre-delay", "Clear separation with pre-delay")
        case "Abrir en estéreo":
            return localizedText("Abrir en estéreo", "Open in stereo")
        case "Automatizar envío":
            return localizedText("Automatizar envío", "Automate send level")
        case "No priorizar claridad":
            return localizedText("No priorizar claridad", "Clarity is not the priority")
        default:
            return text
        }
    }

    private var preferredWindowHeight: CGFloat {
        let measuredHeight = ceil(measuredContentHeight) + Layout.windowHeightSafetyInset

        if history.isEmpty {
            return max(Layout.minimumInterfaceHeight, measuredHeight)
        }

        let fallbackHeight = isHistoryExpanded ? Layout.expandedHistoryHeight : Layout.minimumHeightWithHistoryHeader
        return max(fallbackHeight, measuredHeight)
    }

    private var canScrollHistory: Bool {
        historyHasOverflow
    }

    private var shouldDisplayHistoryHint: Bool {
        canScrollHistory && !hasUserScrolled
    }

    private var hasValidPreview: Bool {
        let trimmed = bpm.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned).map { $0 > 0 } ?? false
    }

    private var canSaveCurrentPreset: Bool {
        guard hasValidPreview else { return false }
        return history.first != currentHistoryItem
    }

    private var currentHistoryItem: HistoryItem? {
        let trimmed = bpm.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let bpmVal = Double(cleaned), bpmVal > 0 else { return nil }

        return HistoryItem(
            bpm: bpmVal,
            multiplier: bpmMultiplier,
            mode: mode,
            emotion: emotion,
            role: role,
            preDelay: Int(preDelay),
            decay: decay,
            decayVal: decayVal,
            send: sendLevel,
            eq: eqText,
            note: noteText
        )
    }

    @ViewBuilder
    private var versionBadge: some View {
        let badgeLabel = Text("2.5")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

        if #available(macOS 26.0, *) {
            badgeLabel
                .glassEffect(.regular.tint(.blue).interactive(), in: .capsule)
        } else {
            badgeLabel
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.95),
                                    Color.cyan.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.22))
                )
                .shadow(color: Color.blue.opacity(0.22), radius: 8, y: 2)
        }
    }

    private var historyToggleChip: some View {
        ZStack {
            historyToggleLabel(title: localizedText("Mostrar", "Show"), symbol: "chevron.down.circle.fill")
                .opacity(isHistoryExpanded ? 0 : 1)

            historyToggleLabel(title: localizedText("Ocultar", "Hide"), symbol: "chevron.up.circle.fill")
                .opacity(isHistoryExpanded ? 1 : 0)
        }
        .frame(width: 86)
        .transaction { transaction in
            transaction.animation = nil
        }
        .foregroundStyle(isHistoryExpanded ? .secondary : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(isHistoryExpanded ? 0.04 : 0.08)))
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    // MARK: - Dynamic Glass Tint
    private var glassTint: Color {
        let scheme = colorSchemeOverride ?? observedSystemScheme
        switch scheme {
        case .dark:
            return Color.white.opacity(0.08)
        case .light:
            return Color.black.opacity(0.04)
        @unknown default:
            return Color.primary.opacity(0.06)
        }
    }

    private var selectorFillColor: Color {
        let scheme = colorSchemeOverride ?? observedSystemScheme
        switch scheme {
        case .dark:
            return Color.white.opacity(0.14)
        case .light:
            return Color.black.opacity(0.12)
        @unknown default:
            return Color.primary.opacity(0.1)
        }
    }

    private var selectorStrokeColor: Color {
        let scheme = colorSchemeOverride ?? observedSystemScheme
        switch scheme {
        case .dark:
            return Color.white.opacity(0.08)
        case .light:
            return Color.black.opacity(0.06)
        @unknown default:
            return Color.primary.opacity(0.08)
        }
    }
    
    struct GlassButtonStyle: ButtonStyle {
        let isSuccess: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSuccess ? Color.green.opacity(0.18) : Color.primary.opacity(0.04))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSuccess
                                    ? Color.green.opacity(0.55)
                                    : Color.primary.opacity(0.12)
                                )
                        )
                )
                .shadow(
                    color: isSuccess ? Color.green.opacity(0.18) : Color.clear,
                    radius: isSuccess ? 8 : 0
                )
                .scaleEffect(configuration.isPressed ? 0.94 : (isSuccess ? 1.03 : 1))
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
                .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isSuccess)
        }
    }

    struct SavePresetButtonStyle: ButtonStyle {
        let isHovered: Bool
        let isEnabled: Bool

        @ViewBuilder
        private func background(isPressed: Bool) -> some View {
            if #available(macOS 26.0, *) {
                ZStack {
                    Capsule()
                        .fill(.clear)
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isPressed ? 0.08 : (isHovered ? 0.24 : 0.10)),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blur(radius: isPressed ? 0 : (isHovered ? 0.4 : 0))
                        }
                }
                .glassEffect(.regular.tint(isEnabled ? .blue : .gray).interactive(), in: .capsule)
            } else {
                Capsule()
                    .fill(isEnabled ? Color.blue.opacity(isPressed ? 0.82 : 1) : Color.gray.opacity(0.45))
            }
        }

        func makeBody(configuration: Configuration) -> some View {
            let isPressed = configuration.isPressed

            return configuration.label
                .frame(width: Layout.actionButtonWidth)
                .padding(.vertical, 10)
                .background(background(isPressed: isPressed))
                .scaleEffect(isPressed ? 0.965 : (isHovered ? 1.03 : 1))
                .offset(y: isPressed ? 1.5 : 0)
                .shadow(
                    color: isEnabled ? Color.blue.opacity(isPressed ? 0.10 : (isHovered ? 0.24 : 0.12)) : .clear,
                    radius: isPressed ? 4 : (isHovered ? 14 : 8),
                    y: isPressed ? 1 : (isHovered ? 4 : 2)
                )
                .brightness(isPressed ? -0.03 : 0)
                .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isPressed)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        }
    }
    
    private var backgroundView: some View {
        Color(nsColor: .windowBackgroundColor)
            .opacity(0.95)
            .overlay(
                LinearGradient(
                    colors: [
                        glassTint.opacity(0.35),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    private var titleBlock: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("VoxSpace")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .tracking(-0.4)

                versionBadge
                    .offset(y: 1)
            }

            Text(localizedText("Creado por Alexey Delgado", "Created by Alexey Delgado"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }

    private var selectorControlsRow: some View {
        HStack(alignment: .top, spacing: 10) {
            selectorColumn(
                title: localizedText("Emoción", "Emotion"),
                width: Layout.emotionControlWidth,
                isDisabled: mode == "Modo clásico"
            ) {
                Menu {
                    ForEach(Emotion.allCases, id: \.self) { option in
                        Button(emotionLabel(option)) {
                            emotion = option
                            calcularPreview()
                        }
                    }
                } label: {
                    emotionSelector
                }
                .buttonStyle(.plain)
                .frame(width: Layout.emotionControlWidth, alignment: .leading)
                .frame(height: Layout.selectorHeight, alignment: .top)
            }

            selectorColumn(
                title: localizedText("Capa vocal", "Vocal layer"),
                width: Layout.roleControlWidth,
                isDisabled: mode == "Modo clásico"
            ) {
                Menu {
                    ForEach(Role.allCases, id: \.self) { option in
                        Button(roleLabel(option)) {
                            role = option
                            calcularPreview()
                        }
                    }
                } label: {
                    roleSelector
                }
                .buttonStyle(.plain)
                .frame(width: Layout.roleControlWidth, alignment: .leading)
                .frame(height: Layout.selectorHeight, alignment: .top)
            }
        }
    }

    private var realtimeStatusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedText("Ajuste en tiempo real", "Real-time update"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(localizedText("Los valores cambian al instante según BPM, modo y capa vocal.", "Values update instantly based on BPM, mode, and vocal layer."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(localizedText("Guardar ajuste", "Save preset")) {
                guardarPresetEnHistorial()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .buttonStyle(SavePresetButtonStyle(isHovered: hoveredSaveButton, isEnabled: canSaveCurrentPreset))
            .disabled(!canSaveCurrentPreset)
            .opacity(canSaveCurrentPreset ? 1 : 0.7)
            .onHover { hovering in
                hoveredSaveButton = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .frame(minHeight: Layout.realtimeStatusHeight)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(glassTint.opacity(0.6))
        )
    }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            topControls
            selectorControlsRow
            resultView
            realtimeStatusCard
            historyView
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(glassTint)
        )
    }

    @ViewBuilder
    private func selectorColumn<Content: View>(
        title: String,
        width: CGFloat,
        isDisabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            content()
                .disabled(isDisabled)
        }
        .frame(width: width, alignment: .leading)
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            VStack(spacing: 10) {
                titleBlock
                mainCard
            }
            .padding(.top, Layout.outerPadding)
            .padding(.horizontal, Layout.outerPadding)
            .padding(.bottom, Layout.outerPadding)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: RootContentHeightKey.self, value: proxy.size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            restorePersistedState()
            calcularPreview()
            startAppearanceObservation()
            resizeWindow(to: preferredWindowHeight, animated: false)
            hasLoadedPersistedState = true
        }
        .onPreferenceChange(RootContentHeightKey.self) { value in
            measuredContentHeight = value
        }
        .onChange(of: preferredWindowHeight) { newHeight in
            resizeWindow(to: newHeight, animated: false)
        }
        .onChange(of: history) { _ in
            persistHistory()
        }
        .onChange(of: bpm) { _ in
            persistSelection()
        }
        .onChange(of: mode) { _ in
            persistSelection()
        }
        .onChange(of: emotion) { _ in
            persistSelection()
        }
        .onChange(of: role) { _ in
            persistSelection()
        }
        .onChange(of: isHistoryExpanded) { _ in
            persistSelection()
        }
        .frame(width: Layout.windowWidth)
        .frame(minHeight: preferredWindowHeight, alignment: .top)
        
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(AppLanguage.allCases) { option in
                        Button {
                            selectedLanguageCode = option.rawValue
                        } label: {
                            HStack {
                                Text(option.title)
                                if option == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "globe")
                }
            }
            ToolbarItem {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        switch colorSchemeOverride {
                        case nil:
                            colorSchemeOverride = .dark
                        case .some(.dark):
                            colorSchemeOverride = .light
                        case .some(.light):
                            colorSchemeOverride = nil
                        default:
                            colorSchemeOverride = nil
                        }
                    }
                } label: {
                    ZStack {
                        switch colorSchemeOverride {
                        case nil:
                            Image(systemName: "circle.lefthalf.filled") // sistema
                        case .some(.dark):
                            Image(systemName: "moon.fill")
                        case .some(.light):
                            Image(systemName: "sun.max.fill")
                        default:
                            Image(systemName: "circle.lefthalf.filled")
                        }
                    }
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))
                    .id(colorSchemeOverride?.hashValue ?? -1)
                    .scaleEffect(1.05)
                    .opacity(1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: colorSchemeOverride)
                }
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .preferredColorScheme(colorSchemeOverride ?? observedSystemScheme)
    }
    
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Pre-delay")
                    .frame(width: 78, alignment: .leading)
                    .foregroundColor(.primary)
                Text(String(format: "%.1f ms", preDelay))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton(texto: String(format: "%.1f", preDelay), field: .pre)
            }

            HStack {
                Text(localizedText("Duración", "Duration"))
                    .frame(width: 78, alignment: .leading)
                    .foregroundColor(.secondary)
                Text("\(decayVal) (\(String(format: "%.2f s", Double(decay) / 1000)))")
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton(texto: String(format: "%.2f", Double(decay) / 1000), field: .decay)
            }

            HStack {
                Text(localizedText("Nivel", "Level"))
                    .frame(width: 78, alignment: .leading)
                    .foregroundColor(.secondary)
                Text(sendLevel)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton(texto: sendLevel.replacingOccurrences(of: " dB", with: ""), field: .send)
            }

            Divider()
                .overlay(glassTint.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedText("EQ sugerida", "Suggested EQ"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(eqText.isEmpty ? localizedText("Se mostrará aquí al introducir un BPM válido.", "It will appear here when you enter a valid BPM.") : localizedEQ(eqText))
                    .font(.caption)
                    .foregroundStyle(eqText.isEmpty ? .tertiary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedText("Consejo", "Tip"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(noteText.isEmpty ? localizedText("Aquí verás una recomendación rápida según el modo y la capa vocal.", "A quick recommendation based on mode and vocal layer will appear here.") : localizedNote(noteText))
                    .font(.caption)
                    .foregroundStyle(noteText.isEmpty ? .tertiary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)

                RadialGradient(
                    colors: [
                        Color.blue.opacity(observedSystemScheme == .dark ? 0.12 : 0.05),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(glassTint.opacity(0.8))
        )
    }
    
    private var topControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                
                HStack(spacing: 8) {
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    TextField("120", text: $bpm)
                        .frame(width: 60)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: bpm) { newValue in
                            // Sanitize input
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")

                            // Normalize visible text (fix trailing spaces bug)
                            if newValue != cleaned {
                                bpm = cleaned
                                return
                            }

                            // Validate numeric BPM > 0
                            if let value = Double(cleaned), value > 0 {
                                lastValidBPM = cleaned
                                calcularPreview()
                            } else if cleaned.isEmpty {
                                clearPreview()
                            } else {
                                bpm = lastValidBPM
                            }
                        }
                }
                HStack(spacing: 6) {
                    multiplierChip(label: "½", value: 0.5)
                    multiplierChip(label: "1×", value: 1.0)
                    multiplierChip(label: "2×", value: 2.0)
                }
                
                Spacer()
                
                Menu {
                    ForEach(modes, id: \.self) { option in
                        Button(modeLabel(option)) {
                            mode = option
                            calcularPreview()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(modeLabel(mode))
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.thinMaterial)
                    )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .leading) {
                    Text(modeHelpText)
                        .font(.caption2)
                        .foregroundStyle(.clear)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()

                    Text(displayedModeHelpText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .blur(radius: isModeHelpTransitioning ? 2.5 : 0)
                        .opacity(isModeHelpTransitioning ? 0.72 : 1)
                }
                .onAppear {
                    displayedModeHelpText = modeHelpText
                }
                .onChange(of: mode) { _ in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isModeHelpTransitioning = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        displayedModeHelpText = modeHelpText

                        withAnimation(.easeInOut(duration: 0.32)) {
                            isModeHelpTransitioning = false
                        }
                    }
                }
                .onChange(of: selectedLanguageCode) { _ in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isModeHelpTransitioning = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        displayedModeHelpText = modeHelpText

                        withAnimation(.easeInOut(duration: 0.32)) {
                            isModeHelpTransitioning = false
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            .allowsHitTesting(false)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(glassTint.opacity(0.9))
        )
    }

    private var historyView: some View {
        Group {
            if !history.isEmpty {
                
                VStack(alignment: .leading, spacing: 4) {
                    
                    Button {
                        isHistoryExpanded.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: isHistoryExpanded ? 0 : 6) {
                            HStack(alignment: .center, spacing: 12) {
                                HStack(spacing: 6) {
                                    Text(localizedText("Historial", "History"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("\(history.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                historyToggleChip
                            }

                            if !isHistoryExpanded {
                                Text(localizedText("Toca para ver los ajustes guardados", "Click to view saved presets"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                        .padding(.bottom, isHistoryExpanded ? 0 : 2)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .frame(minHeight: isHistoryExpanded ? 36 : 58, alignment: .top)
                    .padding(.bottom, isHistoryExpanded ? 0 : 10)
                    
                    if isHistoryExpanded {
                        ScrollView {
                            VStack(spacing: 6) {
                                ScrollInteractionObserver {
                                    hasUserScrolled = true
                                } onOverflowChange: { hasOverflow in
                                    historyHasOverflow = hasOverflow
                                }
                                .frame(width: 0, height: 0)

                                ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                                    historyRow(item)
                                        .transition(.opacity)
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: history)
                            .padding(.top, 2)
                        }
                        .onAppear {
                            historyHasOverflow = false
                        }
                        .onChange(of: isHistoryExpanded) { _ in
                            hasUserScrolled = false
                            historyHasOverflow = false
                        }
                        .onChange(of: history.count) { _ in
                            hasUserScrolled = false
                            historyHasOverflow = false
                        }
                        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.14), value: isHistoryExpanded)
                        .overlay(alignment: .bottom) {
                            if shouldDisplayHistoryHint {
                                VStack(spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down")
                                        Text(localizedText("Desliza para ver más", "Scroll to see more"))
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.blue.opacity(observedSystemScheme == .dark ? 0.7 : 0.62),
                                                        Color.blue.opacity(observedSystemScheme == .dark ? 0.5 : 0.44)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(observedSystemScheme == .dark ? 0.12 : 0.18))
                                    )
                                    .shadow(
                                        color: Color.blue.opacity(observedSystemScheme == .dark ? 0.22 : 0.14),
                                        radius: 8,
                                        y: 1
                                    )
                                    .padding(.bottom, 6)
                                }
                                .allowsHitTesting(false)
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.bottom, isHistoryExpanded ? 0 : 4)
            }
        }
    }
    
    private func historyRow(_ item: HistoryItem) -> some View {
        historyRowContent(item)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 44)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    aplicarHistorial(item)
                    selectedHistory = item.id
                }
                copiarPreset()
            }
            .overlay(alignment: .trailing) {
                Button {
                    history.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hoveredHistory == item.id ? Color.red : Color.secondary)
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 6)
                .opacity(hoveredHistory == item.id ? 1 : 0.35)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedHistory == item.id
                ? Color.blue.opacity(0.25)
                : (hoveredHistory == item.id ? Color.primary.opacity(0.10) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedHistory == item.id
                        ? Color.blue.opacity(0.4)
                        : glassTint.opacity(0.9)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .zIndex(1)
            .onHover { hovering in
                hoveredHistory = hovering ? item.id : nil
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedHistory)
            .contextMenu {
                Button(localizedText("Copiar ajustes", "Copy preset")) {
                    aplicarHistorial(item)
                    copiarPreset()
                }
                Button(localizedText("Eliminar", "Delete")) {
                    history.removeAll { $0.id == item.id }
                }
            }
    }

    private func historyToggleLabel(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))

            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
        }
    }

    private func historyRowContent(_ item: HistoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {

            // Multiplier + BPM (left anchor, multiplier first)
            HStack(spacing: 6) {
                let label = item.multiplier == 2.0 ? "×2" : "÷2"

                Group {
                    if item.multiplier != 1.0 {
                        if #available(macOS 26.0, *) {
                            Text(label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.blue,
                                            Color.cyan.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.blue.opacity(0.35), radius: 2, y: 0)
                        } else {
                            Text(label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.85))
                                )
                        }
                    } else {
                        Text(label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .opacity(0)
                    }
                }
                .frame(width: 28) // reserve space so layout never shifts

                Text("\(Int(item.bpm))")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            // Main info block (refactored)
            VStack(alignment: .leading, spacing: 3) {

                // Context (mode + emotion + role in one compact row)
                Text("\(modeLabel(item.mode)) · \(emotionLabel(item.emotion)) · \(roleLabel(item.role))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Multiplier context (stable layout)
                let resultBPM = Int(item.bpm * item.multiplier)
                Text(
                    item.multiplier != 1.0
                    ? "→ \(resultBPM) BPM"
                    : " "
                )
                .font(.caption2)
                .opacity(item.multiplier != 1.0 ? 1 : 0)
                .frame(height: 12)

                // Technical parameters (clean + consistent)
                HStack(spacing: 6) {
                    Text("Pre \(item.preDelay) ms")
                    Text("·")
                    Text(String(format: "%.2f s", Double(item.decay) / 1000))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .scaleEffect(selectedHistory == item.id ? 1.02 : 1)
        .blur(radius: hoveredHistory == item.id ? 0.2 : 0)
    }

    private func formattedBPM(_ item: HistoryItem) -> String {
        let base = "\(Int(item.bpm)) BPM"
        switch item.multiplier {
        case 2.0:
            return base + " ×2"
        case 0.5:
            return base + " ÷2"
        default:
            return base
        }
    }
    
    private func copyButton(texto: String, field: CopyField) -> some View {
        let isCopied = copiedField == field

        return Button {
            copiarTexto(texto)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                copiedField = field
            }
            copyResetWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.2)) {
                    copiedField = nil
                }
            }
            copyResetWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: workItem)
        } label: {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .opacity(isCopied ? 0 : 1)
                    .scaleEffect(isCopied ? 0.7 : 1)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.green)
                    .opacity(isCopied ? 1 : 0)
                    .scaleEffect(isCopied ? 1 : 0.6)
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(GlassButtonStyle(isSuccess: isCopied))
    }
    // MARK: - Icon Helpers

    private func iconForEmotion(_ emotion: Emotion) -> String {
        switch emotion {
        case .frio: return "snowflake"
        case .cercano: return "flame"
        case .tenso: return "bolt"
        case .vacio: return "moon.stars"
        }
    }

    private func iconForRole(_ role: Role) -> String {
        switch role {
        case .lead: return "music.mic"
        case .back: return "person.2.fill"
        case .adlib: return "waveform"
        case .textura: return "aqi.medium"
        }
    }

    // MARK: - Core
    
    private func calcularPreview() {
        let trimmed = bpm.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let bpmVal = Double(cleaned), bpmVal > 0 else {
            clearPreview()
            return
        }
        let effectiveBPM = bpmVal * bpmMultiplier
        let result = generarReverbInteligente(
            bpm: effectiveBPM,
            size: mode,
            emotion: emotion,
            role: role
        )
        
        preDelay = result.preDelay
        let decayMs = result.decay * 1000
        decayVal = "\(Int(decayMs)) ms"
        sendLevel = result.send
        eqText = result.eq
        noteText = result.note
        decay = Int(result.decay * 1000)
    }

    private func clearPreview() {
        preDelay = 0
        decay = 0
        decayVal = ""
        sendLevel = ""
        eqText = ""
        noteText = ""
    }

    private func targetWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
    }

    private func currentSystemScheme() -> ColorScheme {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return appearance == .darkAqua ? .dark : .light
    }

    private func startAppearanceObservation() {
        guard appearanceObservation == nil else { return }

        observedSystemScheme = currentSystemScheme()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            observedSystemScheme = currentSystemScheme()
        }
    }

    private func resizeWindow(to height: CGFloat, animated: Bool) {
        guard let window = targetWindow() else { return }

        var frame = window.frame
        let targetContentRect = NSRect(x: 0, y: 0, width: Layout.windowWidth, height: height)
        let targetFrame = window.frameRect(forContentRect: targetContentRect)
        let delta = targetFrame.height - frame.height
        frame.origin.y -= delta
        frame.size.height = targetFrame.height
        frame.size.width = targetFrame.width

        window.contentMinSize = NSSize(width: Layout.windowWidth, height: height)
        window.minSize = targetFrame.size
        window.setFrame(frame, display: true, animate: animated)
    }

    private func restorePersistedState() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if let historyData = defaults.data(forKey: StorageKey.history),
           let savedHistory = try? decoder.decode([HistoryItem].self, from: historyData) {
            history = savedHistory
        }

        if let selectionData = defaults.data(forKey: StorageKey.selection),
           let savedSelection = try? decoder.decode(PersistedSelection.self, from: selectionData) {
            bpm = savedSelection.bpm
            lastValidBPM = savedSelection.bpm
            bpmMultiplier = savedSelection.bpmMultiplier
            mode = savedSelection.mode == "Normal"
                ? "Natural"
                : (modes.contains(savedSelection.mode) ? savedSelection.mode : "Voz íntima")
            emotion = savedSelection.emotion
            role = savedSelection.role
            isHistoryExpanded = savedSelection.isHistoryExpanded
        }
    }

    private func persistHistory() {
        guard hasLoadedPersistedState else { return }

        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(history) else { return }
        defaults.set(data, forKey: StorageKey.history)
    }

    private func persistSelection() {
        guard hasLoadedPersistedState else { return }

        let selection = PersistedSelection(
            bpm: bpm,
            bpmMultiplier: bpmMultiplier,
            mode: mode,
            emotion: emotion,
            role: role,
            isHistoryExpanded: isHistoryExpanded
        )

        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(selection) else { return }
        defaults.set(data, forKey: StorageKey.selection)
    }
    
    private func guardarPresetEnHistorial() {
        guard let item = currentHistoryItem else { return }
        
        history.insert(item, at: 0)
        if history.count > 20 {
            history.removeLast()
        }
    }
    
    private func aplicarHistorial(_ item: HistoryItem) {
        bpm = String(Int(item.bpm))
        mode = item.mode
        emotion = item.emotion
        role = item.role
        preDelay = Double(item.preDelay)
        decay = item.decay
        decayVal = item.decayVal
        sendLevel = item.send
        eqText = item.eq
        noteText = item.note
    }
    
    private func copiarPreset() {
        let decaySeconds = String(format: "%.2f s", Double(decay) / 1000)
        let texto = "\(localizedText("Pre-delay", "Pre-delay")): \(preDelay) ms\n\(localizedText("Duración", "Duration")): \(decaySeconds)\nSend: \(sendLevel)"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(texto, forType: .string)
    }

    private func copiarTexto(_ texto: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(texto, forType: .string)
    }
    // MARK: - Selectors
    private var emotionSelector: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: iconForEmotion(emotion))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: Layout.selectorIconWidth, alignment: .center)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.8))
                Text(emotionLabel(emotion))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(width: 58, alignment: .leading)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: Layout.emotionControlWidth, alignment: .leading)
        .frame(height: Layout.selectorHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectorFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            (colorSchemeOverride ?? observedSystemScheme) == .dark
                            ? Color.white.opacity(hoveredEmotion ? 0.08 : 0)
                            : Color.black.opacity(hoveredEmotion ? 0.04 : 0)
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectorStrokeColor)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredEmotion = hovering
            }
        }
    }

    private var roleSelector: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: iconForRole(role))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: Layout.selectorIconWidth, alignment: .center)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.8))
                Text(roleLabel(role))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(width: 86, alignment: .leading)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: Layout.roleControlWidth, alignment: .leading)
        .frame(height: Layout.selectorHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectorFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            (colorSchemeOverride ?? observedSystemScheme) == .dark
                            ? Color.white.opacity(hoveredRole ? 0.08 : 0)
                            : Color.black.opacity(hoveredRole ? 0.04 : 0)
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectorStrokeColor)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredRole = hovering
            }
        }
    }

    // MARK: - Multiplier Chip Helper
    private func multiplierChip(label: String, value: Double) -> some View {
        let isActive = bpmMultiplier == value
        return Button {
            bpmMultiplier = value
            calcularPreview()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isActive ? selectorFillColor : Color.clear)
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(
                    Capsule()
                        .stroke(selectorStrokeColor.opacity(isActive ? 1 : 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .frame(width: 420)
}
