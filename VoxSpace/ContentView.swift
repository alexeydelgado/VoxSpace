import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = VoxSpaceStore()

    enum CopyField {
        case pre, decay, send
    }
    @State private var copiedField: CopyField?
    @State private var copyResetWorkItem: DispatchWorkItem?
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = AppLanguage.spanish.rawValue

    @State private var selectedHistory: UUID?
    @State private var hoveredHistory: UUID?
    @State private var historyHasOverflow: Bool = false
    @State private var hasUserScrolled: Bool = false
    @State private var colorSchemeOverride: ColorScheme? = nil
    @State private var observedSystemScheme: ColorScheme = .light
    @State private var appearanceObservation: NSKeyValueObservation?
    @State private var displayedModeHelpText: String = ""
    @State private var isModeHelpTransitioning: Bool = false
    @State private var measuredContentHeight: CGFloat = 0

    // Hover feedback states for Emotion and Role menus
    @State private var hoveredEmotion: Bool = false
    @State private var hoveredRole: Bool = false
    @State private var hoveredSaveButton: Bool = false

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

    private var persistHistoryEnabled: Bool {
        get { store.persistHistoryEnabled }
        nonmutating set { store.persistHistoryEnabled = newValue }
    }

    private var bpm: String {
        get { store.bpm }
        nonmutating set { store.bpm = newValue }
    }

    private var lastValidBPM: String {
        get { store.lastValidBPM }
        nonmutating set { store.lastValidBPM = newValue }
    }

    private var bpmMultiplier: Double {
        get { store.bpmMultiplier }
        nonmutating set { store.bpmMultiplier = newValue }
    }

    private var mode: String {
        get { store.mode }
        nonmutating set { store.mode = newValue }
    }

    private var emotion: Emotion {
        get { store.emotion }
        nonmutating set { store.emotion = newValue }
    }

    private var role: Role {
        get { store.role }
        nonmutating set { store.role = newValue }
    }

    private var preDelay: Double {
        get { store.preDelay }
        nonmutating set { store.preDelay = newValue }
    }

    private var decay: Int {
        get { store.decay }
        nonmutating set { store.decay = newValue }
    }

    private var decayVal: String {
        get { store.decayVal }
        nonmutating set { store.decayVal = newValue }
    }

    private var sendLevel: String {
        get { store.sendLevel }
        nonmutating set { store.sendLevel = newValue }
    }

    private var eqText: String {
        get { store.eqText }
        nonmutating set { store.eqText = newValue }
    }

    private var noteText: String {
        get { store.noteText }
        nonmutating set { store.noteText = newValue }
    }

    private var history: [HistoryItem] {
        get { store.history }
        nonmutating set { store.history = newValue }
    }

    private var isHistoryExpanded: Bool {
        get { store.isHistoryExpanded }
        nonmutating set { store.isHistoryExpanded = newValue }
    }

    private var hasLoadedPersistedState: Bool {
        get { store.hasLoadedPersistedState }
        nonmutating set { store.hasLoadedPersistedState = newValue }
    }

    private var modes: [String] { store.modes }

    private var bpmBinding: Binding<String> {
        Binding(
            get: { store.bpm },
            set: { store.bpm = $0 }
        )
    }

    @ViewBuilder
    private func languageMenuLabel(for option: AppLanguage) -> some View {
        if option == language {
            Label(option.title, systemImage: "checkmark")
        } else {
            Text(option.title)
        }
    }

    private var appearanceToolbarSymbolName: String {
        switch colorSchemeOverride {
        case nil:
            return "circle.lefthalf.filled"
        case .some(.dark):
            return "moon.fill"
        case .some(.light):
            return "sun.max.fill"
        default:
            return "circle.lefthalf.filled"
        }
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
            store.restorePersistedState()
            store.calcularPreview()
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
            store.persistHistory()
        }
        .onChange(of: persistHistoryEnabled) { isEnabled in
            store.handleHistoryPersistenceChange(isEnabled)
        }
        .onChange(of: bpm) { _ in
            store.persistSelection()
        }
        .onChange(of: mode) { _ in
            store.persistSelection()
        }
        .onChange(of: emotion) { _ in
            store.persistSelection()
        }
        .onChange(of: role) { _ in
            store.persistSelection()
        }
        .onChange(of: isHistoryExpanded) { _ in
            store.persistSelection()
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
                            languageMenuLabel(for: option)
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
                    Image(systemName: appearanceToolbarSymbolName)
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
                    
                    TextField("120", text: bpmBinding)
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
        HistorySectionView(
            history: history,
            isHistoryExpanded: Binding(
                get: { isHistoryExpanded },
                set: { isHistoryExpanded = $0 }
            ),
            selectedHistory: $selectedHistory,
            hoveredHistory: $hoveredHistory,
            historyHasOverflow: $historyHasOverflow,
            hasUserScrolled: $hasUserScrolled,
            glassTint: glassTint,
            observedSystemScheme: observedSystemScheme,
            localizedText: localizedText,
            modeLabel: modeLabel,
            emotionLabel: emotionLabel,
            roleLabel: roleLabel,
            onApply: aplicarHistorial,
            onDelete: { item in
                history.removeAll { $0.id == item.id }
            },
            onCopy: copiarPreset
        )
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
        store.calcularPreview()
    }

    private func clearPreview() {
        store.clearPreview()
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

    private func guardarPresetEnHistorial() {
        store.guardarPresetEnHistorial()
    }
    
    private func aplicarHistorial(_ item: HistoryItem) {
        store.aplicarHistorial(item)
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
