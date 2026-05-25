import AVFoundation
import AudioToolbox
import Foundation

final class EnginePlayer {
    enum GMInstrument: Int {
        case piano = 1
        case celesta = 2
        case harpsichord = 3
        case churchOrgan = 4

        var program: UInt8 {
            switch self {
            case .piano: return 0
            case .celesta: return 8
            case .harpsichord: return 6
            case .churchOrgan: return 19
            }
        }

        var noteLength: TimeInterval {
            switch self {
            case .churchOrgan: return 0.55
            case .celesta: return 0.9
            case .piano: return 0.75
            case .harpsichord: return 0.45
            }
        }
    }

    private let engine = AVAudioEngine()
    private let samplePlayer = AVAudioPlayerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var sampleFormat: AVAudioFormat?
    private var sampler: AVAudioUnitSampler?
    private let soundBankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    private var currentGMInstrument: GMInstrument?

    init(soundRoot: URL) throws {
        try loadBuffers(soundRoot: soundRoot)
        engine.attach(samplePlayer)
        engine.connect(samplePlayer, to: engine.mainMixerNode, format: sampleFormat)
        engine.mainMixerNode.outputVolume = 0.9
        try engine.start()
        samplePlayer.play()
    }

    func playSample(_ name: String) {
        guard let buffer = buffers[name] else { return }
        if !samplePlayer.isPlaying {
            samplePlayer.play()
        }
        samplePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    func playGM(note noteName: String, instrument: GMInstrument) {
        do {
            let sampler = try samplerForInstrument(instrument)
            guard let midiNote = midiNoteNumber(for: noteName) else { return }
            let velocity: UInt8 = instrument == .churchOrgan ? 84 : 96
            sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + instrument.noteLength) { [weak sampler] in
                sampler?.stopNote(midiNote, onChannel: 0)
            }
        } catch {
            fputs("BachAudioHelper GM playback failed: \(error)\n", stderr)
        }
    }

    private func loadBuffers(soundRoot: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: soundRoot,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "wav" }

        for fileURL in files {
            let file = try AVAudioFile(forReading: fileURL)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                continue
            }
            try file.read(into: buffer)
            let name = fileURL.deletingPathExtension().lastPathComponent
            buffers[name] = buffer
            if sampleFormat == nil {
                sampleFormat = file.processingFormat
            }
        }
    }

    private func samplerForInstrument(_ instrument: GMInstrument) throws -> AVAudioUnitSampler {
        if let sampler, currentGMInstrument == instrument {
            return sampler
        }

        let sampler = self.sampler ?? AVAudioUnitSampler()
        if self.sampler == nil {
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
            if !engine.isRunning {
                try engine.start()
            }
            self.sampler = sampler
        }

        try sampler.loadSoundBankInstrument(
            at: soundBankURL,
            program: instrument.program,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        currentGMInstrument = instrument
        return sampler
    }

    private func midiNoteNumber(for name: String) -> UInt8? {
        let normalized = name.replacingOccurrences(of: "sharp", with: "#")
        let pitchNames = [
            "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
            "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
        ]

        let pitch: String
        let octaveString: String
        if normalized.count >= 3, normalized.dropFirst().first == "#" {
            pitch = String(normalized.prefix(2))
            octaveString = String(normalized.dropFirst(2))
        } else {
            pitch = String(normalized.prefix(1))
            octaveString = String(normalized.dropFirst(1))
        }

        guard let semitone = pitchNames[pitch], let octave = Int(octaveString) else {
            return nil
        }

        let midi = semitone + ((octave + 1) * 12)
        guard midi >= 0, midi <= 127 else { return nil }
        return UInt8(midi)
    }
}

let soundRootPath = ProcessInfo.processInfo.environment["BACH_SOUND_ROOT"] ?? ""
let soundRoot = URL(fileURLWithPath: soundRootPath)

do {
    let player = try EnginePlayer(soundRoot: soundRoot)
    print("BachAudioHelper ready")
    fflush(stdout)

    while let line = readLine() {
        let command = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if command == "quit" {
            break
        }

        let components = command.split(separator: "|", maxSplits: 1).map(String.init)
        guard components.count == 2 else {
            player.playSample(command)
            continue
        }

        let mode = components[0]
        let noteName = components[1]
        if mode == "sample" {
            player.playSample(noteName)
            continue
        }

        if mode.hasPrefix("gm:"),
           let instrumentValue = Int(mode.dropFirst(3)),
           let instrument = EnginePlayer.GMInstrument(rawValue: instrumentValue) {
            player.playGM(note: noteName, instrument: instrument)
            continue
        }

        player.playSample(noteName)
    }
} catch {
    fputs("BachAudioHelper failed: \(error)\n", stderr)
    exit(1)
}
