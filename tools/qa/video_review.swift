// Review a recorded project clip and make a smaller viewing copy without retiming.
// swiftc -parse-as-library -module-cache-path work/swift-module-cache tools/qa/video_review.swift -o work/bin/video_review
// video_review INPUT.mp4 NEW_OUTPUT_DIRECTORY
import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

@main struct Review {
    static func main() async {
        do { try await run() }
        catch { fputs("VIDEO_REVIEW_FAILED: \(error)\n",stderr); exit(1) }
    }
    static func run() async throws {
        guard CommandLine.arguments.count == 3 else { throw NSError(domain:"arguments",code:1) }
        let input = URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
        let out = URL(fileURLWithPath:CommandLine.arguments[2]).standardizedFileURL
        let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("outputs").path + "/"
        guard input.path.hasPrefix(root), out.path.hasPrefix(root),
              !FileManager.default.fileExists(atPath:out.path) else { throw NSError(domain:"project outputs only; no overwrite",code:2) }
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let source = AVURLAsset(url:input)
        guard let export = AVAssetExportSession(asset:source,presetName:AVAssetExportPreset1920x1080) else {
            throw NSError(domain:"viewing-copy encoder unavailable",code:3)
        }
        let copy = out.appendingPathComponent("clip.mp4")
        export.shouldOptimizeForNetworkUse = true
        try await export.export(to:copy,as:.mp4)
        let asset = AVURLAsset(url:copy)
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        let sourceDuration = CMTimeGetSeconds(try await source.load(.duration))
        let videos = try await asset.loadTracks(withMediaType:.video)
        let audios = try await asset.loadTracks(withMediaType:.audio)
        guard videos.count == 1, audios.isEmpty, abs(duration-sourceDuration) < 0.05 else {
            throw NSError(domain:"unexpected tracks or duration change",code:5)
        }
        let size = try await videos[0].load(.naturalSize)
        let fps = try await videos[0].load(.nominalFrameRate)
        let reader = try AVAssetReader(asset:asset)
        let track = AVAssetReaderTrackOutput(track:videos[0],outputSettings:nil)
        reader.add(track)
        guard reader.startReading() else { throw reader.error ?? NSError(domain:"reader failed",code:6) }
        var samples = 0
        var pts:[Double] = []
        while let buffer = track.copyNextSampleBuffer() {
            samples += CMSampleBufferGetNumSamples(buffer)
            pts.append(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(buffer)))
        }
        guard reader.status == .completed, samples>1 else { throw reader.error ?? NSError(domain:"incomplete media",code:7) }
        let generator = AVAssetImageGenerator(asset:asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var frames:[[String:Any]] = []
        for second in [0.0,4,8,12,16,min(19,duration - 0.1)] where second<duration {
            let time = CMTime(seconds:second,preferredTimescale:600)
            let (image,actual) = try await generator.image(at:time)
            let file = out.appendingPathComponent(String(format:"frame_%05.2f.png",second))
            guard let destination = CGImageDestinationCreateWithURL(file as CFURL,UTType.png.identifier as CFString,1,nil) else {
                throw NSError(domain:"frame destination failed",code:8)
            }
            CGImageDestinationAddImage(destination,image,nil)
            guard CGImageDestinationFinalize(destination) else { throw NSError(domain:"frame write failed",code:9) }
            frames.append(["file":file.lastPathComponent,"requestedSeconds":second,"actualSeconds":CMTimeGetSeconds(actual)])
        }
        let sourceHash = SHA256.hash(data:try Data(contentsOf:input,options:.mappedIfSafe)).map { String(format:"%02x",$0) }.joined()
        let copyHash = SHA256.hash(data:try Data(contentsOf:copy,options:.mappedIfSafe)).map { String(format:"%02x",$0) }.joined()
        let report:[String:Any] = ["kind":"decoded recorded video; resized viewing copy, no retiming or synthetic frames",
            "source":input.path,"sourceSHA256":sourceHash,"sourceDurationSeconds":sourceDuration,
            "copy":"clip.mp4","copySHA256":copyHash,"durationSeconds":duration,"pixels":[size.width,size.height],
            "audioTracks":audios.count,"encodedSamples":samples,"nominalCaptureFps":fps,
            "firstPTS":pts.min() ?? 0,"lastPTS":pts.max() ?? 0,
            "warning":"capture FPS is not foreground game performance","frames":frames]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("media.json"),options:.withoutOverwriting)
        print("VIDEO_REVIEW_SAVED",out.path,"seconds",duration,"samples",samples)
    }
}
