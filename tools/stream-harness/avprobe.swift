// AVPlayer probe for Ondu streaming experiments.
//   avprobe probe <url>            duration, seekable ranges, seek to 60%, play 1s
//   avprobe gapless <url1> <url2>  AVQueuePlayer; counts rendered frames per item via an
//                                  audio tap and leading/trailing near-silent frames, so
//                                  untrimmed priming/padding (a gap) shows up as numbers.
import AVFoundation
import MediaToolbox
import QuartzCore

final class TapStats {
    var frames: Int64 = 0
    var leadingSilence: Int64 = 0
    var trailingSilence: Int64 = 0
    var sawSignal = false
    /// Host time of the first and last buffer that carried signal, and how long the last one was.
    var firstSignalAt: Double?
    var lastSignalAt: Double?
    var lastSignalBufferSeconds = 0.0
    var channels = 2
    var interleaved = false
    var sampleRate = 0.0
    let name: String
    init(_ name: String) { self.name = name }
}

func makeTap(_ stats: TapStats) -> MTAudioProcessingTap? {
    var callbacks = MTAudioProcessingTapCallbacks(
        version: kMTAudioProcessingTapCallbacksVersion_0,
        clientInfo: Unmanaged.passUnretained(stats).toOpaque(),
        init: { tap, clientInfo, tapStorageOut in tapStorageOut.pointee = clientInfo },
        finalize: { _ in },
        prepare: { tap, maxFrames, format in
            let s = Unmanaged<TapStats>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
            s.channels = Int(format.pointee.mChannelsPerFrame)
            s.interleaved = (format.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
            s.sampleRate = format.pointee.mSampleRate
        },
        unprepare: { _ in },
        process: { tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
            let s = Unmanaged<TapStats>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
            let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
            guard status == noErr else { return }
            let n = Int(numberFramesOut.pointee)
            let abl = UnsafeMutableAudioBufferListPointer(bufferListInOut)
            guard let buf = abl.first, let data = buf.mData else { return }
            let samples = data.assumingMemoryBound(to: Float.self)
            let stride = s.interleaved ? s.channels : 1
            var signalInBuffer = false
            for i in 0..<n {
                let v = abs(samples[i * stride])
                if v > 0.001 { s.sawSignal = true; s.trailingSilence = 0; signalInBuffer = true }
                else if s.sawSignal { s.trailingSilence += 1 } else { s.leadingSilence += 1 }
            }
            if signalInBuffer {
                let now = CACurrentMediaTime()
                if s.firstSignalAt == nil { s.firstSignalAt = now }
                s.lastSignalAt = now
                s.lastSignalBufferSeconds = Double(n) / s.sampleRate
            }
            s.frames += Int64(n)
        })
    var tap: MTAudioProcessingTap?
    let err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
    guard err == noErr, let t = tap else { print("tap create failed \(err)"); return nil }
    return t
}

@MainActor func item(_ url: URL, stats: TapStats?) async throws -> AVPlayerItem {
    let asset = AVURLAsset(url: url)
    let it = AVPlayerItem(asset: asset)
    if let stats, let tap = makeTap(stats) {
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        if let track = tracks.first {
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            let mix = AVMutableAudioMix(); mix.inputParameters = [params]
            it.audioMix = mix
        } else { print("  (no audio track loadable, tap skipped)") }
    }
    return it
}

func waitReady(_ it: AVPlayerItem, timeout: Double = 15) async -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if it.status == .readyToPlay { return true }
        if it.status == .failed { print("  FAILED: \(it.error?.localizedDescription ?? "?")"); return false }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    print("  TIMEOUT waiting for readyToPlay (status \(it.status.rawValue))"); return false
}

func fmt(_ t: CMTime) -> String { t.isIndefinite ? "indefinite" : (t.isValid ? String(format: "%.3f", t.seconds) : "invalid") }

func probe(_ url: URL) async throws {
    print("PROBE \(url.lastPathComponent)\(url.query.map { "?" + $0 } ?? "")")
    let it = try await item(url, stats: nil)
    let p = AVPlayer(playerItem: it); p.volume = 0
    let t0 = Date()
    guard await waitReady(it, timeout: 40) else { return }
    print(String(format: "  readyToPlay after %.2fs", Date().timeIntervalSince(t0)))
    let d = it.duration
    print("  duration=\(fmt(d)) assetDuration=\(fmt(try await it.asset.load(.duration)))")
    let seekable = it.seekableTimeRanges.map { $0.timeRangeValue }.map { "\(fmt($0.start))-\(fmt($0.end))" }
    print("  seekableTimeRanges=\(seekable)")
    p.play()
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    print("  after 1s play: currentTime=\(fmt(p.currentTime())) rate=\(p.rate)")
    let target = d.isIndefinite ? CMTime(seconds: 3, preferredTimescale: 600) : CMTimeMultiplyByFloat64(d, multiplier: 0.6)
    let ok = await it.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    try? await Task.sleep(nanoseconds: 700_000_000)
    print("  seek to \(fmt(target)): completed=\(ok) currentTime=\(fmt(p.currentTime())) rate=\(p.rate) stalled=\(it.isPlaybackBufferEmpty)")
    p.pause()
}

func gapless(_ u1: URL, _ u2: URL) async throws {
    // AVPROBE_TAP=0 plays without the audio tap: the tap gives the frame counts but
    // attaches an audio mix to each item, which may itself cost a gapless handoff.
    // AVPROBE_NOSTALL=1 sets automaticallyWaitsToMinimizeStalling = false, as the app
    // does for local files.
    let env = ProcessInfo.processInfo.environment
    let tap = env["AVPROBE_TAP"] != "0"
    print("GAPLESS \(u1.lastPathComponent) -> \(u2.lastPathComponent)\(tap ? "" : " (no tap)")\(env["AVPROBE_NOSTALL"] == "1" ? " (no stall wait)" : "")")
    let s1 = TapStats("item1"), s2 = TapStats("item2")
    let i1 = try await item(u1, stats: tap ? s1 : nil), i2 = try await item(u2, stats: tap ? s2 : nil)
    let q = AVQueuePlayer(items: [i1, i2]); q.volume = env["AVPROBE_VOLUME"].flatMap(Float.init) ?? 0
    if env["AVPROBE_NOSTALL"] == "1" { q.automaticallyWaitsToMinimizeStalling = false }
    // Only the first item: a queue loads the next one once the current one plays.
    guard await waitReady(i1) else { return }
    var t1End: Date?, t2Start: Date?
    let obs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { n in
        if (n.object as AnyObject?) === i1 { t1End = Date() }
    }
    q.play()
    let start = Date()
    while q.currentItem != nil && Date().timeIntervalSince(start) < 30 {
        if q.currentItem === i2 && t2Start == nil { t2Start = Date() }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    NotificationCenter.default.removeObserver(obs)
    for s in [s1, s2] where tap {
        let expected = Int64(220500.0 * s.sampleRate / 44100.0)
        let signal = s.frames - s.leadingSilence - s.trailingSilence
        print("  \(s.name): signalFrames=\(signal) expected=\(expected) diff=\(signal - expected) (\(String(format: "%.1f", Double(signal - expected) / s.sampleRate * 1000)) ms) @\(Int(s.sampleRate))Hz  [rendered=\(s.frames) lead=\(s.leadingSilence) tail=\(s.trailingSilence)]")
    }
    if let a = t1End, let b = t2Start { print(String(format: "  wallclock item1 end -> item2 current: %.0f ms (coarse, 20ms poll)", b.timeIntervalSince(a) * 1000)) }
    // The render pulls item 2's first signal buffer some time after item 1's last one. On
    // a continuous handoff that is about the last buffer's own length (or less, when item
    // 2 is pre-rolled); anything well beyond it is time the output had nothing to play.
    if let last1 = s1.lastSignalAt, let first2 = s2.firstSignalAt {
        let handoff = (first2 - last1 - s1.lastSignalBufferSeconds) * 1000
        print(String(format: "  render handoff: item2 first signal buffer came %.1f ms after item1's last one ended (last buffer %.1f ms)", handoff, s1.lastSignalBufferSeconds * 1000))
    }
}

let args = CommandLine.arguments
Task {
    do {
        switch args.count > 1 ? args[1] : "" {
        case "probe": try await probe(URL(string: args[2])!)
        case "gapless": try await gapless(URL(string: args[2])!, URL(string: args[3])!)
        default: print("usage: avprobe probe <url> | gapless <url1> <url2>")
        }
    } catch { print("error: \(error)") }
    exit(0)
}
RunLoop.main.run()
