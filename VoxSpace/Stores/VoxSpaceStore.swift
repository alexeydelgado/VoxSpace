import Foundation
import Combine

final class VoxSpaceStore: ObservableObject {
    @Published var persistHistoryEnabled: Bool

    @Published var bpm: String = "120"
    @Published var lastValidBPM: String = "120"
    @Published var bpmMultiplier: Double = 1.0
    @Published var mode: String = "Voz íntima"

    @Published var emotion: Emotion = .frio
    @Published var role: Role = .lead

    @Published var preDelay: Double = 0
    @Published var decay: Int = 0
    @Published var decayVal: String = ""
    @Published var sendLevel: String = ""
    @Published var eqText: String = ""
    @Published var noteText: String = ""

    @Published var history: [HistoryItem] = []
    @Published var isHistoryExpanded: Bool = true
    @Published var hasLoadedPersistedState = false

    let modes = ["Modo clásico", "Voz íntima", "Natural", "Grande"]

    init() {
        persistHistoryEnabled = UserDefaults.standard.object(forKey: VoxSpaceStorageKey.persistHistoryEnabled) as? Bool ?? true
    }

    func restorePersistedState() {
        guard let persistedState = VoxSpacePersistence.loadState() else { return }

        if persistHistoryEnabled {
            history = persistedState.history
        }

        if let savedSelection = persistedState.selection {
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

    func persistHistory() {
        guard hasLoadedPersistedState else { return }

        guard persistHistoryEnabled else {
            VoxSpacePersistence.saveState(history: [], selection: currentPersistedSelection)
            return
        }

        VoxSpacePersistence.saveState(history: history, selection: currentPersistedSelection)
    }

    func clearPersistedHistory() {
        history = []
        VoxSpacePersistence.saveState(history: [], selection: currentPersistedSelection)
    }

    func handleHistoryPersistenceChange(_ isEnabled: Bool) {
        guard hasLoadedPersistedState else { return }

        persistHistoryEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: VoxSpaceStorageKey.persistHistoryEnabled)

        if isEnabled {
            persistHistory()
        } else {
            clearPersistedHistory()
        }
    }

    func persistSelection() {
        guard hasLoadedPersistedState else { return }

        VoxSpacePersistence.saveState(
            history: persistHistoryEnabled ? history : [],
            selection: currentPersistedSelection
        )
    }

    var currentPersistedSelection: PersistedSelection {
        PersistedSelection(
            bpm: bpm,
            bpmMultiplier: bpmMultiplier,
            mode: mode,
            emotion: emotion,
            role: role,
            isHistoryExpanded: isHistoryExpanded
        )
    }

    func calcularPreview() {
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

    func clearPreview() {
        preDelay = 0
        decay = 0
        decayVal = ""
        sendLevel = ""
        eqText = ""
        noteText = ""
    }

    var currentHistoryItem: HistoryItem? {
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

    func guardarPresetEnHistorial() {
        guard let item = currentHistoryItem else { return }

        history.insert(item, at: 0)
        if history.count > 20 {
            history.removeLast()
        }
    }

    func aplicarHistorial(_ item: HistoryItem) {
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
}
