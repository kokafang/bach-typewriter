import Foundation

final class SoundEngine {
    enum Instrument: Int, CaseIterable {
        case celesta = 2
        case nyaSample = 5
        case harpsichord = 3
        case churchOrgan = 4
        case piano = 1
        case sampleHarpsichord = 0

        var menuTitle: String {
            switch self {
            case .sampleHarpsichord: return "Harpsichord (Sample)"
            case .piano: return "Piano (GM)"
            case .celesta: return "Celesta (GM)"
            case .harpsichord: return "Harpsichord (GM)"
            case .churchOrgan: return "Church Organ (GM)"
            case .nyaSample: return "Nya (Sample)"
            }
        }

        var usesSamplePlayer: Bool {
            switch self {
            case .sampleHarpsichord, .nyaSample: return true
            case .piano, .celesta, .harpsichord, .churchOrgan: return false
            }
        }

        func sampleResourceName(for note: Note) -> String {
            switch self {
            case .sampleHarpsichord: return note.resourceName
            case .nyaSample: return note.resourceName
            case .piano, .celesta, .harpsichord, .churchOrgan: return note.name
            }
        }

        func fallbackResourceName(for note: Note) -> String {
            switch self {
            case .nyaSample: return "nya"
            case .sampleHarpsichord, .piano, .celesta, .harpsichord, .churchOrgan:
                return note.resourceName
            }
        }

        var helperCommandValue: String {
            switch self {
            case .sampleHarpsichord:
                return "sample"
            case .nyaSample:
                return "sample-pitched:nya:G4"
            case .piano, .celesta, .harpsichord, .churchOrgan:
                return "gm:\(rawValue)"
            }
        }
    }

    var isEnabled = true
    var instrument: Instrument = .celesta
    private var helperProcess: Process?
    private var helperInput: Pipe?

    func play(note: Note) {
        guard isEnabled else { return }
        if sendToHelper(note: note) {
            return
        }

        let fallbackResourceName = instrument.fallbackResourceName(for: note)
        guard let soundURL = AppResources.url(
            forResource: fallbackResourceName,
            withExtension: "wav",
            subdirectory: "Sounds"
        ) else {
            return
        }

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

        let noteValue = instrument.usesSamplePlayer ? instrument.sampleResourceName(for: note) : note.name
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

        guard let executableURL = Bundle.main.executableURL else {
            return nil
        }

        let devHelper = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("BachAudioHelper")
        if FileManager.default.isExecutableFile(atPath: devHelper.path) {
            return devHelper
        }

        return nil
    }

    private func soundRootURL() -> URL {
        AppResources.directory(subdirectory: "Sounds")
    }
}
