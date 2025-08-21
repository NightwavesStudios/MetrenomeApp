// MARK: MetronomeEngine.swift
import Foundation
import AVFoundation
import CoreHaptics

@MainActor
final class MetronomeEngine: ObservableObject {
    // Public controls
    @Published var bpm: Double = 120
    @Published var beatsPerBar: Int = 4
    @Published var sound: ClickSound = .beep
    @Published var soundEnabled: Bool = true
    @Published var hapticsEnabled: Bool = false
    @Published private(set) var isRunning = false
    @Published var pulse = false   // UI pulse toggle

    // Audio
    private let audio = AudioClickEngine()
    // Haptics
    private let haptics = HapticsEngine()

    // Scheduler
    private var timer: DispatchSourceTimer?
    private let scheduleLookahead: TimeInterval = 0.25  // seconds of audio scheduled ahead
    private let scheduleInterval: TimeInterval = 0.02   // scheduler tick (50 Hz)
    private var nextBeatHostTime: UInt64 = 0
    private var beatIndex: Int = 0

    func prepare() {
        audio.prepare()
        haptics.prepare()
    }

    func start() {
        guard !isRunning else { return }
        audio.start()
        let now = AudioTime.hostTimeNow()
        nextBeatHostTime = now + AudioTime.toHostTime(seconds: 0.1) // start after small delay
        beatIndex = 0
        isRunning = true
        startScheduler()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        audio.stop()
    }

    func resetPhase() {
        // Keep running but re-align next downbeat
        if isRunning {
            let now = AudioTime.hostTimeNow()
            nextBeatHostTime = now + AudioTime.toHostTime(seconds: 0.12)
            beatIndex = 0
        }
    }

    private func startScheduler() {
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        t.schedule(deadline: .now(), repeating: scheduleInterval)
        t.setEventHandler { [weak self] in self?.scheduleBeatsIfNeeded() }
        t.resume()
        timer = t
    }

    private func scheduleBeatsIfNeeded() {
        guard isRunning else { return }
        let secondsPerBeat = 60.0 / bpm
        let hostNow = AudioTime.hostTimeNow()
        var t = nextBeatHostTime

        while AudioTime.hostTimeToSeconds(t) - AudioTime.hostTimeToSeconds(hostNow) < scheduleLookahead {
            let isAccent = (beatIndex % max(beatsPerBar,1)) == 0

            if soundEnabled {
                audio.scheduleClick(atHostTime: t, sound: sound, accent: isAccent)
            }
            if hapticsEnabled {
                haptics.scheduleTransient(atHostTime: t, intensity: isAccent ? 1.0 : 0.5, sharpness: isAccent ? 0.9 : 0.6)
            }

            // UI pulse (on main)
            let uiDelay = max(0, AudioTime.hostTimeToSeconds(t) - AudioTime.hostTimeToSeconds(hostNow))
            DispatchQueue.main.asyncAfter(deadline: .now() + uiDelay) { [weak self] in
                self?.pulse.toggle()
            }

            // advance
            t = AudioTime.addSeconds(hostTime: t, seconds: secondsPerBeat)
            beatIndex &+= 1
        }
        nextBeatHostTime = t
    }

    // Tap tempo: median of last taps
    private var tapTimes: [Date] = []
    func tapTempo() {
        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.suffix(6)
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.0.timeIntervalSince($0.1) }.filter { $0 > 0.12 && $0 < 2.0 }
        guard !intervals.isEmpty else { return }
        let sorted = intervals.sorted()
        let mid = sorted.count/2
        let median = sorted.count % 2 == 0 ? (sorted[mid-1] + sorted[mid]) / 2.0 : sorted[mid]
        let newBPM = min(300, max(20, 60.0 / median))
        DispatchQueue.main.async {
            self.bpm = newBPM
            self.resetPhase()
        }
    }
}
