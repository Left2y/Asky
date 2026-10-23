import AppKit
import ScreenCaptureKit
import CoreMedia

/// Test-only screen recording. Start this before launching the isolated Debug app.
@available(macOS 15, *)
final class PresentationFrames: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Double] = []
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sample.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }
        lock.lock()
        times.append(CMTimeGetSeconds(sample.presentationTimeStamp))
        lock.unlock()
    }
    func summary() -> String {
        lock.lock()
        defer { lock.unlock() }
        let gaps = zip(times.dropFirst(), times).map { $0 - $1 }
        return "completeFrames=\(times.count) maxFrameGapSeconds=\(gaps.max() ?? 0) requestedFPS=60"
    }
}

@available(macOS 15, *)
final class RecordingDelegate: NSObject, SCRecordingOutputDelegate, @unchecked Sendable {
    let finished = DispatchSemaphore(value: 0)
    let displayID: CGDirectDisplayID
    init(displayID: CGDirectDisplayID) { self.displayID = displayID }
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        FileHandle.standardOutput.write(Data("READY \(displayID)\n".utf8))
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        FileHandle.standardError.write(Data("recording failed: \(error)\n".utf8))
        exit(1)
    }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        FileHandle.standardOutput.write(Data("FINISHED\n".utf8))
        finished.signal()
    }
}

@main
@MainActor
enum LauncherPresentationRecorder {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("usage: recorder /absolute/output.mp4; close stdin to finish")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let display = content.displays.first { $0.displayID == id }!
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // Surround the launcher's final frame, including the region below its left corner.
        let visible = screen.visibleFrame
        let x = (visible.midX - 380 - screen.frame.minX).rounded()
        let y = (screen.frame.maxY - (visible.maxY - visible.height * 0.18) - 48).rounded()
        config.sourceRect = CGRect(x: max(0, x), y: max(0, y),
                                   width: min(760, screen.frame.width), height: min(560, screen.frame.height))
        config.width = Int(config.sourceRect.width * screen.backingScaleFactor)
        config.height = Int(config.sourceRect.height * screen.backingScaleFactor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 8
        config.showsCursor = false
        let frames = PresentationFrames()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(frames, type: .screen, sampleHandlerQueue: DispatchQueue(label: "presentation-frames"))
        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = URL(filePath: CommandLine.arguments[1])
        recordingConfig.videoCodecType = .h264
        recordingConfig.outputFileType = .mp4
        let delegate = RecordingDelegate(displayID: id)
        let recording = SCRecordingOutput(configuration: recordingConfig, delegate: delegate)
        try stream.addRecordingOutput(recording)
        try await stream.startCapture()
        _ = await Task.detached { FileHandle.standardInput.readDataToEndOfFile() }.value
        try await stream.stopCapture()
        let finalized: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: delegate.finished.wait(timeout: .now() + 10) == .success)
            }
        }
        guard finalized else { throw NSError(domain: "PresentationRecording", code: 1) }
        print(frames.summary())
    }
}
