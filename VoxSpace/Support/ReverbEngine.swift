import Foundation

func generarReverbInteligente(
    bpm: Double,
    size: String,
    emotion: Emotion,
    role: Role
) -> (preDelay: Double, decay: Double, send: String, eq: String, note: String) {
    let quarter = 60000 / bpm

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
    case "Voz íntima":
        pre = max(20, quarter / 64)
    case "Natural", "Normal":
        pre = quarter / 32
    case "Grande":
        pre = quarter / 16
    default:
        pre = quarter / 32
    }

    let bar = quarter * 4

    let sizeSubdivision: Double
    switch size {
    case "Voz íntima":
        sizeSubdivision = 0.25
    case "Natural", "Normal":
        sizeSubdivision = 0.5
    case "Grande":
        sizeSubdivision = 1.0
    default:
        sizeSubdivision = 0.5
    }

    let emotionFactor: Double
    switch emotion {
    case .frio:
        emotionFactor = 0.95
    case .cercano:
        emotionFactor = 0.98
    case .tenso:
        emotionFactor = 1.1
    case .vacio:
        emotionFactor = 1.25
    }

    let decay = (bar * sizeSubdivision * emotionFactor) / 1000

    let send: String
    switch role {
    case .lead:
        send = "-18 dB"
    case .back:
        send = "-15 dB"
    case .adlib:
        send = "-12 dB"
    case .textura:
        send = "-9 dB"
    }

    let eq: String
    switch emotion {
    case .frio:
        eq = "HPF 180Hz / shelf +2dB @ 7kHz"
    case .cercano:
        eq = "HPF 120Hz / shelf -2dB @ 8kHz"
    case .tenso:
        eq = "HPF 200Hz / peak +2dB @ 2.5kHz"
    case .vacio:
        eq = "HPF 250Hz / LPF 6kHz"
    }

    let note: String
    switch role {
    case .lead:
        note = "Separación clara con pre-delay"
    case .back:
        note = "Abrir en estéreo"
    case .adlib:
        note = "Automatizar envío"
    case .textura:
        note = "No priorizar claridad"
    }

    return (pre, decay, send, eq, note)
}
