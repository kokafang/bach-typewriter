import Foundation

enum GoldbergLibrary {
    private struct LibraryFile: Decodable {
        let tracks: [TrackFile]
    }

    private struct TrackFile: Decodable {
        let id: String
        let title: String
        let noteNames: [String]
    }

    static func loadTracks() -> [MelodyTrack] {
        let nestedURL = Bundle.module.url(
            forResource: "GoldbergLibrary",
            withExtension: "json",
            subdirectory: "Library"
        )
        let flatURL = Bundle.module.url(forResource: "GoldbergLibrary", withExtension: "json")

        guard let url = nestedURL ?? flatURL else {
            print("Bach melody library missing: GoldbergLibrary.json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let library = try JSONDecoder().decode(LibraryFile.self, from: data)
            return library.tracks.compactMap { track in
                let notes = track.noteNames.compactMap(Note.init(name:))
                guard !notes.isEmpty else { return nil }
                return MelodyTrack(id: track.id, title: track.title, notes: notes)
            }
        } catch {
            print("Bach melody library failed to load: \(error)")
            return []
        }
    }
}
