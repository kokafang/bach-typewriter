import Foundation

struct Note {
    let name: String
    let frequency: Double

    var resourceName: String {
        name.replacingOccurrences(of: "#", with: "sharp")
    }
}

struct MelodyTrack {
    let id: String
    let title: String
    let notes: [Note]
}

final class MelodyPlayer {
    private static let defaultTrackID = "goldberg-var-01"

    private var index = 0
    private(set) var selectedTrack: MelodyTrack
    let tracks: [MelodyTrack]

    init() {
        let libraryTracks = GoldbergLibrary.loadTracks()
        tracks = libraryTracks
        selectedTrack = libraryTracks.first(where: { $0.id == Self.defaultTrackID })
            ?? libraryTracks.first
            ?? MelodyTrack(
                id: Self.defaultTrackID,
                title: "Goldberg Variation 1",
                notes: ["G4"].compactMap(Note.init(name:))
            )
    }

    func next() -> Note {
        let note = selectedTrack.notes[index % selectedTrack.notes.count]
        index += 1
        return note
    }

    func selectTrack(id: String) {
        guard let track = tracks.first(where: { $0.id == id }) else { return }
        selectedTrack = track
        index = 0
    }
}

extension Note {
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
