import Foundation

/// Watches one file and reports when it changes on disk.
///
/// The watcher combines two vnode sources: one on the file itself for writes
/// in place, and one on the parent directory for writes that replace the file
/// (write to a temporary file, then rename). A directory event re-attaches the
/// file source, so a rewritten file keeps being watched.
///
/// Events are coalesced: `onChange` runs on the main actor at most once per
/// quiet period, so a burst of writes becomes a single notification. The
/// watcher only reports that *something* may have changed; the caller compares
/// file attributes to decide whether a reload is needed.
///
/// Starting is best-effort. If the file or its directory cannot be opened, the
/// watcher stays quiet. A file that is not watched is still readable, so no
/// error is surfaced.
final class TrajectoryFileWatcher {
    let url: URL

    private static let coalescingDelay: TimeInterval = 0.25

    private let onChange: @MainActor () -> Void
    private let queue = DispatchQueue(label: "io.harborlens.trajectory-file-watcher")
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pendingNotification: DispatchWorkItem?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        directorySource?.cancel()
        fileSource?.cancel()
    }

    func start() {
        queue.async { self.startOnQueue() }
    }

    func cancel() {
        queue.async { self.cancelOnQueue() }
    }

    private func startOnQueue() {
        guard directorySource == nil else { return }

        let directoryDescriptor = open(url.deletingLastPathComponent().path, O_EVTONLY)
        guard directoryDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // A directory event can mean the file was created, replaced, or
            // removed; re-attach so the file source follows the current file.
            attachFileSourceOnQueue()
            scheduleNotification()
        }
        source.setCancelHandler { close(directoryDescriptor) }
        directorySource = source
        source.resume()

        attachFileSourceOnQueue()
    }

    private func attachFileSourceOnQueue() {
        detachFileSourceOnQueue()

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.scheduleNotification() }
        source.setCancelHandler { close(descriptor) }
        fileSource = source
        source.resume()
    }

    private func detachFileSourceOnQueue() {
        fileSource?.cancel()
        fileSource = nil
    }

    private func cancelOnQueue() {
        pendingNotification?.cancel()
        pendingNotification = nil
        directorySource?.cancel()
        directorySource = nil
        detachFileSourceOnQueue()
    }

    private func scheduleNotification() {
        pendingNotification?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            pendingNotification = nil
            Task { @MainActor in self.onChange() }
        }
        pendingNotification = item
        queue.asyncAfter(deadline: .now() + Self.coalescingDelay, execute: item)
    }
}
