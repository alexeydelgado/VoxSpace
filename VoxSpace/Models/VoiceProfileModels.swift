import Foundation

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
