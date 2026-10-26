// Records what the system actually plays (all apps, this process included) for a number
// of seconds into a mono 48kHz WAV, through ScreenCaptureKit. Needs the Screen Recording
// permission for the terminal that runs it. Usage: syscapture <seconds> <out.wav>
import AVFoundation
import ScreenCaptureKit

final class Sink: NSObject, SCStreamOutput, SCStreamDelegate {
    var samples: [Float] = []
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let block = sampleBuffer.dataBuffer else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr, let pointer else { return }
        let count = length / MemoryLayout<Float>.size
        pointer.withMemoryRebound(to: Float.self, capacity: count) { samples.append(contentsOf: UnsafeBufferPointer(start: $0, count: count)) }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { print("capture stopped: \(error)"); exit(1) }
}

let seconds = Double(CommandLine.arguments[1]) ?? 12
let out = URL(fileURLWithPath: CommandLine.arguments[2])
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else { print("no display"); exit(1) }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 48000
        config.channelCount = 1
        config.width = 2; config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let sink = Sink()
        let stream = SCStream(filter: filter, configuration: config, delegate: sink)
        try stream.addStreamOutput(sink, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio"))
        try await stream.startCapture()
        print("capturing")
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        try await stream.stopCapture()
        // Plain 16-bit WAV, which any tool can read.
        var data = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(sink.samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + bytes); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16); put16(1); put16(1); put32(48000); put32(96000); put16(2); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(bytes)
        for v in sink.samples { put16(UInt16(bitPattern: Int16(max(-1, min(1, v)) * 32767))) }
        try data.write(to: out)
        print("wrote \(sink.samples.count) samples to \(out.path)")
        exit(0)
    } catch { print("capture failed: \(error)"); exit(1) }
}
RunLoop.main.run()
