import Foundation

public final class FolderMonitor: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "sublerplus.folder.monitor")

    public init() {}

    public func startMonitoring(url: URL, onChange: @escaping () -> Void) throws {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}

