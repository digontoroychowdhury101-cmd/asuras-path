// User-authorized command-line recording of the confirmed local Studio viewport only.
// swiftc -parse-as-library -module-cache-path work/swift-module-cache tools/qa/studio_record.swift -o work/bin/studio_record
// studio_record frame|record WINDOW_ID X Y WIDTH HEIGHT OUTPUT [SECONDS <= 20]
// Uses a window-specific ScreenCaptureKit filter; no other app, audio, microphone or cursor capture.
// Calibrate record mode with a short decoded video. In the tested macOS window, frame and record
// interpreted the vertical crop origin differently; a correct still did not prove video framing.
import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers
import Darwin

final class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    private let lock = NSLock()
    private var finished = false
    private var failure: String?
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print("RECORDING_STARTED")
        fflush(stdout)
    }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock(); finished = true; lock.unlock()
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        lock.lock(); failure = String(describing: error); finished = true; lock.unlock()
    }
    func state() -> (Bool, String?) {
        lock.lock(); defer { lock.unlock() }; return (finished, failure)
    }
}

@main @MainActor struct Recorder {
    static func main() async {
        do { try await run() }
        catch { fputs("CAPTURE_FAILED: \(error)\n", stderr); exit(1) }
    }
    static func run() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        _ = CGMainDisplayID()
        guard CGPreflightScreenCaptureAccess() else {
            throw NSError(domain:"macOS screen recording permission unavailable",code:8)
        }
        let a = CommandLine.arguments
        guard a.count >= 8, ["frame", "record"].contains(a[1]), let id = UInt32(a[2]),
              let x = Double(a[3]), let y = Double(a[4]), let w = Double(a[5]), let h = Double(a[6]),
              w >= 200, h >= 100 else { throw NSError(domain:"arguments",code:1) }
        let out = URL(fileURLWithPath:a[7]).standardizedFileURL
        let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("outputs").path + "/"
        guard out.path.hasPrefix(root), !FileManager.default.fileExists(atPath:out.path) else {
            throw NSError(domain:"output must be a new file inside project outputs",code:2)
        }
        print("CAPTURE_CONTENT_LOOKUP"); fflush(stdout)
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly:false)
        guard let window = content.windows.first(where: {
            $0.windowID == id && $0.owningApplication?.bundleIdentifier == "com.Roblox.RobloxStudio"
            && ($0.title ?? "").contains("/places/AsurasPath.rbxlx")
        }) else { throw NSError(domain:"confirmed local Studio window unavailable",code:3) }
        let filter = SCContentFilter(desktopIndependentWindow:window)
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = CGRect(x:x,y:y,width:w,height:h)
        cfg.width = Int(w*2); cfg.height = Int(h*2)
        cfg.capturesAudio = false
        cfg.captureMicrophone = false
        cfg.showsCursor = false
        cfg.ignoreShadowsSingleWindow = true
        cfg.minimumFrameInterval = CMTime(value:1,timescale:60)
        cfg.queueDepth = 5
        var metadata:[String:Any] = ["kind":"actual Studio viewport recording; window-specific filter",
            "windowID":id,"windowTitle":window.title ?? "", "sourceRectPoints":[x,y,w,h],
            "windowBounds":[window.frame.minX,window.frame.minY,window.frame.width,window.frame.height],
            "pixels":[cfg.width,cfg.height],"audio":false,"microphone":false,"cursor":false,
            "frontmostAtStart":NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            "startedUtc":ISO8601DateFormatter().string(from:Date())]
        if a[1] == "frame" {
            print("CAPTURE_FRAME"); fflush(stdout)
            let image = try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:cfg)
            guard let target = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString,1,nil) else {
                throw NSError(domain:"PNG destination failed",code:4)
            }
            CGImageDestinationAddImage(target,image,nil)
            guard CGImageDestinationFinalize(target) else { throw NSError(domain:"PNG write failed",code:5) }
        } else {
            guard a.count == 9, let seconds = Double(a[8]), seconds > 0, seconds <= 20 else {
                throw NSError(domain:"recording must be bounded to 20 seconds",code:6)
            }
            let delegate = RecordingDelegate()
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = out
            recordingConfig.outputFileType = .mp4
            recordingConfig.videoCodecType = .h264
            let recording = SCRecordingOutput(configuration:recordingConfig,delegate:delegate)
            let stream = SCStream(filter:filter,configuration:cfg,delegate:nil)
            try stream.addRecordingOutput(recording)
            try await stream.startCapture()
            try await Task.sleep(nanoseconds:UInt64(seconds*1_000_000_000))
            try await stream.stopCapture()
            for _ in 0..<100 {
                if delegate.state().0 { break }
                try await Task.sleep(nanoseconds:100_000_000)
            }
            let (done,failure) = delegate.state()
            guard done, failure == nil else { throw NSError(domain:failure ?? "recording did not finalize",code:7) }
            metadata["requestedSeconds"] = seconds
            metadata["recordedSeconds"] = CMTimeGetSeconds(recording.recordedDuration)
            metadata["recordedBytes"] = recording.recordedFileSize
        }
        metadata["frontmostAtEnd"] = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        metadata["endedUtc"] = ISO8601DateFormatter().string(from:Date())
        try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathExtension("json"),options:.withoutOverwriting)
        print("CAPTURE_SAVED",out.path)
    }
}
