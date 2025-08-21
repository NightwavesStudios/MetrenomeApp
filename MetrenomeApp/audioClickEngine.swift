// MARK: AudioClickEngine.swift
import AVFoundation

enum ClickSound: String, CaseIterable {
    case beep, wood, noise, square
}

final class AudioClickEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat!
    private let sampleRate: Double = 44100

    // Prebuilt click buffers (fast)
    private var normalBuffers: [ClickSound: AVAudioPCMBuffer] = [:]
    private var accentBuffers: [ClickSound: AVAudioPCMBuffer] = [:]

    func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Build sound buffers
        for s in ClickSound.allCases {
            normalBuffers[s] = ClickSynth.makeClick(type: s, accent: false, sampleRate: sampleRate)
            accentBuffers[s] = ClickSynth.makeClick(type: s, accent: true, sampleRate: sampleRate)
        }

        do {
            try engine.start()
        } catch {
            print("Engine start error: \(error)")
        }
    }

    func start() {
        if !engine.isRunning {
            do { try engine.start() } catch { print(error) }
        }
    }

    func stop() {
        player.stop()
        engine.pause()
    }

    func scheduleClick(atHostTime hostTime: UInt64, sound: ClickSound, accent: Bool) {
        let buf = (accent ? accentBuffers[sound] : normalBuffers[sound])!
        if !player.isPlaying { player.play() }
        let when = AVAudioTime(hostTime: hostTime)
        player.scheduleBuffer(buf, at: when, options: [], completionHandler: nil)
    }
}

enum ClickSynth {
    // Fast, clicky buffers with short envelopes; accent uses slightly higher pitch / level.
    static func makeClick(type: ClickSound, accent: Bool, sampleRate: Double) -> AVAudioPCMBuffer {
        let dur = 0.06  // 60 ms click
        let n = Int(dur * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let ptr = buf.floatChannelData![0]

        let amp: Float = accent ? 0.95 : 0.75
        switch type {
        case .beep:
            let f0: Float = accent ? 2000 : 1600
            for i in 0..<n {
                let t = Float(i)/Float(sampleRate)
                let env = envelope(t, total: Float(dur))
                ptr[i] = amp * sinf(2.0*Float.pi*f0*t) * env
            }
        case .wood:
            // short bandpass burst (approximated with decaying noise + resonant sine)
            let f0: Float = accent ? 1200 : 900
            for i in 0..<n {
                let t = Float(i)/Float(sampleRate)
                let env = envelope(t, total: Float(dur))
                let sine = sinf(2*Float.pi*f0*t)
                let noise = (Float.random(in: -1...1))
                ptr[i] = amp * (0.7*sine + 0.3*noise) * env
            }
        case .noise:
            for i in 0..<n {
                let t = Float(i)/Float(sampleRate)
                let env = envelope(t, total: Float(dur))
                let noise = (Float.random(in: -1...1))
                ptr[i] = amp * noise * env
            }
        case .square:
            let f0: Float = accent ? 1000 : 800
            for i in 0..<n {
                let t = Float(i)/Float(sampleRate)
                let env = envelope(t, total: Float(dur))
                let s = sinf(2*Float.pi*f0*t)
                let sq = s >= 0 ? 1.0 as Float : -1.0
                ptr[i] = amp * sq * env * 0.6
            }
        }
        // hard clip guard
        for i in 0..<n { ptr[i] = max(-1, min(1, ptr[i])) }
        return buf
    }

    private static func envelope(_ t: Float, total: Float) -> Float {
        // quick attack, exponential-ish decay
        let a: Float = 0.002
        let d: Float = total - a
        if t < a { return t / a }
        let x = (t - a) / max(d, 1e-4)
        return powf(max(0, 1 - x), 4)
    }
}
