import Foundation

enum PetState: String {
    case idle
    case runningRight
    case runningLeft
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    var row: Int {
        switch self {
        case .idle: return 0
        case .runningRight: return 1
        case .runningLeft: return 2
        case .waving: return 3
        case .jumping: return 4
        case .failed: return 5
        case .waiting: return 6
        case .running: return 7
        case .review: return 8
        }
    }

    var frames: Int {
        switch self {
        case .idle, .waiting, .running, .review: return 6
        case .runningRight, .runningLeft, .failed: return 8
        case .waving: return 4
        case .jumping: return 5
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .running: return 0.09
        case .runningRight, .runningLeft: return 0.12
        case .waving, .jumping, .failed: return 0.14
        case .waiting, .review: return 0.15
        case .idle: return 0.16
        }
    }

    var isQuietThinking: Bool {
        switch self {
        case .idle, .waiting:
            return true
        default:
            return false
        }
    }

    var shouldMirrorFrames: Bool {
        self == .running
    }
}
