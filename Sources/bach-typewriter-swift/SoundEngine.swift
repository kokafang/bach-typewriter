import Foundation

final class SoundEngine {
    enum Instrument: Int, CaseIterable {
        case sampleHarpsichord
        case piano
        case celesta
        case harpsichord
        case churchOrgan

        var menuTitle: String {
            switch self {
            case .sampleHarpsichord: return "Harpsichord (Sample)"
            case .piano: return "Piano (GM)"
            case .celesta: return "Celesta (GM)"
            case .harpsichord: return "Harpsichord (GM)"
            case .churchOrgan: return "Church Organ (GM)"
            }
        }

        var usesSamplePlayer: Bool {
            self == .sampleHarpsichord
        }

        var helperCommandValue: String {
            if usesSamplePlayer {
                return "sample"
            }
            return "gm:\(rawValue)"
        }
    }

    var isEnabled = true
    var instrument: Instrument = .sampleHarpsichord
    private let fallbackSoundRoot = "/Users/jiafenggao/Documents/Obsidian/jiafeng-vault-air/bach-typewriter-swift/Sources/bach-typewriter-swift/Resources/Sounds"
    private var helperProcess: Process?
    private var helperInput: Pipe?

    func play(note: Note) {
        guard isEnabled else { return }
        if sendToHelper(note: note) {
            return
        }

        let soundURL = Bundle.module.url(
            forResource: note.resourceName,
            withExtension: "wav",
            subdirectory: "Sounds"
        ) ?? URL(fileURLWithPath: "\(fallbackSoundRoot)/\(note.resourceName).wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        process.arguments = [soundURL.path]
        try? process.run()
    }

    func playTestNote() {
        play(note: Note(name: "G4", frequency: 392.0))
    }

    private func sendToHelper(note: Note) -> Bool {
        guard startHelperIfNeeded() else { return false }
        guard let input = helperInput else { return false }

        let noteValue = instrument.usesSamplePlayer ? note.resourceName : note.name
        let line = "\(instrument.helperCommandValue)|\(noteValue)\n"
        guard let data = line.data(using: .utf8) else { return false }

        input.fileHandleForWriting.write(data)
        if helperProcess?.isRunning == true {
            return true
        }
        helperProcess = nil
        helperInput = nil
        return false
    }

    private func startHelperIfNeeded() -> Bool {
        if helperProcess?.isRunning == true {
            return true
        }

        guard let helperURL = helperExecutableURL() else {
            return false
        }

        let input = Pipe()
        let output = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = helperURL
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorPipe

        var environment = ProcessInfo.processInfo.environment
        environment["BACH_SOUND_ROOT"] = soundRootURL().path
        process.environment = environment

        do {
            try process.run()
            helperProcess = process
            helperInput = input
            return true
        } catch {
            return false
        }
    }

    private func helperExecutableURL() -> URL? {
        let appHelper = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("BachAudioHelper")
        if FileManager.default.isExecutableFile(atPath: appHelper.path) {
            return appHelper
        }

        let devHelper = URL(fileURLWithPath: "/Users/jiafenggao/Documents/Obsidian/jiafeng-vault-air/bach-typewriter-swift/.build/arm64-apple-macosx/debug/BachAudioHelper")
        if FileManager.default.isExecutableFile(atPath: devHelper.path) {
            return devHelper
        }

        return nil
    }

    private func soundRootURL() -> URL {
        if let g4URL = Bundle.module.url(
            forResource: "G4",
            withExtension: "wav",
            subdirectory: "Sounds"
        ) {
            return g4URL.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: fallbackSoundRoot)
    }
}
