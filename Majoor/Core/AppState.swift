import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Phase: String {
        case idle
        case listening
        case transcribing
        case thinking
        case executing
        case speaking
    }

    @Published var phase: Phase = .idle
    @Published var lastReply: String = ""

    static let shared = AppState()
    private init() {}
}
