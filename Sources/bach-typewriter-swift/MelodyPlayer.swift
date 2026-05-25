import Foundation

struct Note {
    let name: String
    let frequency: Double

    var resourceName: String {
        name.replacingOccurrences(of: "#", with: "sharp")
    }
}

final class MelodyPlayer {
    private var index = 0

    private let notes: [Note] = [
        "G4", "F#4", "G4", "D4", "E4", "F#4", "G4", "A4", "B4", "C#5",
        "D5", "C#5", "D5", "A4", "B4", "C#5", "D5", "E5", "F#5", "D5",
        "G5", "F#5", "E5", "D5", "C#5", "E5", "A4", "G4",
        "F#4", "E4", "D4", "C#4", "D4", "F#4", "A4", "G4", "F#4", "A4", "D4",
        "D5", "C5", "D5", "G5", "B5", "D5",
        "E5", "D5", "E5", "A5", "C5", "E5",
        "F#5", "E5", "F#5", "D5", "A5", "C5",
        "C5", "B4", "G4", "B4", "D5", "G5", "D5", "G5", "A5",
        "B5", "G5", "D5", "B4", "G4", "B4", "D5", "G5", "B5", "G5", "F#5", "E5",
        "A5", "E5", "C#5", "A4", "F#4", "A4", "C#5", "E5", "A5", "F#5", "E5", "D5",
        "G5", "D5", "B4", "G4", "E4", "G4", "B4", "D5", "G5", "F#5", "E5", "D5",
        "C#5", "G4", "E4", "C#4", "A3", "C#4", "E4", "G4", "C#5", "E5", "D5", "C#5",
        "D5", "F#5", "A5", "D6", "F#6",
        "B4", "G4", "B4", "E5", "G5",
        "C#5", "E5", "A4", "G4", "F#4", "A4", "D5", "F#5", "G5", "E5", "D5", "C#5",
        "F#5", "D5", "C#5", "B4", "A4", "G4", "F#4", "E4", "D4"
    ].compactMap(Note.init(name:))

    func next() -> Note {
        let note = notes[index % notes.count]
        index += 1
        return note
    }
}

private extension Note {
    init?(name: String) {
        let pitchNames = [
            "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
            "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
        ]

        let pitch: String
        let octaveString: String

        if name.count == 3 {
            pitch = String(name.prefix(2))
            octaveString = String(name.suffix(1))
        } else {
            pitch = String(name.prefix(1))
            octaveString = String(name.suffix(name.count - 1))
        }

        guard let semitone = pitchNames[pitch], let octave = Int(octaveString) else {
            return nil
        }

        let midi = semitone + ((octave + 1) * 12)
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
        self.init(name: name, frequency: frequency)
    }
}
