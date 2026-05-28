import AVFoundation
import AudioToolbox
import Foundation

final class EnginePlayer {
    private struct SampleVoice {
        let player: AVAudioPlayerNode
        let pitch: AVAudioUnitTimePitch
    }

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
            case .piano: return 0.28
            case .harpsichord: return 0.45
            }
        }

        var shouldChokePreviousNotes: Bool {
            switch self {
            case .piano, .harpsichord, .churchOrgan: return true
            case .celesta: return false
            }
        }

        var idleChokeDelay: TimeInterval {
            switch self {
            case .piano, .harpsichord, .churchOrgan: return 0.2
            case .celesta: return 1.0
            }
        }
    }

    private let engine = AVAudioEngine()
    private let sampleVoices = (0..<16).map { _ in
        SampleVoice(player: AVAudioPlayerNode(), pitch: AVAudioUnitTimePitch())
    }
    private var nextSampleVoiceIndex = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var sampleMidiNotes: [String: Int] = [:]
    private var nearestSampleCache: [String: String] = [:]
    private var sampleFormat: AVAudioFormat?
    private var sampler: AVAudioUnitSampler?
    private let soundBankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    private var currentGMInstrument: GMInstrument?
    private let noteStateLock = NSLock()
    private var activeGMNoteTokens: [UInt8: Int] = [:]
    private var nextGMNoteToken = 0
    private var idleChokeToken = 0
    private var configurationObserver: NSObjectProtocol?

    init(soundRoot: URL) throws {
        try loadBuffers(soundRoot: soundRoot)
        for sampleVoice in sampleVoices {
            engine.attach(sampleVoice.player)
            engine.attach(sampleVoice.pitch)
            engine.connect(sampleVoice.player, to: sampleVoice.pitch, format: sampleFormat)
            engine.connect(sampleVoice.pitch, to: engine.mainMixerNode, format: sampleFormat)
        }
        engine.mainMixerNode.outputVolume = 0.9
        installConfigurationObserver()
        try restartEngine()
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    func playSample(_ name: String) {
        let sampleName = buffers[name] == nil ? nearestSampleName(for: name) : name
        guard let sampleName, let buffer = buffers[sampleName] else { return }
        do {
            try ensureEngineRunning()
        } catch {
            fputs("BachAudioHelper sample engine restart failed: \(error)\n", stderr)
            return
        }
        playSampleBuffer(buffer, pitchCents: 0)
    }

    func playPitchedSample(_ sampleName: String, targetNoteName: String, rootNoteName: String) {
        guard let buffer = buffers[sampleName],
              let targetMidiNote = midiNoteNumber(for: targetNoteName),
              let rootMidiNote = midiNoteNumber(for: rootNoteName) else {
            playSample(sampleName)
            return
        }
        do {
            try ensureEngineRunning()
        } catch {
            fputs("BachAudioHelper pitched sample engine restart failed: \(error)\n", stderr)
            return
        }
        let pitchCents = Float(Int(targetMidiNote) - Int(rootMidiNote)) * 100
        playSampleBuffer(buffer, pitchCents: pitchCents)
    }

    func playGM(note noteName: String, instrument: GMInstrument) {
        do {
            let sampler = try samplerForInstrument(instrument)
            guard let midiNote = midiNoteNumber(for: noteName) else { return }
            let velocity: UInt8 = instrument == .churchOrgan ? 84 : 96
            sampler.sendController(64, withValue: 0, onChannel: 0)
            if instrument.shouldChokePreviousNotes {
                releaseActiveGMNotes(on: sampler)
            }
            let (noteToken, idleToken) = registerStartedGMNote(midiNote)
            sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
            if !instrument.shouldChokePreviousNotes {
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + instrument.noteLength) { [weak self, weak sampler] in
                    guard self?.shouldStopGMNote(midiNote, noteToken: noteToken) == true else { return }
                    sampler?.stopNote(midiNote, onChannel: 0)
                }
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + instrument.idleChokeDelay) { [weak self, weak sampler] in
                guard let self, let sampler, self.shouldIdleChoke(idleToken: idleToken) else { return }
                self.stopActiveGMNotes(on: sampler)
            }
        } catch {
            fputs("BachAudioHelper GM playback failed: \(error)\n", stderr)
        }
    }

    private func installConfigurationObserver() {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.handleEngineConfigurationChange()
        }
    }

    private func handleEngineConfigurationChange() {
        currentGMInstrument = nil
        do {
            try restartEngine()
            fputs("BachAudioHelper recovered from audio device change\n", stderr)
        } catch {
            fputs("BachAudioHelper audio device recovery failed: \(error)\n", stderr)
        }
    }

    private func ensureEngineRunning() throws {
        if engine.isRunning {
            return
        }
        try restartEngine()
    }

    private func restartEngine() throws {
        if engine.isRunning {
            engine.stop()
        }
        for sampleVoice in sampleVoices {
            sampleVoice.player.stop()
        }
        engine.reset()
        try engine.start()
    }

    private func playSampleBuffer(_ buffer: AVAudioPCMBuffer, pitchCents: Float) {
        let sampleVoice = nextSampleVoice()
        sampleVoice.pitch.pitch = pitchCents
        sampleVoice.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !sampleVoice.player.isPlaying {
            sampleVoice.player.play()
        }
    }

    private func nextSampleVoice() -> SampleVoice {
        let voice = sampleVoices[nextSampleVoiceIndex]
        nextSampleVoiceIndex = (nextSampleVoiceIndex + 1) % sampleVoices.count
        return voice
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
            sampleMidiNotes[name] = midiNoteNumber(for: name).map(Int.init)
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
            self.sampler = sampler
        }

        try ensureEngineRunning()
        try sampler.loadSoundBankInstrument(
            at: soundBankURL,
            program: instrument.program,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        currentGMInstrument = instrument
        return sampler
    }

    private func registerStartedGMNote(_ midiNote: UInt8) -> (noteToken: Int, idleToken: Int) {
        noteStateLock.lock()
        defer { noteStateLock.unlock() }
        nextGMNoteToken += 1
        idleChokeToken += 1
        activeGMNoteTokens[midiNote] = nextGMNoteToken
        return (nextGMNoteToken, idleChokeToken)
    }

    private func shouldStopGMNote(_ midiNote: UInt8, noteToken: Int) -> Bool {
        noteStateLock.lock()
        defer { noteStateLock.unlock() }
        guard activeGMNoteTokens[midiNote] == noteToken else {
            return false
        }
        activeGMNoteTokens.removeValue(forKey: midiNote)
        return true
    }

    private func shouldIdleChoke(idleToken: Int) -> Bool {
        noteStateLock.lock()
        defer { noteStateLock.unlock() }
        return idleChokeToken == idleToken
    }

    private func releaseActiveGMNotes(on sampler: AVAudioUnitSampler) {
        noteStateLock.lock()
        let notes = Array(activeGMNoteTokens.keys)
        activeGMNoteTokens.removeAll()
        noteStateLock.unlock()

        sampler.sendController(64, withValue: 0, onChannel: 0)
        for note in notes {
            sampler.stopNote(note, onChannel: 0)
        }
    }

    private func silenceGM(on sampler: AVAudioUnitSampler) {
        sampler.sendController(64, withValue: 0, onChannel: 0)
        sampler.sendController(123, withValue: 0, onChannel: 0)
        sampler.sendController(120, withValue: 0, onChannel: 0)
    }

    private func stopActiveGMNotes(on sampler: AVAudioUnitSampler) {
        noteStateLock.lock()
        let notes = Array(activeGMNoteTokens.keys)
        activeGMNoteTokens.removeAll()
        noteStateLock.unlock()

        silenceGM(on: sampler)
        for note in notes {
            sampler.stopNote(note, onChannel: 0)
        }
    }

    private func nearestSampleName(for name: String) -> String? {
        if let cached = nearestSampleCache[name] {
            return cached
        }

        guard let target = midiNoteNumber(for: name).map(Int.init) else {
            return nil
        }

        let nearest = sampleMidiNotes.min { left, right in
            abs(left.value - target) < abs(right.value - target)
        }?.key
        nearestSampleCache[name] = nearest
        return nearest
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

        if mode.hasPrefix("sample-pitched:") {
            let parameters = mode.split(separator: ":").map(String.init)
            if parameters.count == 3 {
                player.playPitchedSample(parameters[1], targetNoteName: noteName, rootNoteName: parameters[2])
                continue
            }
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
