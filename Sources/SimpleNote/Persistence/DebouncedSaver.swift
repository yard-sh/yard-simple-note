import Foundation

@MainActor
final class DebouncedSaver {
    private let delay: Duration
    private let action: @MainActor () async -> Void
    private var task: Task<Void, Never>?

    init(delay: Duration = .milliseconds(400), action: @MainActor @escaping () async -> Void) {
        self.delay = delay
        self.action = action
    }

    func schedule() {
        task?.cancel()
        task = Task { [delay, action] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            if Task.isCancelled { return }
            await action()
        }
    }

    /// Run the action immediately, cancelling any pending debounce.
    func flush() async {
        task?.cancel()
        task = nil
        await action()
    }
}
